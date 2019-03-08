## Embrionix encapsulator:

* has 2 SDI inputs A and B
* encapsulates 1 video, 8 audio and 1 ancillary flow for each input
* ouputs 2 (1 and 2) RTP streams par flow

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

get_sdp.py uses Embrionix API to fetch sdp per flow.
