#!/usr/bin/env python

"""
Linuxptp sync tester for multiple PTP slaves.

Executed on any host running 'ptp4l', i.e. master or slave, this tool
uses 'Ptp management client' to sample the offset from clock master
for every slave. The outputs are a realtime-plotting graph and
standard derivation.

The output of pmc command looks like:
    sending: GET CURRENT_DATA_SET
        b49691.fffe.0a717c-0 seq 0 RESPONSE MANAGEMENT CURRENT_DATA_SET
            stepsRemoved     1
            offsetFromMaster 22713.0
            meanPathDelay    86597.0
        3c970e.fffe.a94296-1 seq ...
"""

import re
import matplotlib.pyplot as plt
import numpy as np
from common import Server, Command

"""
Params
"""
N = 200 # samples number (~= duration in sec)
SLAVE_1_NAME = ''
SLAVE_1_MAC = ''
# remote host
SERVER_USER = ''
SERVER_PWD = ''
SERVER_IP = ''
PTP_DOMAIN = ''

"""
Clock object:
It contains mac, samples and plot params
"""
class PtpClock:
    def __init__(self, name, mac, color):
        self.name = name
        self.mac = mac
        self.color = color
        self.offset = 0
        self.offset_buffer = []
        self.mean_path_delay = 0
        self.mean_path_delay_buffer = []

    def put_values(self, offset, mean_path_delay):
        self.offset = offset
        self.mean_path_delay = mean_path_delay

    def set_default_values(self):
        # repeat the latest sample
        self.offset = self.offset_buffer[-1] if self.offset_buffer else 0
        self.mean_path_delay = self.mean_path_delay_buffer[-1] if self.mean_path_delay_buffer else 0

    def update_buffers(self):
        self.offset_buffer.append(self.offset)
        self.mean_path_delay_buffer.append(self.mean_path_delay)
        offset_sdt = np.std(np.array(self.offset_buffer))
        print("{} offset_sdt:{}".format(self.name, offset_sdt))

"""
Remote execution of the Ptp Management Client
"""
def get_ptp_stat(server):
    measurement_cmd = "pmc -d %s -u -b 2 'GET CURRENT_DATA_SET'" % (PTP_DOMAIN)
    command = Command(server=server, wait=True, command=measurement_cmd, control=None, timeout=-1, enable=True)
    try:
        output = command.execute(server.ssh)
        # convert multiline text to list and remove useless command header
        measurement_list = output.replace("\t", "").split("\n")[2:]
        return [i for i in measurement_list if i != ""]

    except Exception as e:
        print(e)
        return []

def main():
    # clock instances
    ptp_clocks = []
    ptp_clocks.append(PtpClock(SLAVE_1_NAME, SLAVE_1_MAC, 'b'))

    # connect to a remote host where ptp4l is running, slave or master to
    # reach the ptp management channel
    server = Server(1, SERVER_USER, SERVER_PWD, SERVER_IP)
    server.connect()

    # interactive plot mode with labeled axis and legend
    fig, offset_graph = plt.subplots()
    path_delay_graph = offset_graph.twinx()

    for clk in ptp_clocks:
        offset_graph.plot(range(len(clk.offset_buffer)),
                          clk.offset_buffer,
                          "".join([clk.color, "-"]),
                          label=" ".join([clk.name, "offset"]))
        path_delay_graph.plot(range(len(clk.mean_path_delay_buffer)),
                              clk.mean_path_delay_buffer,
                              "".join([clk.color, "."]),
                              label=" ".join([clk.name, "path delay"]))
        offset_graph.legend(loc='upper left', shadow=True)
        path_delay_graph.legend(loc='upper right', shadow=True)

    offset_graph.set_xlabel("samples")
    offset_graph.set_ylabel("master offset (ns)")
    path_delay_graph.set_ylabel("mean path delay (ns)")

    for i in range(N):
        measurement_list = get_ptp_stat(server)

        for clk in ptp_clocks:
            clk.set_default_values()

            # parse incoming data from pmc
            iterator = iter(measurement_list)
            for c, n, o, p in zip(iterator, iterator, iterator, iterator):
                mac = c.split('-')[0]
                offset = re.sub('offsetFromMaster +', '', o)
                path_delay = re.sub('meanPathDelay +', '', p)

                if mac == clk.mac:
                    clk.put_values(float(offset), float(path_delay))

            # append buffers and plot
            clk.update_buffers()
            offset_graph.plot(range(len(clk.offset_buffer)),
                              clk.offset_buffer,
                              clk.color+"-",
                              label=clk.name+" offset")
            offset_graph.autoscale(True, 'both', True)
            path_delay_graph.plot(range(len(clk.mean_path_delay_buffer)),
                                  clk.mean_path_delay_buffer,
                                  clk.color+".",
                                  label=clk.name)

        plt.pause(1)

    plt.show()

if __name__ == '__main__':
    main()
