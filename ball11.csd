; started: 8/13/18 
; last edit: 4/30/23 
; again on 3/8/26
; again on 4/3/26 to try to implement the bosendorfer piano samples.
<CsoundSynthesizer> 
<CsOptions> 
-odac ; :hw:1,0; live play may require -+rtaudio with -+portaudio (default) or -+alsa
</CsOptions> 
<CsInstruments> 
 giMoved = 0 
 ; I changed the sample rate to the maximum, 24 bit audio -3 option 
 ; sr = 192000 ; my laptop audio supports this high sample rate, but not the docking station 
 sr = 44100 
 ksmps = 10; 
 nchnls = 2 
 instr 1 
 
; p1 is always 1 
; p2 start time 
; p3 duration 
; p4 velocity, 60-80 works best 
; p5 tone - which tone is this note - 1-1200 for cents 
; p6 Octave 
; p7 voice 
; p8 stereo - pan from left = 0 to right = 16 
; p9 envelope - one of several function tables for envelopes 1 - 16 
; p10 glissando - one of several function tables to modify pitch 
; p11 upsample - use a sample higher (>0) or lower (<256) than normal 
; p12 envelope for right channel - if blank, use the left channel envelope for both channels 
; p13 2nd glissando 
; p14 3rd glissando 
; p15 volume 
; 
;  print(p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11, p12, p13, p14, p15)
 if p4 = 1 goto skipVel 
; 
;  table f2 has the iSampleType values indicating type of sample 
 iSampleType table p7,2 ; from McGill.dat col 6 1: mono 2: stereo 4: Akai MDF??? 5: Gigasample 
; 
 iVelTemp = (p4 > 90 ? 90 : p4) ; make sure p4 velocity not greater than 90 
 iVel = (iVelTemp < 50 ? 50 : iVelTemp) ; nor less than 50 
 iVel = p4
 iVoicet = (iSampleType = 5 ? (p7 + (iVel - 60)/2) : p7) ; alter voice if SampleType is 5, otherwise don't touch it 
 iVoice = round(iVoicet) 
; 
; table f1 has the start location of the sample tables control functions 
 iSampWaveTable table iVoice,1 ; find the location of the sample wave tables base on input p7 
;  print(p7, iVoice,iSampWaveTable)
 ipitch table p5, 3 ; look up the cent value in ftable 3 a table of 1200 values from 0.001 to 0.120 
 ioct = p6 ; convert from my octave form to midi standard 
;  iRatioFromCent = cent(p5) ; convert cents to ratio to be multiplied by a base frequency 
 ; 
 iMIDInumber = round(p5 / 100) + (12 * ioct) ; cent value, i.e. 386/100 = rounds to 4 + (12 * 2) = 28. iMIDInumber = 28 for an E 
 ; 
 iFtableTemp table iMIDInumber, iSampWaveTable ; map midi note number to the correct ftable for that note 
 iFtable = iFtableTemp + p11  ; up or down sample by parameter 11 
; The next section added on 5/4/22 to ensure that a sample file out of range is not selected. 
 iLength ftlen iSampWaveTable ; length of the table (128). How many steps it could hold. 
 indx = 0 
 iLowValue table indx, iSampWaveTable 
 iHighValue table iLength, iSampWaveTable 
 loop: 
 iCurValue table indx, iSampWaveTable 
 if iFtable == iCurValue goto iFound ; found the required sample file in the list of sample files, not out of range
 loop_lt indx, 1, iLength, loop ; this is basically a conditional goto statement 
; it's not in the list of valid samples. It could be too low or too high - for now reset it to what it originally was 
; before it went too far 
; if the upsample went to a higher sample file, set it to the maximum in the table 
 giMoved = giMoved + 1 
 ; printf_i "upsample tried to move sample out of range of available samples. originally %i requested %i. declined\n", 1, iFtableTemp, iFtable
 if iFtable > iFtableTemp then 
 iFtable = iHighValue 
 else 
 iFtable = iLowValue 
 endif 
; printf_i "switched to %i. giMoved now: %d\n", 1, iFtableTemp , giMoved 
;                ivoice,          iFtableTemp    iFtable             giMoved   always print
;                  +                        +     +                       +     +
 if iFtable != iFtableTemp then
 printf_i "voice: %i. switched sample from %i to %i. Total moved so far: %i\n", 1, iVoice, iFtableTemp, iFtable, giMoved 
;  else
;  printf_i "voice: %i. no switch %i == %i\n", 1, iVoice, iFtableTemp, iFtable
 endif

 iFound: 
 
 iamp = ampdb(iVel) * p15 / 5 ; velocity input is 60-80 - convert to amplitude 
 ; End of modification 5/4/22 
 i9 = 298-p9 ; valid envelope table number are 298, 297, 296, 295 etc. - left channel 
 i12 = 298-p12 ; valid envelope table number are 298, 297, 296, 295 etc. - right channel 
 i10 = p10 ; glissando #1 
 i13 = p13 ; valid glissando table number are 1500 since 4/28/23 and are listed with those numbers 
 ; print p10, i10 
 kamp_l oscil iamp, 1/p3, i9 ; create an envelope from a function table for left channel 
 kamp_r oscil iamp, 1/p3, i12 ; create an envelope from a function table for right channel 
 kpan_l tablei p8/16, 4, 1,0,1 ; pan with a sine wave using f table #4 - 2st value is reduced to max 1, normalized 
 kpan_r tablei 1.0 - p8/16, 4, 1,0,1 ; inverse of kpan_l 
 ibasno table iFtable-(3+iSampWaveTable), 1 + iSampWaveTable ; get midi note number the sample was recorded at 
 icent table iFtable-(3+iSampWaveTable), 2 + iSampWaveTable ; get cents to flatten each note 
 iloop table iFtable-(3+iSampWaveTable), 3 + iSampWaveTable ; get loop or not 
 ibasoct = ibasno/12 ; find the base octave 
 ibascps = cpsoct(ibasoct+(icent/1200)) ; flatten amount in icent table 
 ;
 inote = cpspch(ioct + ipitch) ; note plus the decimal fraction of a note from table 
 kcps = cpspch(ioct + ipitch) ; convert oct.fract to Hz at krate 
 if i10 > 0 then ; if glissando #1 is not zero, shift the note by the value of the gliss 
 kcpsm oscili 1, 1/p3, i10 ; create an set of shift multiplicands from table - glissandi 
 kcps1 = kcps * kcpsm ; shift the frequency by values in glissando table 
 else 
 kcps1 = kcps 
 endif 
 if i13 > 0 then ; glissand #2 if not zero cause it to shift the note a second time. 
 kcpsm2 oscili 1, 1/p3, i13 ; create a 2nd set of shift multiplicands from table - glissandi 2 
 kcps2 = kcpsm2 * kcps1 ; shift the frequency by values in 2nd glissando table 
 else 
 kcps2 = kcps1 
 endif 

 ; print p5, ioct, iMIDInumber, iFtable, iSampleType, iloop 
 if iSampleType = 4 goto akaimono 
 if iSampleType = 1 goto noloopm 
 if iloop = 0 goto noloops 
 ; Stereo with loop 
 a3,a4 loscil 1, kcps2, iFtable, ibascps; stereo sample with looping 
 goto skipstereo 
 noloops: 
 ; Stereo without looping - something has happened here between csound 6.4 and 6.11 
 a3,a4 loscil 1, kcps2, iFtable, ibascps, 0, 1, 2 ; stereo sample without looping - note that 1,2 is l 
 goto skipstereo 
 akaimono: 
 if iloop = 0 goto noloopm 
 ; Mono with looping 
 a3 loscil 1, kcps2, iFtable, ibascps ; mono sampling with loop - 
 a4 = a3 
 goto skipstereo 
 noloopm: 
 ; Mono without looping 
 a3 loscil 1, kcps2, iFtable, ibascps,0,1,2 ; mono AIFF sample without loop 
 a4 = a3 
 
 skipstereo: 
 a1 = a3 * kamp_l 
 a2 = a4 * kamp_r 
 ; 
 outs a1 * kpan_l ,a2 * kpan_r ; outs has been deprecated?
 skipVel: 
 endin 
 
