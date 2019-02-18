## Embrionix encapsulator:

* has 2 SDI inputs A and B
* encapsulates 1 video, 8 audio and 1 ancillary essence for each input
* ouputs 2 (1 and 2) RTP streams par essence

The 40 essences are ordered this way:

* video A1 <------------------ selected by get_sdp.py
* video A2
* audio ch1 A1 <-------------- selected by get_sdp.py
* audio ch1 A2
* [...]
* audio ch8 A1
* audio ch8 A2
* ancillary A1 <-------------- selected by get_sdp.py
* ancillary A2
* video B1
* [...]
* ancillary B2
