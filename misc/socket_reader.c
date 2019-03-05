/* compile with:
 * gcc socket_reader.c
 */

#define _GNU_SOURCE
#include <arpa/inet.h>
#include <errno.h>
#include <inttypes.h>
#include <netinet/in.h>
#include <netinet/ip.h> /* superset of previous */
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <signal.h>
#include <unistd.h>

typedef struct {
#ifdef WORDS_BIGENDIAN
    unsigned version:2;   /* protocol version */
    unsigned int p:1;           /* padding flag */
    unsigned int x:1;           /* header extension flag */
    unsigned int cc:4;          /* CSRC count */
    unsigned int m:1;           /* marker bit */
    unsigned int pt:7;          /* payload type */
#else
    unsigned int cc:4;          /* CSRC count */
    unsigned int x:1;           /* header extension flag */
    unsigned int p:1;           /* padding flag */
    unsigned version:2;         /* protocol version */
    unsigned int pt:7;          /* payload type */
    unsigned int m:1;           /* marker bit */
#endif
    unsigned int seq:16;        /* sequence number */
    uint32_t ts;                /* timestamp */
    uint32_t ssrc;              /* synchronization source */
    uint32_t csrc[1];           /* optional CSRC list */
} rtpHeader;

#define MTU 1500
#define RTP_HEADER_SIZE 12

#define USE_RECV 0
#define USE_RECVMSG 1
#define USE_RECV_MANY_MSG 2

static unsigned int count_call_recvmmsg = 0;
static unsigned int count_recvmmsg_max_reached = 0;

uint16_t last_seq = 0;
uint32_t last_timestamp = 0;
bool seen_pt = false;
bool last_packet_marked;
int nb_dropped = 0;
int nb_received = 0;

int verbose = 0; /* verbose output */

#define DEFAULT_FRAME_WIDTH 1920
#define DEFAULT_FRAME_HEIGHT 1080
#define DEFAULT_BYTES_PER_PIXEL 2

int frame_width = DEFAULT_FRAME_WIDTH;
int frame_height = DEFAULT_FRAME_HEIGHT;
int bytes_per_pixel = DEFAULT_BYTES_PER_PIXEL;
int frame_size = -1;

static bool extract_payload = false;
static uint32_t last_rtp_timestamp = 0;
static unsigned int write_offset = 0;
static bool wait_first_frame = true;

static bool msg_waitforone = false;

static long rcv_buf_size = -1; // -1 indicates to use the default value
static bool use_vmsplice = false;

static int sleep_us = 0;
static int delay = 0;

void display_stats()
{
    fprintf(stderr, "received: %d\n", nb_received);
    fprintf(stderr, "dropped: %d  \n", nb_dropped);
    fprintf(stderr, "%0.2lf %% drop\n", (double)nb_dropped / (double)(nb_received + nb_dropped) * 100);
    if (count_call_recvmmsg) {
        fprintf(stderr, "max recvmmsg returned max messages %u times (out of %u)\n",
                count_recvmmsg_max_reached, count_call_recvmmsg);
        fprintf(stderr, "average messages fetched by recvmmsg: %.2lf\n",
                (double) nb_received / (double)count_call_recvmmsg);
    }

}

void sig_handler(int signo)
{
    if (signo == SIGINT) {
        fprintf(stderr, "received SIGINT\n");
        display_stats();
        exit(1);
    }
}

static void write_payload(const void *buf, size_t len)
{
    while (len) {
        ssize_t ret = write(STDOUT_FILENO, buf, len);

        if (ret == -1) {
            fprintf(stderr, "write returned %zd (len = %zu)\n", ret, len);
            exit(EXIT_FAILURE);
        }

        buf += ret;
        len -= ret;
    }
}