</CsInstruments> 
 
<CsScore> 
; cents for each step in the scale 
; 1200 edo in cents 
; simplified way to write this table: 
; f# time size 7 a n1 b n2 c ... 
; f3 0 12 -7 0 12 0.1200 
f3 0 1200 -7 0 1200 0.1200 
f4 0 1025 9 .25 1 0 ;The first quadrant of a sine for panning 
; end of function tables included in the .mac file. The rest are system generated to support sampling. 
; first table is a list of the function tables for the samples based on the midi number 
; +1 second is a list of midi numbers representing the base note of the sample files 
; +2 third is cent offset to flatten the note to the correct intonation 
; +3 fourth is loop or not 
f298 0 1025 6 0 1 .5 1 1 496 1 496 1 15 .5 15 0.0 ; e0 - Attack and sustain with a relatively sharp ending 
f297 0 1025 6 0 4 .5 4 1 500 1 500 1 4 .5 4 0.0 ; e1 - Attack and sustain with a relatively sharp ending 
;#5 0 siz exp start take reach take reach 
; lf296 0 512 5 1024 512 1 ; e2 - exponential - dead piano 
; +-- cubic polynomials 
; | +-- start at 0 
; | | +-- take 2 to reach 
; | | | +-- reach 1/2 volumelf296 
; | | | | +-- take 2 to full volume 
; | | | | | +-- reach full volume 
; | | | | | | +-- take 126 
; | | | | | | | +-- half point 
f296 0 256 6 0 2 .5 2 1 32 0.6 32 0.25 32 0.125 32 0.06 32 0.001 
; lf296 0 512 5 1024 512 1 ; e2 - exponential - dead piano 
;#6 0 siz exp min values mid val max val mid val min val mid val max val mid val min 
f295 0 1025 6 0 64 .5 64 1 128 .6 128 .3 128 .5 128 .6 192 .3 192 0 ; e3 big hump, small hump 
f294 0 1025 6 0 64 .15 64 .3 128 .25 128 .2 128 .6 128 1 192 .5 192 0 ; e4 small hump, big hump 
f293 0 1025 6 0 1 .5 1 1 447 .99 447 .98 64 0.5 64 0 ;e5 default woodwind envelope 
f292 0 1025 6 0 1 .5 1 1 447 0.60 447 0.20 32 0.21 32 0.22 32 0.11 32 0.00 ; e6 moving away slowly 
f291 0 1025 6 0 1 .5 1 1 128 0.60 128 0.20 256 0.15 254 0.10 128 0.05 128 0.00 ; e7 moving away faster 
;lf290 0 1025 6 0 2 .5 2 1 501 .6 483 .3 18 .15 18 0 ; e8 hit and drop most 
f290 0 256 6 0 1 .5 1 1 128 .5 126 0 ; e8 hit and drop most 
f289 0 1025 6 0 1 .3 1 .6 479 .8 479 1 32 .5 32 0 ; e9 Start moderately and build, abrupt end 
f288 0 1025 6 0 64 .40 448 1 448 .6 64 0 ; e10 One long hump in the middle 
; +-- cubic polynomials 
; | +-- start at 0 
; | | +-- take 1 to reach 
; | | | +-- reach 1/2 volume 
; | | | | +-- take 1 to full volume 
; | | | | | +-- reach full volume 
; | | | | | | +-- take 368 
; | | | | | | | +-- almost full volume 
; | | | | | | | | +-- take 368 
; | | | | | | | | | +-- almost full volume 
; | | | | | | | | | | +-- take 16 to reach 
; | | | | | | | | | | | +-- 1/2 volume 
; | | | | | | | | | | | | +-- take 16 to reach 
; | | | | | | | | | | | | | +-- zero 
; | | | | | | | | | | | | | | stay there till the end - csound pads with zeros automatically 
f287 0 1025 6 0 1 .5 1 1 368 .99 368 .98 16 .5 16 0 ; e11 hit and sustain 3/4 the normal length 
; 1 1 303 303 16 16 
f286 0 1025 6 0 1 .5 1 1 323 .99 323 .98 16 .5 16 0 ; e12 hit and sustain 2/3 the normal length 
f285 0 1025 6 0 1 .5 1 1 248 .99 248 .98 16 .5 16 0 ; e13 hit and sustain 1/2 the normal length 
f284 0 1025 6 0 1 .5 1 1 124 .99 124 .98 4 .5 4 0 ; e14 hit and sustain 1/4 the normal length 
f283 0 1025 6 0 1 .5 1 1 84 .99 84 .98 1 .5 1 0 ; e15 hit and sustain 1/5 the normal length 
f282 0 1025 6 0 2 .2 2 .4 477 .7 479 1 32 .5 32 0 ; e16 sustain piano sound 
f281 0 1025 6 0 1 .1 1 .2 479 .6 479 1 32 .5 32 0 ; e17 sustain guitar sound 
;lf280 0 1025 6 1 64 .7 64 .4 64 .4 64 .4 384 .7 352 1 16 .5 16 0 ; e18 Sharp attack, then less quiet, build to end 
; +-- cubic polynomials 
; | +-- start at 1 loudest with no normalization 
; | | +-- take 64 to reach .7 
; | | | +-- reach 1/2 way to target 
; | | | | +-- target .4 
; | | | | | +-- take 64 to stay at this level 
; | | | | | | +-- target .4 
; | | | | | | | +-- take another 64 to stay 
; | | | | | | | | +-- target .4 
; | | | | | | | | | +-- take 368 to reach 1/2 way to full volume 
; | | | | | | | | | | +-- 1/2 volume 
; | | | | | | | | | | | +-- take 368 to reach full volume 
; | | | | | | | | | | | | +-- full volume 
; | | | | | | | | | | | | | +-- take 16 to reach half way to zero 
; | | | | | | | | | | | | | | +-- half way to zero 
; | | | | | | | | | | | | | | | +-- take 16 to reach 0 
; | | | | | | | | | | | | | | | | +-- target zero 
f280 0 1025 6 1 64 .7 64 .4 64 .4 64 .4 368 .7 368 1 16 .5 16 0 ; e18 Sharp attack, then less quiet, build to end 
f279 0 1025 6 0 1 .5 1 1.0 128 .7 228 .4 128 .4 28 .4 128 .5 128 .6 128 .3 126 0 ; e19 Moderate attack, then slightly quiet, build to end 
f278 0 1025 6 0 85 0.40 85 0.80 85 0.65 85 0.50 85 0.75 85 1.00 85 0.75 85 0.50 85 0.65 85 0.8 85 0.4 89 0.0 ; e20 3 humps - biggest in middle 
f277 0 1025 6 0 85 0.50 85 1.00 85 0.75 85 0.50 85 0.65 85 0.80 85 0.65 85 0.50 85 0.65 85 0.8 85 0.4 89 0.0 ; e21 3 humps - biggest early 
f276 0 1025 6 0 85 0.40 85 0.80 85 0.65 85 0.50 85 0.65 85 0.80 85 0.65 85 0.50 85 0.75 85 1.0 85 0.5 89 0.0 ; e22 3 humps - biggest late 
f275 0 1025 6 0 1 0.01 84 0.80 84 0.65 84 0.50 84 0.75 84 1.00 84 0.75 84 0.50 84 0.65 84 0.8 84 0.4 183 0.0 ; e24 3 humps - early biggest in middle 
f274 0 1025 6 0 1 0.01 84 1.00 84 0.75 84 0.50 84 0.65 84 0.80 84 0.65 84 0.50 84 0.65 84 0.8 84 0.4 183 0.0 ; e24 3 humps - early biggest early 
f273 0 1025 6 0 1 0.01 84 0.80 84 0.65 84 0.50 84 0.65 84 0.80 84 0.65 84 0.50 84 0.75 84 1.0 84 0.5 183 0.0 ; e25 3 humps - early biggest late 
f272 0 1025 6 0 64 .5 64 1 256 1 512 1 64 .5 64 0 ; e26 slow rise, sustain, slow drop 
; min pts mid pts max pts mid pts min pts mid pts max pts mid pts min 
;p1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 ; 
f265 0 1025 6 0 32 0.20 32 0.40 32 0.30 32 0.20 432 0.60 432 1.00 16 0.50 16 0.00 ; e33 channel one moving in gradually 
f264 0 1025 6 0 206 0.03 206 0.06 205 0.06 205 0.05 85 0.53 85 1.00 16 0.50 16 0.00 ; e34 channel 2 moving in at the end 
;#6 0 siz exp min values mid val max val mid val min val mid val max val mid val min 
f263 0 1025 6 0 2 .2 2 .6 4 .4 4 .3 500 .6 500 1 6 .5 7 0 ; e35 low bass piano inverse of h48 and above 
f262 0 1025 6 0 2 .2 2 .6 4 .4 4 .3 500 .32 500 .33 6 .2 7 0 ; e36 low bass piano inverse of h48 
f261 0 513 5 1024 384 1 ; e37- exponential - dead piano 
; Orchestra: Bosendorfer piano samples
;  Start of the sample file definitions:
; first ftable (601) assigns samples based on midi value. For example "0 605 22 " assigns sample table 605 for midi notes 0 through 22
; second ftable (602) is the base midi note for the sample. For example sample at ftable 605 was recorded at midi value 21
; third ftable (603) indicates if the sample file includes a loop point. 0 is no loop, 1 indicates the sample has a loop point.
; fourth ftable (604) is cent offset to flatten the sample to the correct intonation
f601 0 128 -17 0 605 22 606 24 607 25 608 27 609 29 610 30 611 32 612 34 613 36 614 37 615 39 616 41 617 42 618 44 619 46 620 48 621 49 622 60 623 63 624 65 625 72 626 73 627 75 628 77 629 78 630 80 631 85 632 87 633 89 634 90 635 92 636 94 
  637 96 638 97 639 99 640 101 641 102 642 104 643 106 644 108 645 109 
