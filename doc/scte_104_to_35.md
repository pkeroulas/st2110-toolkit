# SCTE-104 to SCTE-35

## Definitions

* SCTE-104 -> SDI and SMPTE ST 2110-40 (did=0x41, sdid=0x07)
* SCTE-35 -> MPEG TS

## References

[Kernel Labs](http://www.kernellabs.com) has documented their [SDI-to-TS transcoder](http://www.kernellabs.com/blog/?p=4251) and has intended to [upstream in ffmpeg](https://patchwork.ffmpeg.org/patch/7221/) the integration of their [library](https://github.com/stoth68000/libklscte35). Here is their recommendation:
> No new work would be needed to the libklvanc nor libklscte35
> libraries, as we have this use case working in a publicly available
> build of the Open Broadcast Encoder.  In terms of ffmpeg integration,
> I was primarily focused on the opposite use case - extracting SCTE-35
> from a transport stream, converting it to SCTE-104, and putting it out
> over SDI as VANC.  While I certainly intend to support the use case
> you're describing and indeed I had it working in the lab at one point,
> the functionality isn't stable and needs more time/energy to get it
> into production.  In particular, an ffmpeg bitstream filter needs to
> be written to do the conversion (we have a "scte35 to scte104" filter,
> but you need a filter which does the opposite), and the mpeg TS muxing
> module needs to be modified to embed the resulting SCTE-35 packets.
> It isn't a huge piece of work, but it's not something I'm in a
> position to release yet as I can't claim it's fully stable