static void print_pad_bytes(unsigned int pad)
{
    /* using:
     *     char buffer[pad];
     *     memset(buffer, 0, pad);
     *     write_payload(buffer, pad);
     * could explode the stack if pad is big, use a safer
     * (and maybe a bit slower) construct.
     */

    if (verbose)
        fprintf(stderr, "padding %d\n", pad);

#define PAD_LEN 8096
    while (pad) {
        size_t write_len = pad > PAD_LEN ? PAD_LEN : pad;
        char buffer[PAD_LEN] = { 0 };

        write_payload(buffer, write_len);
        pad -= write_len;
    }
}

void depay_rfc4175(char *buf, size_t len)
{
    rtpHeader* header = (rtpHeader *) buf;
    buf += 12;
    len -= 12;

    /*
     * RTP timestamp is the same for every packet of a frame, so we detect new
     * frames when timestamp changes
     */
    if (last_rtp_timestamp && last_rtp_timestamp != header->ts) {
        if (wait_first_frame) {
            wait_first_frame = false;
        } else {
           /*
            * new frame, send some padding if previous frame was incomplete,
            * that way the image is stable and viewable
            */
           if (frame_size - write_offset) {
              fprintf(stderr, "incomplete frame, frame_size: %d, write_offset: %u\n", frame_size, write_offset);
              print_pad_bytes(frame_size - write_offset);
           }

           if (verbose)
              fprintf(stderr, "new frame\n");

           write_offset = 0;
        }
    }

    last_rtp_timestamp = header->ts;

    /* if we're still waiting for the first packet of a new frame to come in, return early */
    if (wait_first_frame)
        return;

    int length, line, offset, cont;
    const uint8_t *headers = buf + 2; /* skip extended seqnum */
    const uint8_t *payload = buf + 2;
    int payload_len = len - 2;

    /*
     * looks for the 'Continuation bit' in scan lines' headers
     * to find where data start
     */
    do {
        if (payload_len < 6) {
            fprintf(stderr, "payload too short when scanning header\n");
            return;
        }

        cont = payload[4] & 0x80;
        payload += 6;
        payload_len -= 6;
    } while (cont);

    /* and now iterate over every scan lines */
    do {
        if (payload_len < 4) {
            fprintf(stderr, "payload too short when scanning payload %d\n", payload_len);
            return;
        }

        length = (headers[0] << 8) | headers[1];
        line = ((headers[2] & 0x7f) << 8) | headers[3];
        offset = ((headers[4] & 0x7f) << 8) | headers[5];
        cont = headers[4] & 0x80;
        headers += 6;

        if (verbose)
           fprintf(stderr, "line: %d, offset: %d, length: %d\n", line, offset, length);

        /*
         * YCbCr-4:2:2 8 bit has a pixel group of 4B, check
         * that length is a multiple of that value
         */
        if (length % 4) {
            fprintf(stderr, "length is not a multiple of the pixel group size\n");
            return;
        }

        if (length > payload_len) {
           fprintf(stderr, "Shoo, adjusted length\n");
            length = payload_len;
        }

        unsigned int frame_offset = (line * frame_width + offset) * bytes_per_pixel;
        if (frame_offset > frame_size) {
           fprintf(stderr, "frame_offset bigger than frame_size\n");
           return;
        }

        if (frame_offset != write_offset) {
           if (verbose)
               fprintf(stderr, "missing data: frame_offset: %u, write_offset: %u\n", frame_offset, write_offset);
            print_pad_bytes(frame_offset - write_offset);
            write_offset = frame_offset;
        }

        if (verbose)
           fprintf(stderr, "writting %d bytes\n", length);
        write_payload(payload, length);
        write_offset += length;

        payload += length;
        payload_len -= length;
    } while (cont);

}

void do_delay(int iterations)
{
    int i = 0;
    while (i < iterations) {
        ++i;
    }
}

