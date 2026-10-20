# ARTM multi-h CPM reading list

Retrieved 24 September 2026. “CPM-H” is interpreted here as ARTM multi-h CPM (Tier II).

1. [RCC 106-20, Chapter 2 (July 2020)](https://www.trmc.osd.mil/wiki/download/attachments/240256843/chapter2.pdf?api=v2&modificationDate=1692197849361&version=1). Start at section 2.3.3.3, printed pages 2-9 to 2-11, especially equation 2-11 and Table 2-6. Primary parameter reference: four dibit levels, three-symbol raised-cosine frequency pulse, and alternating indices 4/16 and 5/16. This is a dated reference edition, not a claim about the latest standard.
2. [Mark Geoghegan, Description and Performance Results for the Advanced Range Telemetry (ARTM) Tier II Waveform (ITC 2000)](https://www.quasonix.com/files/artm-tier-ii-waveform-itc-paper.pdf). Read PDF page 2 for the phase equations; page 3 for pulse, phase-tree and spectrum illustrations. Explains the reasons for pulse shaping and alternating indices, and the receiver complexity tradeoff. The notebook follows its explicit phase convention, with pulse integral 1/2 and phase multiplier 2π.
3. [Michael Rice and Erik Perrins, The Detection Efficiency of ARTM CPM in Aeronautical Telemetry (2005)](https://scholarsarchive.byu.edu/facpub/392/). Author repository record and abstract; useful for a later receiver notebook. Examines reduced-complexity detection. Only the repository abstract was reviewed for this starter; no BER results are reproduced.
4. [Keysight, Custom IQ — ARTM Multi-h CPM](https://helpfiles.keysight.com/csg/n5186/Content/CMOD/Custom%20IQ%20ARTM%20Multi-h%20CPM.htm). Practical cross-check: order 4, RC3 filter, h1=0.25 and h2=0.3125. Also flags phase closure when looping waveform files.

## Notebook scope

An educational complex-baseband modulator and spectrum experiment. Independent random bits approximate a randomized input. No framing, standard randomizer, channel coding, receiver, RF hardware impairments, or spectral-mask compliance test is implemented. Comparisons to altered pulse lengths or indices are experiments, not other standardized telemetry waveforms.