f602 0 64 -2 0  21  23  24  26  28  29  31  33  35  36  38  40  41  43  45  47  48  59  62  64  71  72  74  76  77  79  84  86  88  89  91  93  95  96  98 100 101 103 105 107 108 
f603 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0
f604 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
f646 0 128 -17 0 650 22 651 24 652 25 653 27 654 29 655 30 656 32 657 34 658 36 659 37 660 39 661 41 662 42 663 44 664 46 665 48 666 49 667 51 668 53 669 54 670 56 671 58 672 60 673 61 674 63 675 65 676 66 677 68 678 70 679 72 680 73 681 75 
  682 77 683 78 684 80 685 82 686 84 687 85 688 87 689 89 690 90 691 92 692 94 693 97 694 99 695 101 696 102 697 104 698 106 699 108 700 109 
f647 0 64 -2 0  21  23  24  26  28  29  31  33  35  36  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  83  84  86  88  89  91  93  96  98 100 101 103 105 107 108 
f648 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f649 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f701 0 128 -17 0 705 22 706 24 707 25 708 27 709 29 710 30 711 32 712 34 713 37 714 39 715 41 716 42 717 44 718 46 719 48 720 49 721 53 722 56 723 60 724 61 725 63 726 73 727 75 728 77 729 78 730 80 731 84 732 85 733 87 734 89 735 90 736 92 
  737 94 738 96 739 97 740 99 741 101 742 102 743 104 744 106 745 108 746 109 
f702 0 64 -2 0  21  23  24  26  28  29  31  33  36  38  40  41  43  45  47  48  52  55  59  60  62  72  74  76  77  79  83  84  86  88  89  91  93  95  96  98 100 101 103 105 107 108 
f703 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f704 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f747 0 128 -17 0 751 22 752 24 753 25 754 27 755 29 756 30 757 32 758 34 759 36 760 39 761 41 762 42 763 44 764 46 765 48 766 49 767 51 768 53 769 54 770 56 771 58 772 60 773 61 774 63 775 65 776 66 777 68 778 70 779 72 780 73 781 75 782 77 
  783 78 784 80 785 82 786 84 787 85 788 87 789 89 790 90 791 92 792 94 793 96 794 97 795 99 796 101 797 102 798 104 799 106 800 108 801 109 
f748 0 64 -2 0  21  23  24  26  28  29  31  33  35  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96  98 100 101 103 105 107 108 
f749 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f750 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f802 0 128 -17 0 806 22 807 24 808 25 809 27 810 29 811 30 812 32 813 34 814 36 815 37 816 39 817 41 818 42 819 44 820 46 821 48 822 49 823 51 824 53 825 54 826 56 827 58 828 60 829 61 830 63 831 65 832 66 833 68 834 70 835 72 836 73 837 75 
  838 77 839 78 840 80 841 82 842 84 843 85 844 87 845 89 846 90 847 92 848 94 849 96 850 97 851 99 852 101 853 102 854 104 855 106 856 108 857 109 