void parse_rtp_packet(char* buf, size_t len) {

    rtpHeader* header = (rtpHeader *) buf;
    uint16_t curr_seq = ntohs(header->seq);
    uint16_t diff = curr_seq - last_seq - 1;
    uint32_t timestamp = ntohl(header->ts);
    int pt = header->pt;

    if ((last_seq != 0) && (diff != 0)) {
        if (verbose) {
            fprintf(stderr, "last_seq=%d, curr_seq=%d, missed: %d \n",
                    last_seq, curr_seq, diff);
        }
        nb_dropped+=diff;
    }

    last_seq = curr_seq;

    if (last_timestamp != 0) {
        if (timestamp < last_timestamp)
            fprintf(stderr,
                    "timestamp wrap: last_timestamp=%" PRIu32
                    ", current_timestamp=%" PRIu32 "\n",
                    last_timestamp, timestamp);
        if (timestamp != last_timestamp && !last_packet_marked)
            fprintf(stderr, "Missed or missing RTP marker\n");
    }

    last_timestamp = timestamp;
    last_packet_marked = header->m;

    if (!seen_pt) {
        fprintf(stderr, "Detected stream with payload type %d\n", pt);
        seen_pt = true;
    }

    if (extract_payload)
       depay_rfc4175(buf, len);

    // TODO: probably won't work in all cases
    if (last_seq == 65535)
        last_seq = 0;

    nb_received++;

    if (sleep_us > 0) {
        usleep(sleep_us);
    }

    do_delay(delay);
}

void use_recv(int listen_fd)
{
    int err;
    char buf[MTU];

    ssize_t len_msg = recv(listen_fd, buf, MTU, 0);

    err = errno;

    if (len_msg < 0) {
        if ((err == EAGAIN) || (err == EWOULDBLOCK)) {
            fprintf(stderr, "non-blocking operation returned EAGAIN or EWOULDBLOCK\n");
        } else {
            fprintf(stderr, "errno=%d \n", err);
        }

    } else if (len_msg >= RTP_HEADER_SIZE) {
        parse_rtp_packet(buf, len_msg);

    } else {
        fprintf(stderr, "packet length below %d \n", RTP_HEADER_SIZE);
    }
}

void use_recvmsg(int listen_fd, struct sockaddr_storage src_addr)
{
    int err;
    char buf[MTU];

    struct iovec iov[1];
    iov[0].iov_base=buf;
    iov[0].iov_len=sizeof(buf);

    struct msghdr message;
    message.msg_name=&src_addr;
    message.msg_namelen=sizeof(src_addr);
    message.msg_iov=iov;
    message.msg_iovlen=1;
    message.msg_control=0;
    message.msg_controllen=0;

    ssize_t len_msg = recvmsg(listen_fd, &message, 0);

    err = errno;

    if (len_msg < 0) {
        if ((err == EAGAIN) || (err == EWOULDBLOCK)) {
            fprintf(stderr, "non-blocking operation returned EAGAIN or EWOULDBLOCK\n");
        } else {
            fprintf(stderr, "errno=%d \n", err);
        }

    } else if (len_msg >= RTP_HEADER_SIZE) {
        parse_rtp_packet(buf, len_msg);

    } else {
        fprintf(stderr, "packet length below %d \n", RTP_HEADER_SIZE);
    }
}

int use_recv_many_msg(int listen_fd, int how_many_msgs)
{
    char bufs[how_many_msgs][MTU+1];
    struct mmsghdr msgs[how_many_msgs];
    struct iovec iovecs[how_many_msgs];

    memset(msgs, 0, sizeof(msgs));
    for (int i = 0; i < how_many_msgs; i++) {
        iovecs[i].iov_base         = bufs[i];
        iovecs[i].iov_len          = MTU;
        msgs[i].msg_hdr.msg_iov    = &iovecs[i];
        msgs[i].msg_hdr.msg_iovlen = 1;
    }

    int num_msgs = -1;

    num_msgs = recvmmsg(listen_fd, msgs, how_many_msgs, msg_waitforone ? MSG_WAITFORONE : 0, NULL);
    count_call_recvmmsg++;
    if (num_msgs == how_many_msgs)
        count_recvmmsg_max_reached++;

    if (num_msgs == -1) {
        perror("recvmmsg()");
        return 0;
    }

    //printf("%d messages received\n", num_msgs);
    for (int i = 0; i < num_msgs; i++) {
        bufs[i][msgs[i].msg_len] = 0;
        //printf("%d %s", i+1, bufs[i]);
        parse_rtp_packet(bufs[i], msgs[i].msg_len);
    }

    return 1;
}

