## Embrionix encapsulator:

* has 2 SDI inputs A and B
* encapsulates 1 video, 8 audio and 1 ancillary flow for each input
* ouputs 2 (1 and 2) RTP streams per flow for -7
* provides normal, per-flow SDPs
* provides -7 SDPs, with primary and secondary flow combined (used by NMOS API)
* has a unicast IP address for control
* has a fake source IP address for media, it is not pingable and is used
  for src IP only, in packets

The 40 flows are ordered this way:

* 0:  video A1
* 1:  video A2
* 2:  audio ch1 A1
* 3:  audio ch1 A2
* [...]
* 16: audio ch8 A1
* 17: audio ch8 A2
* 18: ancillary A1
* 19: ancillary A2
* 20: video B1
* 21: video B2
* [...]
* 38: ancillary B1
* 39: ancillary B2

get_sdp.py uses Embrionix API to fetch SDP per flow.

# API

Firmware info: http://<SFP_IP>

API entry point: http://<SFP_IP>/emsfp/node/v1

# ancillary:

RTP time step: 1501 or 1502 ticks (interlaced)

Version 3.1.1673

3 modes:

* 'End of field event': 1pkt/field, compliant
* '1 ms of decoding': 2pkt/field, wrong marker bit, not compliant
* 'Packet by Packet': 1 anc type / pkt + 1 empty pkt for marker