f803 0 64 -2 0  21  23  24  26  28  29  31  33  35  36  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96  98 100 101 103 105 107 108 
f804 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f805 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f858 0 128 -17 0 862 24 863 25 864 27 865 29 866 30 867 32 868 34 869 36 870 37 871 39 872 41 873 42 874 44 875 46 876 48 877 49 878 51 879 53 880 54 881 56 882 58 883 60 884 61 885 63 886 65 887 66 888 68 889 70 890 72 891 73 892 75 893 77 
  894 78 895 80 896 82 897 84 898 85 899 87 900 89 901 90 902 92 903 94 904 96 905 97 906 99 907 101 908 102 909 104 910 106 911 108 912 109 
f859 0 64 -2 0  23  24  26  28  29  31  33  35  36  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96  98 100 101 103 105 107 108 
f860 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f861 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f913 0 128 -17 0 917 22 918 24 919 25 920 27 921 29 922 30 923 32 924 34 925 36 926 37 927 39 928 41 929 42 930 44 931 46 932 48 933 49 934 51 935 53 936 54 937 56 938 58 939 60 940 61 941 63 942 65 943 66 944 68 945 70 946 72 947 73 948 75 
  949 77 950 78 951 80 952 82 953 84 954 85 955 87 956 89 957 90 958 92 959 94 960 96 961 97 962 99 963 101 964 102 965 104 966 106 967 108 968 109 