void reader_loop(int listen_fd,
                 struct sockaddr_storage src_addr,
                 int receive_type, int how_many_msgs)
{
    while(1)
    {
        switch (receive_type) {
            case USE_RECV :
                use_recv(listen_fd);
                break;
            case USE_RECVMSG :
                use_recvmsg(listen_fd, src_addr);
                break;
            case USE_RECV_MANY_MSG :
            default:
                if (!use_recv_many_msg(listen_fd, how_many_msgs))
                    exit(EXIT_FAILURE);
        }
    }
}

void join_multicast(int socket, const char *multicast_group, const char *interface_ip)
{
    struct ip_mreq mc_req;

    mc_req.imr_multiaddr.s_addr = inet_addr(multicast_group);
    mc_req.imr_interface.s_addr = inet_addr(interface_ip);

    if (setsockopt(socket, IPPROTO_IP, IP_ADD_MEMBERSHIP,
                   (void*) &mc_req, sizeof(mc_req)) < 0) {
        perror("failed to join multicast group");
        exit(EXIT_FAILURE);
    }
}

int main(int argc, char *argv[])
{
    int opt;
    int receive_type = 2;
    int port = 5005;
    int how_many_msgs = 10; /* used in case of USE_RECV_MANY_MSG */

    char* token;
    char delim[2] = "x";

    char *multicast_group = NULL;
    char *receiver_ip = NULL;

    while ((opt = getopt(argc, argv, "vr:p:s:d:m:ewb:n:g:i:")) != -1) {
        switch(opt) {
            case 'v' :
                verbose = 1;
                break;
            case 'e':
                extract_payload = true;
                break;
            case 'r' :
                /* -r receive type options:
                 * 0: recv
                 * 1: recvmsg
                 * 2: recvmmsg (default)
                 */
                receive_type = atoi(optarg);
                if (receive_type < 0 || receive_type > 2) {
                    fprintf(stderr, "-r out of range: %d, possible values: [0,2]\n"
                                    "\t0 - recv\n"
                                    "\t1 - recvmsg\n"
                                    "\t2 - recvmmsg\n",
                            receive_type);
                    exit(EXIT_FAILURE);
                }
                break;

            case 'p' :
                port = atoi(optarg);
                break;

            case 's' :
                sleep_us = atoi(optarg);

                if (sleep_us < 0 || sleep_us > 1000000) {
                    fprintf(stderr, "-s out of range: %d, must be in the range: [0,1000000]\n",
                            sleep_us);
                    exit(EXIT_FAILURE);
                }
                break;
            case 'd' :
                delay = atoi(optarg);
                if (delay < 0) {
                    fprintf(stderr, "-d out of range: %d, must be greater than 0\n", delay);
                    exit(EXIT_FAILURE);
                }
                break;
            case 'm' :
                how_many_msgs = atoi(optarg);
                if (how_many_msgs < 1) {
                    fprintf(stderr, "-m out of range: %d, must be greater than 1\n",
                            how_many_msgs);
                    exit(EXIT_FAILURE);
                }
                break;
            case 'w' :
                msg_waitforone = true;
                break;
            case 'b' :
                rcv_buf_size = atol(optarg);
                if (rcv_buf_size < 128) {
                    fprintf(stderr, "-b out of range: %ld, must be >= 128\n",
                            rcv_buf_size);
                    exit(EXIT_FAILURE);
                }
                break;
            case 'n' :
                token = strtok(optarg, delim);
                if (token) {
                    frame_width = atoi(token);
                    token = strtok(NULL, delim);
                    if (token) {
                        frame_height = atoi(token);
                    } else {
                        fprintf(stderr, "please provide a correct height \n");
                        exit(EXIT_FAILURE);
                    }
                } else {
                    fprintf(stderr, "please provide a correct width \n");
                    exit(EXIT_FAILURE);
                }
                break;
            case 'g':
                multicast_group = strdup(optarg);
                break;
            case 'i':
                receiver_ip = strdup(optarg);
                break;
            default :
                fprintf(stderr, "Usage: %s [-r receive_type [0,2]] "
                                "[-p port] "
                                "[-s sleep microseconds] "
                                "[-d delay] "
                                "[-m recvmmsg vlen] "
                                "[-e] "
                                "[-v] "
                                "[-w] "
                                "[-b rcvbuf ] "
                                "[-n resolution] "
                                "[-g multicast_group -i receiver_ip]\n",
                        argv[0]);
                exit(EXIT_FAILURE);
        }

        frame_size = frame_width * frame_height * bytes_per_pixel;
    }

    if ((multicast_group || receiver_ip) && (!multicast_group || !receiver_ip)) {
        fprintf(stderr, "-i and -g must be used together\n");
        exit(EXIT_FAILURE);
    }

    fprintf(stderr,
            "port: %d"
            ", sleep: %dus"
            ", delay: %d"
            ", extract RTP payload: %s"
            ", receive func type: %d"
            ", recvmmsg messages: %d"
            ", verbose: %d"
            ", MSG_WAITFORONE: %s"
            ", rcvbuf: %ld"
            ", resolution: %dx%d \n",
            port, sleep_us, delay, extract_payload ? "yes" : "no", receive_type, how_many_msgs, verbose,
            msg_waitforone ? "true" : "false", rcv_buf_size, frame_width, frame_height);

    int listen_fd = -1;
    struct sockaddr_in serv_addr;

    struct sockaddr_storage src_addr;

    listen_fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (listen_fd < 0) {
        fprintf(stderr, "can not create socket \n");
        exit(EXIT_FAILURE);
    }

    if (signal(SIGINT, sig_handler) == SIG_ERR)
        fprintf(stderr, "can't catch SIGINT\n");

    serv_addr.sin_family = AF_INET;
    serv_addr.sin_addr.s_addr = htonl(INADDR_ANY);
    serv_addr.sin_port = htons(port);

    int ret = bind(listen_fd, (struct sockaddr*)&serv_addr, sizeof(serv_addr));

    if (ret != 0) {
        fprintf(stderr, "error binding to socket, check if it is already in use: %d\n", errno);
        exit(EXIT_FAILURE);
    }

    if (rcv_buf_size != -1) {
        if (setsockopt(listen_fd, SOL_SOCKET, SO_RCVBUF, &rcv_buf_size, sizeof(rcv_buf_size)) == -1) {
            fprintf(stderr, "could not set rcv buffer size: %d\n", errno);
            exit(EXIT_FAILURE);
        }
    }

    long rcv_buf_actual;
    socklen_t optlen = sizeof(rcv_buf_actual);
    if (getsockopt(listen_fd, SOL_SOCKET, SO_RCVBUF, &rcv_buf_actual, &optlen) == -1) {
        fprintf(stderr, "could not get rcv buffer size: %d\n", errno);
        exit(EXIT_FAILURE);
    }
    rcv_buf_actual = rcv_buf_actual & ((1UL<< optlen * 8) - 1);

    if (rcv_buf_size != -1) {
        // the kernel should set the buffer size to twice the requested size; if not, it means
        // that the requested size (x 2) is larger than the max size in the kernel
        if (rcv_buf_actual != rcv_buf_size * 2) {
            fprintf(stderr, "could not set requested rcv buffer size, verify that it does not exceed the max size\n");
            exit(EXIT_FAILURE);
        }
    }

    fprintf(stderr, "using rcv buffer size: %ld\n", rcv_buf_actual);

    if (multicast_group && receiver_ip)
        join_multicast(listen_fd, multicast_group, receiver_ip);

    reader_loop(listen_fd, src_addr, receive_type, how_many_msgs);
}