f914 0 64 -2 0  21  23  24  26  28  29  31  33  35  36  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96  98 100 101 103 105 107 108 
f915 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f916 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f605 0 0 1 "./samples/Bosendor/25 emp A0.wav" 0 0 0
f606 0 0 1 "./samples/Bosendor/25 emp B0-.wav" 0 0 0
f607 0 0 1 "./samples/Bosendor/25 emp C1-.wav" 0 0 0
f608 0 0 1 "./samples/Bosendor/25 emp D1-.wav" 0 0 0
f609 0 0 1 "./samples/Bosendor/25 emp E1-.wav" 0 0 0
f610 0 0 1 "./samples/Bosendor/25 emp F1-.wav" 0 0 0
f611 0 0 1 "./samples/Bosendor/25 emp G1-.wav" 0 0 0
f612 0 0 1 "./samples/Bosendor/25 emp A1.wav" 0 0 0
f613 0 0 1 "./samples/Bosendor/25 emp B1-.wav" 0 0 0
f614 0 0 1 "./samples/Bosendor/25 emp C2-.wav" 0 0 0
f615 0 0 1 "./samples/Bosendor/25 emp D2-.wav" 0 0 0
f616 0 0 1 "./samples/Bosendor/25 emp E2-.wav" 0 0 0
f617 0 0 1 "./samples/Bosendor/25 emp F2-.wav" 0 0 0
f618 0 0 1 "./samples/Bosendor/25 emp G2-.wav" 0 0 0
f619 0 0 1 "./samples/Bosendor/25 emp A2-.wav" 0 0 0
f620 0 0 1 "./samples/Bosendor/25 emp B2-.wav" 0 0 0
f621 0 0 1 "./samples/Bosendor/25 emp C3-.wav" 0 0 0
f622 0 0 1 "./samples/Bosendor/25 emp B3-.wav" 0 0 0
f623 0 0 1 "./samples/Bosendor/25 emp D4-.wav" 0 0 0
f624 0 0 1 "./samples/Bosendor/25 emp E4-.wav" 0 0 0
f625 0 0 1 "./samples/Bosendor/25 emp B4-.wav" 0 0 0
f626 0 0 1 "./samples/Bosendor/25 emp C5-.wav" 0 0 0
f627 0 0 1 "./samples/Bosendor/25 emp D5-.wav" 0 0 0
f628 0 0 1 "./samples/Bosendor/25 emp E5-.wav" 0 0 0
f629 0 0 1 "./samples/Bosendor/25 emp F5-.wav" 0 0 0
f630 0 0 1 "./samples/Bosendor/25 emp G5-.wav" 0 0 0
f631 0 0 1 "./samples/Bosendor/25 emp C6-.wav" 0 0 0
f632 0 0 1 "./samples/Bosendor/25 emp D6-.wav" 0 0 0
f633 0 0 1 "./samples/Bosendor/25 emp E6-.wav" 0 0 0
f634 0 0 1 "./samples/Bosendor/25 emp F6-.wav" 0 0 0
f635 0 0 1 "./samples/Bosendor/25 emp G6-.wav" 0 0 0
f636 0 0 1 "./samples/Bosendor/25 emp A6-.wav" 0 0 0
f637 0 0 1 "./samples/Bosendor/25 emp B6-.wav" 0 0 0
f638 0 0 1 "./samples/Bosendor/25 emp C7-.wav" 0 0 0
f639 0 0 1 "./samples/Bosendor/25 emp D7-.wav" 0 0 0
f640 0 0 1 "./samples/Bosendor/25 emp E7-.wav" 0 0 0
f641 0 0 1 "./samples/Bosendor/25 emp F7-.wav" 0 0 0
f642 0 0 1 "./samples/Bosendor/25 emp G7-.wav" 0 0 0
f643 0 0 1 "./samples/Bosendor/25 emp A7-.wav" 0 0 0
f644 0 0 1 "./samples/Bosendor/25 emp B7-.wav" 0 0 0
f645 0 0 1 "./samples/Bosendor/25 emp C8-.wav" 0 0 0
f650 0 0 1 "./samples/Bosendor/31 emp A0.wav" 0 0 0
f651 0 0 1 "./samples/Bosendor/31 emp B0-.wav" 0 0 0
f652 0 0 1 "./samples/Bosendor/31 emp C1-.wav" 0 0 0
f653 0 0 1 "./samples/Bosendor/31 emp D1-.wav" 0 0 0
f654 0 0 1 "./samples/Bosendor/31 emp E1-.wav" 0 0 0
f655 0 0 1 "./samples/Bosendor/31 emp F1-.wav" 0 0 0
f656 0 0 1 "./samples/Bosendor/31 emp G1-.wav" 0 0 0
f657 0 0 1 "./samples/Bosendor/31 emp A1.wav" 0 0 0
f658 0 0 1 "./samples/Bosendor/31 emp B1-.wav" 0 0 0
f659 0 0 1 "./samples/Bosendor/31 emp C2-.wav" 0 0 0
f660 0 0 1 "./samples/Bosendor/31 emp D2-.wav" 0 0 0
f661 0 0 1 "./samples/Bosendor/31 emp E2-.wav" 0 0 0
f662 0 0 1 "./samples/Bosendor/31 emp F2-.wav" 0 0 0
f663 0 0 1 "./samples/Bosendor/31 emp G2-.wav" 0 0 0
f664 0 0 1 "./samples/Bosendor/31 emp A2-.wav" 0 0 0
f665 0 0 1 "./samples/Bosendor/31 emp B2-.wav" 0 0 0
f666 0 0 1 "./samples/Bosendor/31 emp C3-.wav" 0 0 0
f667 0 0 1 "./samples/Bosendor/31 emp D3-.wav" 0 0 0
f668 0 0 1 "./samples/Bosendor/31 emp E3-.wav" 0 0 0
f669 0 0 1 "./samples/Bosendor/31 emp F3-.wav" 0 0 0
f670 0 0 1 "./samples/Bosendor/31 emp G3-.wav" 0 0 0
f671 0 0 1 "./samples/Bosendor/31 emp A3-.wav" 0 0 0
f672 0 0 1 "./samples/Bosendor/31 emp B3-.wav" 0 0 0
f673 0 0 1 "./samples/Bosendor/31 emp C4-.wav" 0 0 0
f674 0 0 1 "./samples/Bosendor/31 emp D4-.wav" 0 0 0
f675 0 0 1 "./samples/Bosendor/31 emp E4-.wav" 0 0 0
f676 0 0 1 "./samples/Bosendor/31 emp F4-.wav" 0 0 0
f677 0 0 1 "./samples/Bosendor/31 emp G4-.wav" 0 0 0
f678 0 0 1 "./samples/Bosendor/31 emp A4-.wav" 0 0 0
f679 0 0 1 "./samples/Bosendor/31 emp B4-.wav" 0 0 0
f680 0 0 1 "./samples/Bosendor/31 emp C5-.wav" 0 0 0
f681 0 0 1 "./samples/Bosendor/31 emp D5-.wav" 0 0 0
f682 0 0 1 "./samples/Bosendor/31 emp E5-.wav" 0 0 0
f683 0 0 1 "./samples/Bosendor/31 emp F5-.wav" 0 0 0
f684 0 0 1 "./samples/Bosendor/31 emp G5-.wav" 0 0 0
f685 0 0 1 "./samples/Bosendor/31 emp A5-.wav" 0 0 0
f686 0 0 1 "./samples/Bosendor/31 emp B5-.wav" 0 0 0
f687 0 0 1 "./samples/Bosendor/31 emp C6-.wav" 0 0 0
f688 0 0 1 "./samples/Bosendor/31 emp D6-.wav" 0 0 0
f689 0 0 1 "./samples/Bosendor/31 emp E6-.wav" 0 0 0
f690 0 0 1 "./samples/Bosendor/31 emp F6-.wav" 0 0 0
f691 0 0 1 "./samples/Bosendor/31 emp G6-.wav" 0 0 0
f692 0 0 1 "./samples/Bosendor/31 emp A6-.wav" 0 0 0
f693 0 0 1 "./samples/Bosendor/31 emp C7-.wav" 0 0 0
f694 0 0 1 "./samples/Bosendor/31 emp D7-.wav" 0 0 0
f695 0 0 1 "./samples/Bosendor/31 emp E7-.wav" 0 0 0
f696 0 0 1 "./samples/Bosendor/31 emp F7-.wav" 0 0 0
f697 0 0 1 "./samples/Bosendor/31 emp G7-.wav" 0 0 0
f698 0 0 1 "./samples/Bosendor/31 emp A7-.wav" 0 0 0
f699 0 0 1 "./samples/Bosendor/31 emp B7-.wav" 0 0 0
f700 0 0 1 "./samples/Bosendor/31 emp C8-.wav" 0 0 0
f705 0 0 1 "./samples/Bosendor/39 emp A0.wav" 0 0 0
f706 0 0 1 "./samples/Bosendor/39 emp B0-.wav" 0 0 0
f707 0 0 1 "./samples/Bosendor/39 emp C1-.wav" 0 0 0
f708 0 0 1 "./samples/Bosendor/39 emp D1-.wav" 0 0 0
f709 0 0 1 "./samples/Bosendor/39 emp E1-.wav" 0 0 0
f710 0 0 1 "./samples/Bosendor/39 emp F1-.wav" 0 0 0
f711 0 0 1 "./samples/Bosendor/39 emp G1-.wav" 0 0 0
f712 0 0 1 "./samples/Bosendor/39 emp A1.wav" 0 0 0
f713 0 0 1 "./samples/Bosendor/39 emp C2-.wav" 0 0 0
f714 0 0 1 "./samples/Bosendor/39 emp D2-.wav" 0 0 0
f715 0 0 1 "./samples/Bosendor/39 emp E2-.wav" 0 0 0
f716 0 0 1 "./samples/Bosendor/39 emp F2-.wav" 0 0 0
f717 0 0 1 "./samples/Bosendor/39 emp G2-.wav" 0 0 0
f718 0 0 1 "./samples/Bosendor/39 emp A2-.wav" 0 0 0
f719 0 0 1 "./samples/Bosendor/39 emp B2-.wav" 0 0 0
f720 0 0 1 "./samples/Bosendor/39 emp C3-.wav" 0 0 0
f721 0 0 1 "./samples/Bosendor/39 emp E3-.wav" 0 0 0
f722 0 0 1 "./samples/Bosendor/39 emp G3-.wav" 0 0 0
f723 0 0 1 "./samples/Bosendor/39 emp B3-.wav" 0 0 0
f724 0 0 1 "./samples/Bosendor/39 emp C4-.wav" 0 0 0
f725 0 0 1 "./samples/Bosendor/39 emp D4-.wav" 0 0 0
f726 0 0 1 "./samples/Bosendor/39 emp C5-.wav" 0 0 0
f727 0 0 1 "./samples/Bosendor/39 emp D5-.wav" 0 0 0
f728 0 0 1 "./samples/Bosendor/39 emp E5-.wav" 0 0 0
f729 0 0 1 "./samples/Bosendor/39 emp F5-.wav" 0 0 0
f730 0 0 1 "./samples/Bosendor/39 emp G5-.wav" 0 0 0
f731 0 0 1 "./samples/Bosendor/39 emp B5-.wav" 0 0 0
f732 0 0 1 "./samples/Bosendor/39 emp C6-.wav" 0 0 0
f733 0 0 1 "./samples/Bosendor/39 emp D6-.wav" 0 0 0
f734 0 0 1 "./samples/Bosendor/39 emp E6-.wav" 0 0 0
f735 0 0 1 "./samples/Bosendor/39 emp F6-.wav" 0 0 0
f736 0 0 1 "./samples/Bosendor/39 emp G6-.wav" 0 0 0
f737 0 0 1 "./samples/Bosendor/39 emp A6-.wav" 0 0 0
f738 0 0 1 "./samples/Bosendor/39 emp B6-.wav" 0 0 0
f739 0 0 1 "./samples/Bosendor/39 emp C7-.wav" 0 0 0
f740 0 0 1 "./samples/Bosendor/39 emp D7-.wav" 0 0 0
f741 0 0 1 "./samples/Bosendor/39 emp E7-.wav" 0 0 0
f742 0 0 1 "./samples/Bosendor/39 emp F7-.wav" 0 0 0
f743 0 0 1 "./samples/Bosendor/39 emp G7-.wav" 0 0 0
f744 0 0 1 "./samples/Bosendor/39 emp A7-.wav" 0 0 0
f745 0 0 1 "./samples/Bosendor/39 emp B7-.wav" 0 0 0
f746 0 0 1 "./samples/Bosendor/39 emp C8-.wav" 0 0 0
f751 0 0 1 "./samples/Bosendor/47 emp A0.wav" 0 0 0
f752 0 0 1 "./samples/Bosendor/47 emp B0-.wav" 0 0 0
f753 0 0 1 "./samples/Bosendor/47 emp C1-.wav" 0 0 0
f754 0 0 1 "./samples/Bosendor/47 emp D1-.wav" 0 0 0
f755 0 0 1 "./samples/Bosendor/47 emp E1-.wav" 0 0 0
f756 0 0 1 "./samples/Bosendor/47 emp F1-.wav" 0 0 0
f757 0 0 1 "./samples/Bosendor/47 emp G1-.wav" 0 0 0
f758 0 0 1 "./samples/Bosendor/47 emp A1.wav" 0 0 0
f759 0 0 1 "./samples/Bosendor/47 emp B1-.wav" 0 0 0
f760 0 0 1 "./samples/Bosendor/47 emp D2-.wav" 0 0 0
f761 0 0 1 "./samples/Bosendor/47 emp E2-.wav" 0 0 0
f762 0 0 1 "./samples/Bosendor/47 emp F2-.wav" 0 0 0
f763 0 0 1 "./samples/Bosendor/47 emp G2-.wav" 0 0 0
f764 0 0 1 "./samples/Bosendor/47 emp A2-.wav" 0 0 0
f765 0 0 1 "./samples/Bosendor/47 emp B2-.wav" 0 0 0
f766 0 0 1 "./samples/Bosendor/47 emp C3-.wav" 0 0 0
f767 0 0 1 "./samples/Bosendor/47 emp D3-.wav" 0 0 0
f768 0 0 1 "./samples/Bosendor/47 emp E3-.wav" 0 0 0
f769 0 0 1 "./samples/Bosendor/47 emp F3-.wav" 0 0 0
f770 0 0 1 "./samples/Bosendor/47 emp G3-.wav" 0 0 0
f771 0 0 1 "./samples/Bosendor/47 emp A3-.wav" 0 0 0
f772 0 0 1 "./samples/Bosendor/47 emp B3-.wav" 0 0 0
f773 0 0 1 "./samples/Bosendor/47 emp C4-.wav" 0 0 0
f774 0 0 1 "./samples/Bosendor/47 emp D4-.wav" 0 0 0
f775 0 0 1 "./samples/Bosendor/47 emp E4-.wav" 0 0 0
f776 0 0 1 "./samples/Bosendor/47 emp F4-.wav" 0 0 0
f777 0 0 1 "./samples/Bosendor/47 emp G4-.wav" 0 0 0
f778 0 0 1 "./samples/Bosendor/47 emp A4-.wav" 0 0 0
f779 0 0 1 "./samples/Bosendor/47 emp B4-.wav" 0 0 0
f780 0 0 1 "./samples/Bosendor/47 emp C5-.wav" 0 0 0
f781 0 0 1 "./samples/Bosendor/47 emp D5-.wav" 0 0 0
f782 0 0 1 "./samples/Bosendor/47 emp E5-.wav" 0 0 0
f783 0 0 1 "./samples/Bosendor/47 emp F5-.wav" 0 0 0
f784 0 0 1 "./samples/Bosendor/47 emp G5-.wav" 0 0 0
f785 0 0 1 "./samples/Bosendor/47 emp A5-.wav" 0 0 0
f786 0 0 1 "./samples/Bosendor/47 emp B5-.wav" 0 0 0
f787 0 0 1 "./samples/Bosendor/47 emp C6-.wav" 0 0 0
f788 0 0 1 "./samples/Bosendor/47 emp D6-.wav" 0 0 0
f789 0 0 1 "./samples/Bosendor/47 emp E6-.wav" 0 0 0
f790 0 0 1 "./samples/Bosendor/47 emp F6-.wav" 0 0 0
f791 0 0 1 "./samples/Bosendor/47 emp G6-.wav" 0 0 0
f792 0 0 1 "./samples/Bosendor/47 emp A6-.wav" 0 0 0
f793 0 0 1 "./samples/Bosendor/47 emp B6-.wav" 0 0 0
f794 0 0 1 "./samples/Bosendor/47 emp C7-.wav" 0 0 0
f795 0 0 1 "./samples/Bosendor/47 emp D7-.wav" 0 0 0
f796 0 0 1 "./samples/Bosendor/47 emp E7-.wav" 0 0 0
f797 0 0 1 "./samples/Bosendor/47 emp F7-.wav" 0 0 0
f798 0 0 1 "./samples/Bosendor/47 emp G7-.wav" 0 0 0
f799 0 0 1 "./samples/Bosendor/47 emp A7-.wav" 0 0 0
f800 0 0 1 "./samples/Bosendor/47 emp B7-.wav" 0 0 0
f801 0 0 1 "./samples/Bosendor/47 emp C8-.wav" 0 0 0
f806 0 0 1 "./samples/Bosendor/63 emp A0.wav" 0 0 0
f807 0 0 1 "./samples/Bosendor/63 emp B0-.wav" 0 0 0
f808 0 0 1 "./samples/Bosendor/63 emp C1-.wav" 0 0 0
f809 0 0 1 "./samples/Bosendor/63 emp D1-.wav" 0 0 0
f810 0 0 1 "./samples/Bosendor/63 emp E1-.wav" 0 0 0
f811 0 0 1 "./samples/Bosendor/63 emp F1-.wav" 0 0 0
f812 0 0 1 "./samples/Bosendor/63 emp G1-.wav" 0 0 0
f813 0 0 1 "./samples/Bosendor/63 emp A1.wav" 0 0 0
f814 0 0 1 "./samples/Bosendor/63 emp B1-.wav" 0 0 0
f815 0 0 1 "./samples/Bosendor/63 emp C2-.wav" 0 0 0
f816 0 0 1 "./samples/Bosendor/63 emp D2-.wav" 0 0 0
f817 0 0 1 "./samples/Bosendor/63 emp E2-.wav" 0 0 0
f818 0 0 1 "./samples/Bosendor/63 emp F2-.wav" 0 0 0
f819 0 0 1 "./samples/Bosendor/63 emp G2-.wav" 0 0 0
f820 0 0 1 "./samples/Bosendor/63 emp A2-.wav" 0 0 0
f821 0 0 1 "./samples/Bosendor/63 emp B2-.wav" 0 0 0
f822 0 0 1 "./samples/Bosendor/63 emp C3-.wav" 0 0 0
f823 0 0 1 "./samples/Bosendor/63 emp D3-.wav" 0 0 0
f824 0 0 1 "./samples/Bosendor/63 emp E3-.wav" 0 0 0
f825 0 0 1 "./samples/Bosendor/63 emp F3-.wav" 0 0 0
f826 0 0 1 "./samples/Bosendor/63 emp G3-.wav" 0 0 0
f827 0 0 1 "./samples/Bosendor/63 emp A3-.wav" 0 0 0
f828 0 0 1 "./samples/Bosendor/63 emp B3-.wav" 0 0 0
f829 0 0 1 "./samples/Bosendor/63 emp C4-.wav" 0 0 0
f830 0 0 1 "./samples/Bosendor/63 emp D4-.wav" 0 0 0
f831 0 0 1 "./samples/Bosendor/63 emp E4-.wav" 0 0 0
f832 0 0 1 "./samples/Bosendor/63 emp F4-.wav" 0 0 0
f833 0 0 1 "./samples/Bosendor/63 emp G4-.wav" 0 0 0
f834 0 0 1 "./samples/Bosendor/63 emp A4-.wav" 0 0 0
f835 0 0 1 "./samples/Bosendor/63 emp B4-.wav" 0 0 0
f836 0 0 1 "./samples/Bosendor/63 emp C5-.wav" 0 0 0
f837 0 0 1 "./samples/Bosendor/63 emp D5-.wav" 0 0 0
f838 0 0 1 "./samples/Bosendor/63 emp E5-.wav" 0 0 0
f839 0 0 1 "./samples/Bosendor/63 emp F5-.wav" 0 0 0
f840 0 0 1 "./samples/Bosendor/63 emp G5-.wav" 0 0 0
f841 0 0 1 "./samples/Bosendor/63 emp A5-.wav" 0 0 0
f842 0 0 1 "./samples/Bosendor/63 emp B5-.wav" 0 0 0
f843 0 0 1 "./samples/Bosendor/63 emp C6-.wav" 0 0 0
f844 0 0 1 "./samples/Bosendor/63 emp D6-.wav" 0 0 0
f845 0 0 1 "./samples/Bosendor/63 emp E6-.wav" 0 0 0
f846 0 0 1 "./samples/Bosendor/63 emp F6-.wav" 0 0 0
f847 0 0 1 "./samples/Bosendor/63 emp G6-.wav" 0 0 0
f848 0 0 1 "./samples/Bosendor/63 emp A6-.wav" 0 0 0
f849 0 0 1 "./samples/Bosendor/63 emp B6-.wav" 0 0 0
f850 0 0 1 "./samples/Bosendor/63 emp C7-.wav" 0 0 0
f851 0 0 1 "./samples/Bosendor/63 emp D7-.wav" 0 0 0
f852 0 0 1 "./samples/Bosendor/63 emp E7-.wav" 0 0 0
f853 0 0 1 "./samples/Bosendor/63 emp F7-.wav" 0 0 0
f854 0 0 1 "./samples/Bosendor/63 emp G7-.wav" 0 0 0
f855 0 0 1 "./samples/Bosendor/63 emp A7-.wav" 0 0 0
f856 0 0 1 "./samples/Bosendor/63 emp B7-.wav" 0 0 0
f857 0 0 1 "./samples/Bosendor/63 emp C8-.wav" 0 0 0
f862 0 0 1 "./samples/Bosendor/78 emp B0-.wav" 0 0 0
f863 0 0 1 "./samples/Bosendor/78 emp C1-.wav" 0 0 0
f864 0 0 1 "./samples/Bosendor/78 emp D1-.wav" 0 0 0
f865 0 0 1 "./samples/Bosendor/78 emp E1-.wav" 0 0 0
f866 0 0 1 "./samples/Bosendor/78 emp F1-.wav" 0 0 0
f867 0 0 1 "./samples/Bosendor/78 emp G1-.wav" 0 0 0
f868 0 0 1 "./samples/Bosendor/78 emp A1.wav" 0 0 0
f869 0 0 1 "./samples/Bosendor/78 emp B1-.wav" 0 0 0
f870 0 0 1 "./samples/Bosendor/78 emp C2-.wav" 0 0 0
f871 0 0 1 "./samples/Bosendor/78 emp D2-.wav" 0 0 0
f872 0 0 1 "./samples/Bosendor/78 emp E2-.wav" 0 0 0
f873 0 0 1 "./samples/Bosendor/78 emp F2-.wav" 0 0 0
f874 0 0 1 "./samples/Bosendor/78 emp G2-.wav" 0 0 0
f875 0 0 1 "./samples/Bosendor/78 emp A2-.wav" 0 0 0
f876 0 0 1 "./samples/Bosendor/78 emp B2-.wav" 0 0 0
f877 0 0 1 "./samples/Bosendor/78 emp C3-.wav" 0 0 0
f878 0 0 1 "./samples/Bosendor/78 emp D3-.wav" 0 0 0
f879 0 0 1 "./samples/Bosendor/78 emp E3-.wav" 0 0 0
f880 0 0 1 "./samples/Bosendor/78 emp F3-.wav" 0 0 0
f881 0 0 1 "./samples/Bosendor/78 emp G3-.wav" 0 0 0
f882 0 0 1 "./samples/Bosendor/78 emp A3-.wav" 0 0 0
f883 0 0 1 "./samples/Bosendor/78 emp B3-.wav" 0 0 0
f884 0 0 1 "./samples/Bosendor/78 emp C4-.wav" 0 0 0
f885 0 0 1 "./samples/Bosendor/78 emp D4-.wav" 0 0 0
f886 0 0 1 "./samples/Bosendor/78 emp E4-.wav" 0 0 0
f887 0 0 1 "./samples/Bosendor/78 emp F4-.wav" 0 0 0
f888 0 0 1 "./samples/Bosendor/78 emp G4-.wav" 0 0 0
f889 0 0 1 "./samples/Bosendor/78 emp A4-.wav" 0 0 0
f890 0 0 1 "./samples/Bosendor/78 emp B4-.wav" 0 0 0
f891 0 0 1 "./samples/Bosendor/78 emp C5-.wav" 0 0 0
f892 0 0 1 "./samples/Bosendor/78 emp D5-.wav" 0 0 0
f893 0 0 1 "./samples/Bosendor/78 emp E5-.wav" 0 0 0
f894 0 0 1 "./samples/Bosendor/78 emp F5-.wav" 0 0 0
f895 0 0 1 "./samples/Bosendor/78 emp G5-.wav" 0 0 0
f896 0 0 1 "./samples/Bosendor/78 emp A5-.wav" 0 0 0
f897 0 0 1 "./samples/Bosendor/78 emp B5-.wav" 0 0 0
f898 0 0 1 "./samples/Bosendor/78 emp C6-.wav" 0 0 0
f899 0 0 1 "./samples/Bosendor/78 emp D6-.wav" 0 0 0
f900 0 0 1 "./samples/Bosendor/78 emp E6-.wav" 0 0 0
f901 0 0 1 "./samples/Bosendor/78 emp F6-.wav" 0 0 0
f902 0 0 1 "./samples/Bosendor/78 emp G6-.wav" 0 0 0
f903 0 0 1 "./samples/Bosendor/78 emp A6-.wav" 0 0 0
f904 0 0 1 "./samples/Bosendor/78 emp B6-.wav" 0 0 0
f905 0 0 1 "./samples/Bosendor/78 emp C7-.wav" 0 0 0
f906 0 0 1 "./samples/Bosendor/78 emp D7-.wav" 0 0 0
f907 0 0 1 "./samples/Bosendor/78 emp E7-.wav" 0 0 0
f908 0 0 1 "./samples/Bosendor/78 emp F7-.wav" 0 0 0
f909 0 0 1 "./samples/Bosendor/78 emp G7-.wav" 0 0 0
f910 0 0 1 "./samples/Bosendor/78 emp A7-.wav" 0 0 0
f911 0 0 1 "./samples/Bosendor/78 emp B7-.wav" 0 0 0
f912 0 0 1 "./samples/Bosendor/78 emp C8-.wav" 0 0 0
f917 0 0 1 "./samples/Bosendor/85 emp A0.wav" 0 0 0
f918 0 0 1 "./samples/Bosendor/85 emp B0-.wav" 0 0 0
f919 0 0 1 "./samples/Bosendor/85 emp C1-.wav" 0 0 0
f920 0 0 1 "./samples/Bosendor/85 emp D1-.wav" 0 0 0
f921 0 0 1 "./samples/Bosendor/85 emp E1-.wav" 0 0 0
f922 0 0 1 "./samples/Bosendor/85 emp F1-.wav" 0 0 0
f923 0 0 1 "./samples/Bosendor/85 emp G1-.wav" 0 0 0
f924 0 0 1 "./samples/Bosendor/85 emp A1.wav" 0 0 0
f925 0 0 1 "./samples/Bosendor/85 emp B1-.wav" 0 0 0
f926 0 0 1 "./samples/Bosendor/85 emp C2-.wav" 0 0 0
f927 0 0 1 "./samples/Bosendor/85 emp D2-.wav" 0 0 0
f928 0 0 1 "./samples/Bosendor/85 emp E2-.wav" 0 0 0
f929 0 0 1 "./samples/Bosendor/85 emp F2-.wav" 0 0 0
f930 0 0 1 "./samples/Bosendor/85 emp G2-.wav" 0 0 0
f931 0 0 1 "./samples/Bosendor/85 emp A2-.wav" 0 0 0
f932 0 0 1 "./samples/Bosendor/85 emp B2-.wav" 0 0 0
f933 0 0 1 "./samples/Bosendor/85 emp C3-.wav" 0 0 0
f934 0 0 1 "./samples/Bosendor/85 emp D3-.wav" 0 0 0
f935 0 0 1 "./samples/Bosendor/85 emp E3-.wav" 0 0 0
f936 0 0 1 "./samples/Bosendor/85 emp F3-.wav" 0 0 0
f937 0 0 1 "./samples/Bosendor/85 emp G3-.wav" 0 0 0
f938 0 0 1 "./samples/Bosendor/85 emp A3-.wav" 0 0 0
f939 0 0 1 "./samples/Bosendor/85 emp B3-.wav" 0 0 0
f940 0 0 1 "./samples/Bosendor/85 emp C4-.wav" 0 0 0
f941 0 0 1 "./samples/Bosendor/85 emp D4-.wav" 0 0 0
f942 0 0 1 "./samples/Bosendor/85 emp E4-.wav" 0 0 0
f943 0 0 1 "./samples/Bosendor/85 emp F4-.wav" 0 0 0
f944 0 0 1 "./samples/Bosendor/85 emp G4-.wav" 0 0 0
f945 0 0 1 "./samples/Bosendor/85 emp A4-.wav" 0 0 0
f946 0 0 1 "./samples/Bosendor/85 emp B4-.wav" 0 0 0
f947 0 0 1 "./samples/Bosendor/85 emp C5-.wav" 0 0 0
f948 0 0 1 "./samples/Bosendor/85 emp D5-.wav" 0 0 0
f949 0 0 1 "./samples/Bosendor/85 emp E5-.wav" 0 0 0
f950 0 0 1 "./samples/Bosendor/85 emp F5-.wav" 0 0 0
f951 0 0 1 "./samples/Bosendor/85 emp G5-.wav" 0 0 0
f952 0 0 1 "./samples/Bosendor/85 emp A5-.wav" 0 0 0
f953 0 0 1 "./samples/Bosendor/85 emp B5-.wav" 0 0 0
f954 0 0 1 "./samples/Bosendor/85 emp C6-.wav" 0 0 0
f955 0 0 1 "./samples/Bosendor/85 emp D6-.wav" 0 0 0
f956 0 0 1 "./samples/Bosendor/85 emp E6-.wav" 0 0 0
f957 0 0 1 "./samples/Bosendor/85 emp F6-.wav" 0 0 0
f958 0 0 1 "./samples/Bosendor/85 emp G6-.wav" 0 0 0
f959 0 0 1 "./samples/Bosendor/85 emp A6-.wav" 0 0 0
f960 0 0 1 "./samples/Bosendor/85 emp B6-.wav" 0 0 0
f961 0 0 1 "./samples/Bosendor/85 emp C7-.wav" 0 0 0
f962 0 0 1 "./samples/Bosendor/85 emp D7-.wav" 0 0 0
f963 0 0 1 "./samples/Bosendor/85 emp E7-.wav" 0 0 0
f964 0 0 1 "./samples/Bosendor/85 emp F7-.wav" 0 0 0
f965 0 0 1 "./samples/Bosendor/85 emp G7-.wav" 0 0 0
f966 0 0 1 "./samples/Bosendor/85 emp A7-.wav" 0 0 0
f967 0 0 1 "./samples/Bosendor/85 emp B7-.wav" 0 0 0
f968 0 0 1 "./samples/Bosendor/85 emp C8-.wav" 0 0 0
; address of the ftables for instrument metadata. Instrument #1 metadata is located at 601, and #2 is a louder version of the same sample, located at 646. The rest of the instruments are located at 701, 747, 802, 858, and 913, where the loudest is located. The csound orchestra will choose which instrument number at execution time based on the volume level of the note being played. The louder the note, the higher the instrument number, and thus the more pressure on the piano hammer that was played to make the louder samples.
f1 0 64 -2 0 601 646 701 747 802 858 913 
; type of each instrument
;            1 2 3 4 5 6 7
f2 0 64 -2 0 5 5 5 5 5 5 5
f0 600 ; dummy f-statement to keep it running for 10 minutes
; end of modified 3/1/26
;Ins Star Dur Vel   Ton   Oct  Voice Stere Envlp Gliss Upsamp R-Env 2nd-gl 3rd Mult Line # ; Channel
;p1  p2   p3  p4    p5    p6   p7    p8    p9    p10   p11    p12   p13   p14  p15; Channel
; i1  0     4   69    000    4   1    8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   2    8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   3    8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   4    8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   5    8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   6    8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   7    8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   8    8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   9    8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   10   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   11   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   12   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   13   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   14   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   15   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   16   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   17   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   18   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   19   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   20   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   21   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   22   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   23   8     1     0     0     1     0     0    35 ;  
; i1  +     4   69    000    .   24   8     1     0     0     1     0     0    35 ;  
; t0   600
</CsScore>
</CsoundSynthesizer>