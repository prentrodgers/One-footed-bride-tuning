; started: 8/13/18 
; last edit: 4/30/23 
; again: 4/17/26 and many before that.
<CsoundSynthesizer> 
 
<CsOptions> 
; use the following for writing to a file -G is to create a postscript eps output file of function tables 
; -o dac ; live play 
 -o Music/sflib/ball9.wav -W -G -m2 -3 
</CsOptions> 
 
<CsInstruments> 
 giMoved = 0 
 ; I changed the sample rate to the maximum, 24 bit audio -3 option 
 ; sr = 192000 ; my laptop audio supports this high sample rate, but not the docking station 
 sr = 44100 
 ksmps = 5; any higher than 10 and I hear clicks - use 1 for final take 
 ; typically save 5x processing time by increasing ksmps by 10x 
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
 if p4 = 1 goto skipVel 
; 
; ; table f2 has the iSampleType values indicating type of sample 
 iSampleType table p7,2 ; from McGill.dat col 6 1: mono 2: stereo 4: Akai MDF??? 5: Gigasample 
; 
 iVelTemp = (p4 > 90 ? 90 : p4) ; make sure p4 velocity not greater than 90 
 iVel = (iVelTemp < 50 ? 50 : iVelTemp) ; nor less than 50 
 iVoicet = (iSampleType == 5 ? (p7 + max(iVel - 60, 0)/2) : p7) ; 2:1 volume change to sample change
 iVoicet = (iSampleType == 5 ? (min(iVoicet, 38)) : p7) 
 iVoice = int(iVoicet + 0.5) 
; print(p4, iVel, p7, iSampleType, iVoicet, iVoice) 
; table f1 has the start location of the sample tables control functions 
 iSampWaveTable table iVoice,1 ; find the location of the sample wave tables base on input p7 
; print(iSampWaveTable) 
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
 iHighValue table iLength-1, iSampWaveTable ; use last valid index, not guard point (guard may be 0)
 ; If MIDI note is outside sample range (iFtableTemp==0 from GEN17 initial value), clamp to highest valid sample
 if iFtableTemp == 0 then
     iFtableTemp = iHighValue
     iFtable = iHighValue
 endif
 ; GEN17 initial 0 means no sample assigned; use iFtableTemp as floor to avoid ftable 0 (mono)
 iLowValue = (iLowValue == 0 ? iFtableTemp : iLowValue)
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
 ; ivoice, iFtableTemp iFtable giMoved always print 
 ; + + + + + 
 if iFtable != iFtableTemp then 
 printf_i "voice: %i. switched sample from %i to %i. Total moved so far: %i\n", 1, iVoice, iFtableTemp, iFtable, giMoved 
 else 
 printf_i "voice: %i. no switch %i == %i\n", 1, iVoice, iFtableTemp, iFtable 
 endif 
 iFound: ; nothing found the target sample in the sample collection. Move ok. 
 
 iamp = ampdb(iVel) * p15 / 5 ; velocity input is 60-80 - convert to amplitude 
 ; End of modification 5/4/22 
 i9 = 298-p9 ; valid envelope table number are 298, 297, 296, 295 etc. - left channel 
 i12 = 298-p12 ; valid envelope table number are 298, 297, 296, 295 etc. - right channel 
 i12 = 298-p12 ; valid envelope table number are 298, 297, 296, 295 etc. - right channel 
 i10 = p10 ; glissando #1 
 i13 = p13 ; glissando #2
 i14 = p14 ; glissando #3
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
 ; Still have yet to implement the 3rd glissando. 
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
f307 0 256 -7 .5 256 .5 ; constant 0.5 multiplier — drops playback frequency one octave (used by bass_part octave-0 rescue)
f308 0 256 -7 .25 256 .25 ; constant 0.25 multiplier — drops playback frequency two octaves (used by bass_part octave-0 rescue)
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
; Orchestra: finger piano (112), bass finger piano (159), balloon drums (155, 156, 157), bass flute (96), oboe (10), 
; 9 10 11 
; clarinet (77), bassoon (71), french horn (102) 
; 
f601 0 128 -17 0 605 13 606 17 607 20 608 22 609 25 610 27 611 30 612 32 613 34 614 37 615 39 616 41 617 44 618 46 619 49 620 51 621 53 622 54 623 56 624 61 625 63 626 66 627 68 628 70 629 73 
f602 0 64 -2 0  12  16  19  21  24  26  29  31  33  36  38  40  43  45  48  50  52  53  55  60  62  65  67  69  72 
f603 0 64 -2 0 +0  -4  0   0   0   0   0   0   0   0   -3  +5  +1  0   -1  +1  +4  +6  -1  -1  -1  0   -2  0   -1  
f604 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
; Orchestra: 
; voices instrument csound samples # samples 
; finger_piano_part: voice # McGill instrument # 
; 6 finger piano 1 1 112 
; 2 bass finger piano 1 24 
; 8 pizzicato 4 
; violin-pizz 1 19 57 
; viola-pizz 1 11 52 
; cello-pizz 1 14 74 
; 4 marimbas 1 18 8 
; 4 xylophone 1 20 65 
; 4 vibraphone 1 13 47 
; 4 harp 1 20 3 
; 8 martele strings 4 
; violin martele 1 17 56 
; viola martele 1 16 51 
; cello martele 1 20 73 
; woodwind_part: 
; 8 woodwinds 5 
; bassoon 1 6 71 
; clarinet 1 19 77 
; flute no vib 1 14 100 
; oboe 1 15 10 
; french horn 1 17 102 
; 8 bowed strings vib 4 
; violin 1 19 58 
; viola 1 18 53 
; cello 1 20 75 
; 8 trumpet 2 25 40 
; trombone 
; tuba 
; ------------------------------------------ 
; total samples 329 
; both parts: Wait a bit before adding the piano. It's terribly complicated and prone to untraceable errors. 
; 8 Bosendorfer 11 494 184 
; ------- 
; 823 samples in total 
; 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 
f630 0 128 -17 0 634 44 635 48 636 50 637 52 638 54 639 56 640 58 641 60 642 62 643 64 644 66 645 68 646 70 647 72 648 74 649 76 650 78 651 80 
f631 0 64 -2 0  43  47  49  51  53  55  57  59  61  63  65  67  69  71  73  75  77  79 
f632 0 64 -2 0 -6  -8  +2  -13 +17 -4  0   0   0   0   0   0   0   0   0   0   0   0   
f633 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f652 0 128 -17 0 656 49 657 52 658 55 659 58 660 64 661 67 662 70 663 73 664 76 665 79 666 82 
f653 0 64 -2 0  48  51  54  57  63  66  69  72  75  78  81 
f654 0 64 -2 0 -13 -31 0   0   0   0   +6  0   +13 0   0   
f655 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 
f667 0 128 -17 0 671 37 672 41 673 46 674 50 675 53 676 60 677 61 678 65 679 67 680 69 681 72 682 75 
f668 0 64 -2 0  36  40  45  49  52  59  60  64  66  68  71  74 
f669 0 64 -2 0 +13 +49 -6  +11 +1  +8  +1  +8  +7  0   0   0   
f670 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 
f683 0 128 -17 0 687 30 688 33 689 36 690 39 691 45 692 48 693 51 694 54 695 57 696 60 697 63 698 66 699 69 700 73 701 75 702 78 703 81 704 84 
f684 0 64 -2 0  29  32  35  38  44  47  50  53  56  59  62  65  68  72  74  77  80  83 
f685 0 64 -2 0 +8  +5  +8  +11 +7  +7  +5  +6  -2  -8  +5  +5  +3  +2  +9  +5  +4  +7  
f686 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f705 0 128 -17 0 709 54 710 56 711 58 712 60 713 62 714 64 715 66 716 68 717 70 718 72 719 74 720 76 721 78 722 80 723 82 724 84 725 86 
f706 0 64 -2 0  53  55  57  59  61  63  65  67  69  71  73  75  77  79  81  83  85 
f707 0 64 -2 0 +14 +13 +13 +12 +12 +13 +12 +13 +13 0   0   0   0   0   0   +18 +19 
f708 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f726 0 128 -17 0 730 42 731 46 732 50 733 52 734 55 735 58 736 61 737 64 738 67 739 71 740 74 741 78 
f727 0 64 -2 0  41  45  49  51  54  57  60  63  66  70  73  77 
f728 0 64 -2 0 +6  +6  +6  +6  +5  +4  +4  +4  +5  +5  +7  +6  
f729 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 
f742 0 128 -17 0 746 14 747 16 748 18 749 21 750 24 751 28 752 30 753 35 754 41 755 44 756 47 757 50 758 53 759 57 760 61 761 65 762 68 763 76 764 80 765 84 
f743 0 64 -2 0  13  15  17  20  23  27  29  34  40  43  46  49  52  56  60  64  67  75  79  83 
f744 0 64 -2 0 -25 -33 -16 +1  +1  -1  -3  +12 -11 +1  -4  +13 +3  -6  +4  -7  +2  -8  0   -21 
f745 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f766 0 128 -17 0 770 44 771 46 772 48 773 50 774 52 775 54 776 56 777 58 778 60 779 62 780 64 781 66 782 68 783 70 784 72 785 74 786 76 
f767 0 64 -2 0  43  45  47  49  51  53  55  57  59  61  63  65  67  69  71  73  75 
f768 0 64 -2 0 -9  -12 +4  +8  +3  +7  -8  +9  +4  +24 +14 0   +3  0   0   0   0   
f769 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f787 0 128 -17 0 791 37 792 39 793 41 794 43 795 46 796 49 797 51 798 53 799 55 800 58 801 60 802 62 803 64 804 69 805 71 806 73 
f788 0 64 -2 0  36  38  40  42  45  48  50  52  54  57  59  61  63  68  70  72 
f789 0 64 -2 0 -11 -21 -13 -25 0   -2  -2  -33 -28 +9  0   0   -31 0   0   0   
f790 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f807 0 128 -17 0 811 25 812 27 813 29 814 31 815 33 816 35 817 37 818 39 819 41 820 43 821 47 822 49 823 51 824 53 825 55 826 57 827 59 828 61 829 63 
f808 0 64 -2 0  24  26  28  30  32  34  36  38  40  42  46  48  50  52  54  56  58  60  62 
f809 0 64 -2 0 +38 +6  0   -3  -9  -8  +8  -10 -9  -2  +1  0   -25 -5  -9  +24 -16 +15 +12 
f810 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f830 0 128 -17 0 834 23 835 25 836 27 837 29 838 31 839 33 840 35 841 37 842 39 843 41 844 43 845 45 846 47 847 49 848 51 849 53 
f831 0 64 -2 0  22  24  26  28  30  32  34  36  38  40  42  44  46  48  50  52 
f832 0 64 -2 0 +5  +7  +12 +2  -2  +5  +2  +1  +3  -3  -1  -6  +2  +2  +1  0   
f833 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f850 0 128 -17 0 854 39 855 41 856 43 857 45 858 47 859 49 860 53 861 55 862 57 863 59 864 61 865 63 866 65 867 67 868 69 869 71 870 73 871 75 
f851 0 64 -2 0  38  40  42  44  46  48  52  54  56  58  60  62  64  66  68  70  72  74 
f852 0 64 -2 0 +1  +5  +1  0   +7  +2  +5  +1  +2  +1  +4  +1  +4  +5  +3  +2  +2  +1  
f853 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f872 0 128 -17 0 876 49 877 51 878 55 879 59 880 65 881 70 882 72 883 74 884 76 885 78 886 80 887 82 888 84 889 85 
f873 0 64 -2 0  48  50  54  58  64  69  71  73  75  77  79  81  83  84 
f874 0 64 -2 0 -2  -8  +10 +12 +3  -2  +7  +8  +6  +7  +6  +4  +7  +22 
f875 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f890 0 128 -17 0 894 47 895 49 896 51 897 53 898 55 899 57 900 59 901 61 902 63 903 65 904 69 905 71 906 73 907 75 908 77 
f891 0 64 -2 0  46  48  50  52  54  56  58  60  62  64  68  70  72  74  76 
f892 0 64 -2 0 -12 +4  +6  +7  +9  +10 -8  -7  +15 +8  +5  +2  +14 +12 +22 
f893 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f909 0 128 -17 0 913 27 914 29 915 31 916 33 917 35 918 39 919 41 920 43 921 45 922 47 923 49 924 51 925 53 926 55 927 59 928 61 929 63 
f910 0 64 -2 0  26  28  30  32  34  38  40  42  44  46  48  50  52  54  58  60  62 
f911 0 64 -2 0 +1  -2  +3  -15 +5  -4  +13 -1  -6  -9  -5  +1  +2  -7  -6  +1  +3  
f912 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f930 0 128 -17 0 934 45 935 47 936 49 937 51 938 53 939 55 940 57 941 59 942 62 943 64 944 66 945 68 946 70 947 72 948 74 949 76 950 78 951 80 952 82 
f931 0 64 -2 0  44  46  48  50  52  54  56  58  61  63  65  67  69  71  73  75  77  79  81 
f932 0 64 -2 0 +3  -3  -1  +1  +3  -7  -2  -7  +14 +21 0   +6  -8  +6  -30 +9  -18 +8  -19 
f933 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f953 0 128 -17 0 957 38 958 39 959 41 960 43 961 45 962 47 963 49 964 51 965 53 966 55 967 57 968 59 969 61 970 65 971 67 972 70 973 72 974 74 
f954 0 64 -2 0  37  38  40  42  44  46  48  50  52  54  56  58  60  64  66  69  71  73 
f955 0 64 -2 0 -14 -26 -33 -13 -26 -13 -10 -3  -18 -40 -5  -1  -2  +0  +13 -1  -6  -5  
f956 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f975 0 128 -17 0 979 26 980 28 981 30 982 32 983 34 984 36 985 38 986 40 987 42 988 44 989 46 990 48 991 50 992 52 993 54 994 56 995 58 996 60 997 62 998 64 
f976 0 64 -2 0  25  27  29  31  33  35  37  39  41  43  45  47  49  51  53  55  57  59  61  63 
f977 0 64 -2 0 +1  +2  0   0   -1  -4  -1  +3  -3  -3  -11 -5  -8  -8  -5  -4  -2  -2  +14 -35 
f978 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f999 0 128 -17 0 1003 24 1004 26 1005 28 1006 29 1007 31 1008 33 1009 34 1010 36 1011 38 1012 39 1013 41 1014 43 1015 45 1016 47 1017 48 1018 50 1019 52 1020 54 1021 56 1022 58 1023 60 1024 62 1025 64 1026 66 1027 68 1028 70 1029 72 
f1000 0 64 -2 0  23  25  27  28  30  32  33  35  37  38  40  42  44  46  47  49  51  53  55  57  59  61  63  65  67  69  71 
f1001 0 64 -2 0 -9  -7  -6  -15 -4  -7  -9  +2  -5  -9  -5  +3  -6  +5  -14 -1  -1  +25 +6  -7  +2  -1  -2  +0  -2  -6  +11 
f1002 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1030 0 128 -17 0 1034 29 1035 31 1036 33 1037 34 1038 36 1039 38 1040 39 1041 41 1042 43 1043 44 1044 46 1045 48 1046 49 1047 51 1048 53 1049 55 1050 57 1051 59 1052 61 1053 63 1054 65 1055 67 1056 69 1057 71 1058 73 1059 75 1060 77 1061 79 
  1062 81 1063 83 1064 85 1065 87 1066 91 1067 93 1068 95 1069 97 
f1031 0 64 -2 0  28  30  32  33  35  37  38  40  42  43  45  47  48  50  52  54  56  58  60  62  64  66  68  70  72  74  76  78  80  82  84  86  90  92  94  96 
f1032 0 64 -2 0 -9  0   -3  -4  -3  -10 -3  -4  -4  -6  0   -5  +1  -2  -5  -5  0   -2  0   0   0   +2  -2  -3  0   +1  -1  0   0   -13 -15 -29 -16 -47 +28 -37 
f1033 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1070 0 128 -17 0 1074 12 1075 13 1076 15 1077 17 1078 18 1079 20 1080 22 1081 24 1082 25 1083 27 1084 29 1085 30 1086 32 1087 34 1088 36 1089 37 1090 39 1091 41 1092 42 1093 44 1094 46 1095 48 1096 49 1097 51 1098 53 1099 54 1100 56 1101 58 
  1102 60 1103 61 
f1071 0 64 -2 0  11  12  14  16  17  19  21  23  24  26  28  29  31  33  35  36  38  40  41  43  45  47  48  50  52  53  55  57  59  60 
f1072 0 64 -2 0 +1  +1  -3  -1  +1  -1  0   0   0   0   0   +2  +5  0   0   0   0   -2  -5  0   +1  -1  -1  0   0   -5  -5  0   +3  -3  
f1073 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1104 0 128 -17 0 1108 40 1109 41 1110 45 1111 46 1112 47 1113 48 1114 49 1115 50 1116 51 1117 52 1118 53 1119 55 1120 57 1121 59 1122 61 1123 63 1124 65 1125 67 1126 69 1127 72 1128 74 1129 76 
f1105 0 64 -2 0  39  40  44  45  46  47  48  49  50  51  52  54  56  58  60  62  64  66  68  71  73  75 
f1106 0 64 -2 0 -49 +56 -9  +23 +22 -5  +16 +10 -22 -17 -5  +2  -3  +2  -27 -30 -5  +6  -3  +10 -11 +0  
f1107 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1130 0 128 -17 0 1134 8 1135 9 1136 11 1137 13 1138 15 1139 20 1140 22 1141 25 1142 27 1143 29 1144 31 1145 34 1146 35 1147 37 1148 39 1149 42 1150 45 1151 47 1152 51 1153 55 1154 58 1155 63 
f1131 0 64 -2 0   7   8  10  12  14  19  21  24  26  28  30  33  34  36  38  41  44  46  50  54  57  62 
f1132 0 64 -2 0 +0  -31 -20 -16 +9  +18 +22 -11 -39 +12 +17 -33 -4  +16 +45 -31 +0  +43 -7  -1  +34 -41 
f1133 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1156 0 128 -17 0 1160 43 1161 45 1162 47 1163 49 1164 51 1165 53 1166 55 1167 57 1168 59 1169 61 1170 63 1171 65 1172 67 1173 69 1174 71 1175 73 1176 75 
f1157 0 64 -2 0  42  44  46  48  50  52  54  56  58  60  62  64  66  68  70  72  74 
f1158 0 64 -2 0 +2  -4  +5  +8  -10 -5  +2  +3  -1  0   +1  +1  -4  +6  0   -2  -6  
f1159 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f1177 0 128 -17 0 1181 29 1182 32 1183 35 1184 38 1185 41 1186 44 1187 47 1188 50 1189 53 1190 56 1191 59 
f1178 0 64 -2 0  28  31  34  37  40  43  46  49  52  55  58 
f1179 0 64 -2 0 0   -7  -1  -4  -7  0   -9  +6  +5  +3  -6  
f1180 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 
f1192 0 128 -17 0 1196 25 1197 27 1198 30 1199 32 1200 34 1201 36 1202 38 1203 40 1204 42 1205 44 1206 46 1207 48 1208 50 1209 52 1210 54 1211 56 
f1193 0 64 -2 0  24  26  29  31  33  35  37  39  41  43  45  47  49  51  53  55 
f1194 0 64 -2 0 +6  +2  +4  0   +2  +4  +1  -6  +1  +1  +2  +3  +1  +3  +4  +6  
f1195 0 64 -2 0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 
f1212 0 128 -17 0 1216 58 
f1213 0 64 -2 0  57 
f1214 0 64 -2 0  0  
f1215 0 64 -2 0 1 
f1217 0 128 -17 0 1221 10 1222 12 1223 13 1224 15 1225 17 1226 18 1227 20 1228 22 1229 24 1230 25 1231 27 1232 29 1233 30 1234 32 1235 34 1236 36 1237 37 1238 48 1239 51 1240 53 1241 60 1242 61 1243 63 1244 65 1245 66 1246 68 1247 73 1248 75 
  1249 77 1250 78 1251 80 1252 82 1253 84 1254 85 1255 87 1256 89 1257 90 1258 92 1259 94 1260 96 1261 97 
f1218 0 64 -2 0   9  11  12  14  16  17  19  21  23  24  26  28  29  31  33  35  36  47  50  52  59  60  62  64  65  67  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96 
f1219 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f1220 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1262 0 128 -17 0 1266 10 1267 12 1268 13 1269 15 1270 17 1271 18 1272 20 1273 22 1274 24 1275 25 1276 27 1277 29 1278 30 1279 32 1280 34 1281 36 1282 37 1283 39 1284 41 1285 42 1286 44 1287 46 1288 48 1289 49 1290 51 1291 53 1292 54 1293 56 
  1294 58 1295 60 1296 61 1297 63 1298 65 1299 66 1300 68 1301 70 1302 72 1303 73 1304 75 1305 77 1306 78 1307 80 1308 82 1309 85 1310 87 1311 89 1312 90 1313 92 1314 94 1315 96 1316 97 
f1263 0 64 -2 0   9  11  12  14  16  17  19  21  23  24  26  28  29  31  33  35  36  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  84  86  88  89  91  93  95  96 
f1264 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f1265 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1317 0 128 -17 0 1321 10 1322 12 1323 13 1324 15 1325 17 1326 18 1327 20 1328 22 1329 25 1330 27 1331 29 1332 30 1333 32 1334 34 1335 36 1336 37 1337 41 1338 44 1339 48 1340 49 1341 51 1342 61 1343 63 1344 65 1345 66 1346 68 1347 72 1348 73 
  1349 75 1350 77 1351 78 1352 80 1353 82 1354 84 1355 85 1356 87 1357 89 1358 90 1359 92 1360 94 1361 96 1362 97 
f1318 0 64 -2 0   9  11  12  14  16  17  19  21  24  26  28  29  31  33  35  36  40  43  47  48  50  60  62  64  65  67  71  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96 
f1319 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f1320 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1363 0 128 -17 0 1367 10 1368 12 1369 13 1370 15 1371 17 1372 18 1373 20 1374 22 1375 24 1376 27 1377 29 1378 30 1379 32 1380 34 1381 36 1382 37 1383 39 1384 41 1385 42 1386 44 1387 46 1388 48 1389 49 1390 51 1391 53 1392 54 1393 56 1394 58 
  1395 60 1396 61 1397 63 1398 65 1399 66 1400 68 1401 70 1402 72 1403 73 1404 75 1405 77 1406 78 1407 80 1408 82 1409 84 1410 85 1411 87 1412 89 1413 90 1414 92 1415 94 1416 96 1417 97 
f1364 0 64 -2 0   9  11  12  14  16  17  19  21  23  26  28  29  31  33  35  36  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96 
f1365 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f1366 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1418 0 128 -17 0 1422 10 1423 12 1424 13 1425 15 1426 17 1427 18 1428 20 1429 22 1430 24 1431 25 1432 27 1433 29 1434 30 1435 32 1436 34 1437 36 1438 37 1439 39 1440 41 1441 42 1442 44 1443 46 1444 48 1445 49 1446 51 1447 53 1448 54 1449 56 
  1450 58 1451 60 1452 61 1453 63 1454 65 1455 66 1456 68 1457 70 1458 72 1459 73 1460 75 1461 77 1462 78 1463 80 1464 82 1465 84 1466 85 1467 87 1468 89 1469 90 1470 92 1471 94 1472 96 1473 97 
f1419 0 64 -2 0   9  11  12  14  16  17  19  21  23  24  26  28  29  31  33  35  36  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96 
f1420 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f1421 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1474 0 128 -17 0 1478 12 1479 13 1480 15 1481 17 1482 18 1483 20 1484 22 1485 24 1486 25 1487 27 1488 29 1489 30 1490 32 1491 34 1492 36 1493 37 1494 39 1495 41 1496 42 1497 44 1498 46 1499 48 1500 49 1501 51 1502 53 1503 54 1504 56 1505 58 
  1506 60 1507 61 1508 63 1509 65 1510 66 1511 68 1512 70 1513 72 1514 73 1515 75 1516 77 1517 78 1518 80 1519 82 1520 84 1521 85 1522 87 1523 89 1524 90 1525 92 1526 94 1527 96 1528 97 
f1475 0 64 -2 0  11  12  14  16  17  19  21  23  24  26  28  29  31  33  35  36  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96 
f1476 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f1477 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1529 0 128 -17 0 1533 10 1534 12 1535 13 1536 15 1537 17 1538 18 1539 20 1540 22 1541 24 1542 25 1543 27 1544 29 1545 30 1546 32 1547 34 1548 36 1549 37 1550 39 1551 41 1552 42 1553 44 1554 46 1555 48 1556 49 1557 51 1558 53 1559 54 1560 56 
  1561 58 1562 60 1563 61 1564 63 1565 65 1566 66 1567 68 1568 70 1569 72 1570 73 1571 75 1572 77 1573 78 1574 80 1575 82 1576 84 1577 85 1578 87 1579 89 1580 90 1581 92 1582 94 1583 96 1584 97 
f1530 0 64 -2 0   9  11  12  14  16  17  19  21  23  24  26  28  29  31  33  35  36  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96 
f1531 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f1532 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1585 0 128 -17 0 1589 10 1590 12 1591 13 1592 15 1593 17 1594 18 1595 20 1596 22 1597 24 1598 25 1599 27 1600 29 1601 30 1602 32 1603 34 1604 36 1605 37 1606 39 1607 41 1608 42 1609 44 1610 46 1611 48 1612 49 1613 51 1614 53 1615 54 1616 56 
  1617 58 1618 60 1619 61 1620 63 1621 65 1622 66 1623 68 1624 70 1625 72 1626 73 1627 75 1628 77 1629 78 1630 80 1631 82 1632 84 1633 85 1634 87 1635 89 1636 90 1637 92 1638 94 1639 96 1640 97 
f1586 0 64 -2 0   9  11  12  14  16  17  19  21  23  24  26  28  29  31  33  35  36  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96 
f1587 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f1588 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1641 0 128 -17 0 1645 10 1646 12 1647 13 1648 15 1649 17 1650 18 1651 20 1652 22 1653 24 1654 25 1655 27 1656 29 1657 30 1658 34 1659 36 1660 37 1661 39 1662 41 1663 42 1664 44 1665 46 1666 48 1667 49 1668 51 1669 53 1670 54 1671 56 1672 58 
  1673 60 1674 61 1675 63 1676 65 1677 66 1678 68 1679 70 1680 72 1681 73 1682 75 1683 77 1684 78 1685 80 1686 82 1687 84 1688 85 1689 87 1690 89 1691 90 1692 92 1693 94 1694 96 1695 97 
f1642 0 64 -2 0   9  11  12  14  16  17  19  21  23  24  26  28  29  33  35  36  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96 
f1643 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f1644 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
f1696 0 128 -17 0 1700 10 1701 12 1702 13 1703 15 1704 17 1705 18 1706 20 1707 22 1708 24 1709 25 1710 27 1711 29 1712 30 1713 32 1714 34 1715 36 1716 39 1717 41 1718 42 1719 44 1720 46 1721 48 1722 49 1723 51 1724 53 1725 54 1726 56 1727 58 
  1728 60 1729 61 1730 63 1731 65 1732 66 1733 68 1734 70 1735 72 1736 73 1737 75 1738 77 1739 78 1740 80 1741 82 1742 84 1743 85 1744 87 1745 89 1746 90 1747 92 1748 94 1749 96 1750 97 
f1697 0 64 -2 0   9  11  12  14  16  17  19  21  23  24  26  28  29  31  33  35  38  40  41  43  45  47  48  50  52  53  55  57  59  60  62  64  65  67  69  71  72  74  76  77  79  81  83  84  86  88  89  91  93  95  96 
f1698 0 64 -2 0 0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   
f1699 0 64 -2 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 
; 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 
f605 0 0 1 "samples/FingerP/c1.aif" 0 0 0
f606 0 0 1 "samples/FingerP/e1.aif" 0 0 0
f607 0 0 1 "samples/FingerP/g1.aif" 0 0 0
f608 0 0 1 "samples/FingerP/a1.aif" 0 0 0
f609 0 0 1 "samples/FingerP/c2.aif" 0 0 0
f610 0 0 1 "samples/FingerP/d2.aif" 0 0 0
f611 0 0 1 "samples/FingerP/f2.aif" 0 0 0
f612 0 0 1 "samples/FingerP/g2.aif" 0 0 0
f613 0 0 1 "samples/FingerP/a2.aif" 0 0 0
f614 0 0 1 "samples/FingerP/c3.aif" 0 0 0
f615 0 0 1 "samples/FingerP/d3.aif" 0 0 0
f616 0 0 1 "samples/FingerP/e3.aif" 0 0 0
f617 0 0 1 "samples/FingerP/g3.aif" 0 0 0
f618 0 0 1 "samples/FingerP/a3.aif" 0 0 0
f619 0 0 1 "samples/FingerP/c4.aif" 0 0 0
f620 0 0 1 "samples/FingerP/d4.aif" 0 0 0
f621 0 0 1 "samples/FingerP/e4.aif" 0 0 0
f622 0 0 1 "samples/FingerP/f4.aif" 0 0 0
f623 0 0 1 "samples/FingerP/g4.aif" 0 0 0
f624 0 0 1 "samples/FingerP/c5.aif" 0 0 0
f625 0 0 1 "samples/FingerP/d5.aif" 0 0 0
f626 0 0 1 "samples/FingerP/f5.aif" 0 0 0
f627 0 0 1 "samples/FingerP/g5.aif" 0 0 0
f628 0 0 1 "samples/FingerP/a5.aif" 0 0 0
f629 0 0 1 "samples/FingerP/c6.aif" 0 0 0
f634 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP G3.aif" 0 0 0
f635 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP B3.aif" 0 0 0
f636 0 0 1 "samples/VIOLIN-PIZZ/VIOLINPC#4.aif" 0 0 0
f637 0 0 1 "samples/VIOLIN-PIZZ/VIOLINPD#4.aif" 0 0 0
f638 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP F4.aif" 0 0 0
f639 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP G4.aif" 0 0 0
f640 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP A4.aif" 0 0 0
f641 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP B4.aif" 0 0 0
f642 0 0 1 "samples/VIOLIN-PIZZ/VIOLINPC#5.aif" 0 0 0
f643 0 0 1 "samples/VIOLIN-PIZZ/VIOLINPD#5.aif" 0 0 0
f644 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP F5.aif" 0 0 0
f645 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP G5.aif" 0 0 0
f646 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP A5.aif" 0 0 0
f647 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP B5.aif" 0 0 0
f648 0 0 1 "samples/VIOLIN-PIZZ/VIOLINPC#6.aif" 0 0 0
f649 0 0 1 "samples/VIOLIN-PIZZ/VIOLINPD#6.aif" 0 0 0
f650 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP F6.aif" 0 0 0
f651 0 0 1 "samples/VIOLIN-PIZZ/VIOLINP G6.aif" 0 0 0
f656 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZC3.aif" 0 0 0
f657 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZD#3.aif" 0 0 0
f658 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZF#3.aif" 0 0 0
f659 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZA3.aif" 0 0 0
f660 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZD#4.aif" 0 0 0
f661 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZF#4.aif" 0 0 0
f662 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZA4.aif" 0 0 0
f663 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZC5.aif" 0 0 0
f664 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZD#5.aif" 0 0 0
f665 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZF#5.aif" 0 0 0
f666 0 0 1 "samples/VIOLA-PIZZ/VIOLAPZA5.aif" 0 0 0
f671 0 0 1 "samples/CELLO PIZZ/P CELLOC2.aif" 0 0 0
f672 0 0 1 "samples/CELLO PIZZ/P CELLOE2.aif" 0 0 0
f673 0 0 1 "samples/CELLO PIZZ/P CELLOA2.aif" 0 0 0
f674 0 0 1 "samples/CELLO PIZZ/P CELLOC#3.aif" 0 0 0
f675 0 0 1 "samples/CELLO PIZZ/P CELLOE3.aif" 0 0 0
f676 0 0 1 "samples/CELLO PIZZ/P CELLOB3.aif" 0 0 0
f677 0 0 1 "samples/CELLO PIZZ/P CELLOC4.aif" 0 0 0
f678 0 0 1 "samples/CELLO PIZZ/P CELLOE4.aif" 0 0 0
f679 0 0 1 "samples/CELLO PIZZ/P CELLOF#4.aif" 0 0 0
f680 0 0 1 "samples/CELLO PIZZ/P CELLOG#4.aif" 0 0 0
f681 0 0 1 "samples/CELLO PIZZ/P CELLOB4.aif" 0 0 0
f682 0 0 1 "samples/CELLO PIZZ/P CELLOD5.aif" 0 0 0
f687 0 0 1 "samples/MARIMBA/MARIMBA F2.aif" 0 0 0
f688 0 0 1 "samples/MARIMBA/MARIMBAG#2.aif" 0 0 0
f689 0 0 1 "samples/MARIMBA/MARIMBA B2-f.aif" 0 0 0
f690 0 0 1 "samples/MARIMBA/MARIMBA D3-f.aif" 0 0 0
f691 0 0 1 "samples/MARIMBA/MARIMBAG#3-f.aif" 0 0 0
f692 0 0 1 "samples/MARIMBA/MARIMBA B3-f.aif" 0 0 0
f693 0 0 1 "samples/MARIMBA/MARIMBA D4-f.aif" 0 0 0
f694 0 0 1 "samples/MARIMBA/MARIMBA F4-f.aif" 0 0 0
f695 0 0 1 "samples/MARIMBA/MARIMBAG#4-f.aif" 0 0 0
f696 0 0 1 "samples/MARIMBA/MARIMBA B4-f.aif" 0 0 0
f697 0 0 1 "samples/MARIMBA/MARIMBA D5-f.aif" 0 0 0
f698 0 0 1 "samples/MARIMBA/MARIMBA F5-f.aif" 0 0 0
f699 0 0 1 "samples/MARIMBA/MARIMBAG#5.aif" 0 0 0
f700 0 0 1 "samples/MARIMBA/MARIMBA C6-f.aif" 0 0 0
f701 0 0 1 "samples/MARIMBA/MARIMBA D6-f.aif" 0 0 0
f702 0 0 1 "samples/MARIMBA/MARIMBA F6-f.aif" 0 0 0
f703 0 0 1 "samples/MARIMBA/MARIMBAG#6.aif" 0 0 0
f704 0 0 1 "samples/MARIMBA/MARIMBA B6-f.aif" 0 0 0
f709 0 0 1 "samples/XYLOPHONE/XYLO F4.aif" 0 0 0
f710 0 0 1 "samples/XYLOPHONE/XYLO G4.aif" 0 0 0
f711 0 0 1 "samples/XYLOPHONE/XYLO A4.aif" 0 0 0
f712 0 0 1 "samples/XYLOPHONE/XYLO B4.aif" 0 0 0
f713 0 0 1 "samples/XYLOPHONE/XYLO C#5.aif" 0 0 0
f714 0 0 1 "samples/XYLOPHONE/XYLO D#5.aif" 0 0 0
f715 0 0 1 "samples/XYLOPHONE/XYLO F5.aif" 0 0 0
f716 0 0 1 "samples/XYLOPHONE/XYLO G5.aif" 0 0 0
f717 0 0 1 "samples/XYLOPHONE/XYLO A5.aif" 0 0 0
f718 0 0 1 "samples/XYLOPHONE/XYLO B5.aif" 0 0 0
f719 0 0 1 "samples/XYLOPHONE/XYLO C#6.aif" 0 0 0
f720 0 0 1 "samples/XYLOPHONE/XYLO D#6.aif" 0 0 0
f721 0 0 1 "samples/XYLOPHONE/XYLO F6.aif" 0 0 0
f722 0 0 1 "samples/XYLOPHONE/XYLO G6.aif" 0 0 0
f723 0 0 1 "samples/XYLOPHONE/XYLO A6.aif" 0 0 0
f724 0 0 1 "samples/XYLOPHONE/XYLO B6.aif" 0 0 0
f725 0 0 1 "samples/XYLOPHONE/XYLO C#7.aif" 0 0 0
f730 0 0 1 "samples/VIBRAPHONE/VIBES F3.aif" 0 0 0
f731 0 0 1 "samples/VIBRAPHONE/VIBES A3.aif" 0 0 0
f732 0 0 1 "samples/VIBRAPHONE/VIBES C#4.aif" 0 0 0
f733 0 0 1 "samples/VIBRAPHONE/VIBES D#4.aif" 0 0 0
f734 0 0 1 "samples/VIBRAPHONE/VIBES F#4.aif" 0 0 0
f735 0 0 1 "samples/VIBRAPHONE/VIBES A4.aif" 0 0 0
f736 0 0 1 "samples/VIBRAPHONE/VIBES C5.aif" 0 0 0
f737 0 0 1 "samples/VIBRAPHONE/VIBES D#5.aif" 0 0 0
f738 0 0 1 "samples/VIBRAPHONE/VIBES F#5.aif" 0 0 0
f739 0 0 1 "samples/VIBRAPHONE/VIBES A#5.aif" 0 0 0
f740 0 0 1 "samples/VIBRAPHONE/VIBES C#6.aif" 0 0 0
f741 0 0 1 "samples/VIBRAPHONE/VIBES F6.aif" 0 0 0
f746 0 0 1 "samples/HARP/HARP C#1.aif" 0 0 0
f747 0 0 1 "samples/HARP/HARP D#1.aif" 0 0 0
f748 0 0 1 "samples/HARP/HARP F1.aif" 0 0 0
f749 0 0 1 "samples/HARP/HARP G#1.aif" 0 0 0
f750 0 0 1 "samples/HARP/HARP B1.aif" 0 0 0
f751 0 0 1 "samples/HARP/HARP D#2.aif" 0 0 0
f752 0 0 1 "samples/HARP/HARP F2.aif" 0 0 0
f753 0 0 1 "samples/HARP/HARP A#2.aif" 0 0 0
f754 0 0 1 "samples/HARP/HARP E3.aif" 0 0 0
f755 0 0 1 "samples/HARP/HARP G3.aif" 0 0 0
f756 0 0 1 "samples/HARP/HARP A#3.aif" 0 0 0
f757 0 0 1 "samples/HARP/HARP C#4.aif" 0 0 0
f758 0 0 1 "samples/HARP/HARP E4.aif" 0 0 0
f759 0 0 1 "samples/HARP/HARP G#4.aif" 0 0 0
f760 0 0 1 "samples/HARP/HARP C5.aif" 0 0 0
f761 0 0 1 "samples/HARP/HARP E5.aif" 0 0 0
f762 0 0 1 "samples/HARP/HARP G5.aif" 0 0 0
f763 0 0 1 "samples/HARP/HARP D#6.aif" 0 0 0
f764 0 0 1 "samples/HARP/HARP G6.aif" 0 0 0
f765 0 0 1 "samples/HARP/HARP B6.aif" 0 0 0
f770 0 0 1 "samples/VIOLIN-MART/VIOLINM G3.aif" 0 0 0
f771 0 0 1 "samples/VIOLIN-MART/VIOLINM A3.aif" 0 0 0
f772 0 0 1 "samples/VIOLIN-MART/VIOLINM B3.aif" 0 0 0
f773 0 0 1 "samples/VIOLIN-MART/VIOLINMC#4.aif" 0 0 0
f774 0 0 1 "samples/VIOLIN-MART/VIOLINMD#4.aif" 0 0 0
f775 0 0 1 "samples/VIOLIN-MART/VIOLINM F4.aif" 0 0 0
f776 0 0 1 "samples/VIOLIN-MART/VIOLINM G4.aif" 0 0 0
f777 0 0 1 "samples/VIOLIN-MART/VIOLINM A4.aif" 0 0 0
f778 0 0 1 "samples/VIOLIN-MART/VIOLINM B4.aif" 0 0 0
f779 0 0 1 "samples/VIOLIN-MART/VIOLINMC#5.aif" 0 0 0
f780 0 0 1 "samples/VIOLIN-MART/VIOLINMD#5.aif" 0 0 0
f781 0 0 1 "samples/VIOLIN-MART/VIOLINM F5.aif" 0 0 0
f782 0 0 1 "samples/VIOLIN-MART/VIOLINM G5.aif" 0 0 0
f783 0 0 1 "samples/VIOLIN-MART/VIOLINM A5.aif" 0 0 0
f784 0 0 1 "samples/VIOLIN-MART/VIOLINM B5.aif" 0 0 0
f785 0 0 1 "samples/VIOLIN-MART/VIOLINMC#6.aif" 0 0 0
f786 0 0 1 "samples/VIOLIN-MART/VIOLINMD#6.aif" 0 0 0
f791 0 0 1 "samples/VIOLA-MARTEL/VIOLAMC3.aif" 0 0 0
f792 0 0 1 "samples/VIOLA-MARTEL/VIOLAMD3.aif" 0 0 0
f793 0 0 1 "samples/VIOLA-MARTEL/VIOLAME3.aif" 0 0 0
f794 0 0 1 "samples/VIOLA-MARTEL/VIOLAMF#3.aif" 0 0 0
f795 0 0 1 "samples/VIOLA-MARTEL/VIOLAMA3.aif" 0 0 0
f796 0 0 1 "samples/VIOLA-MARTEL/VIOLAMC4.aif" 0 0 0
f797 0 0 1 "samples/VIOLA-MARTEL/VIOLAMD4.aif" 0 0 0
f798 0 0 1 "samples/VIOLA-MARTEL/VIOLAME4.aif" 0 0 0
f799 0 0 1 "samples/VIOLA-MARTEL/VIOLAMF#4.aif" 0 0 0
f800 0 0 1 "samples/VIOLA-MARTEL/VIOLAMA4.aif" 0 0 0
f801 0 0 1 "samples/VIOLA-MARTEL/VIOLAMB4.aif" 0 0 0
f802 0 0 1 "samples/VIOLA-MARTEL/VIOLAMC#5.aif" 0 0 0
f803 0 0 1 "samples/VIOLA-MARTEL/VIOLAMD#5.aif" 0 0 0
f804 0 0 1 "samples/VIOLA-MARTEL/VIOLAMG#5.aif" 0 0 0
f805 0 0 1 "samples/VIOLA-MARTEL/VIOLAMA#5.aif" 0 0 0
f806 0 0 1 "samples/VIOLA-MARTEL/VIOLAMC6.aif" 0 0 0
f811 0 0 1 "samples/CELLOMARTELE/CELLO M C2.aif" 0 0 0
f812 0 0 1 "samples/CELLOMARTELE/CELLO M D2.aif" 0 0 0
f813 0 0 1 "samples/CELLOMARTELE/CELLO M E2.aif" 0 0 0
f814 0 0 1 "samples/CELLOMARTELE/CELLO M F#2.aif" 0 0 0
f815 0 0 1 "samples/CELLOMARTELE/CELLO M G#2.aif" 0 0 0
f816 0 0 1 "samples/CELLOMARTELE/CELLO M A#2.aif" 0 0 0
f817 0 0 1 "samples/CELLOMARTELE/CELLO M C3.aif" 0 0 0
f818 0 0 1 "samples/CELLOMARTELE/CELLO M D3.aif" 0 0 0
f819 0 0 1 "samples/CELLOMARTELE/CELLO M E3.aif" 0 0 0
f820 0 0 1 "samples/CELLOMARTELE/CELLO M F#3.aif" 0 0 0
f821 0 0 1 "samples/CELLOMARTELE/CELLO M A#3.aif" 0 0 0
f822 0 0 1 "samples/CELLOMARTELE/CELLO M C4.aif" 0 0 0
f823 0 0 1 "samples/CELLOMARTELE/CELLO M D4.aif" 0 0 0
f824 0 0 1 "samples/CELLOMARTELE/CELLO M E4.aif" 0 0 0
f825 0 0 1 "samples/CELLOMARTELE/CELLO M F#4.aif" 0 0 0
f826 0 0 1 "samples/CELLOMARTELE/CELLO M G#4.aif" 0 0 0
f827 0 0 1 "samples/CELLOMARTELE/CELLO M A#4.aif" 0 0 0
f828 0 0 1 "samples/CELLOMARTELE/CELLO M C5.aif" 0 0 0
f829 0 0 1 "samples/CELLOMARTELE/CELLO M D5.aif" 0 0 0
f834 0 0 1 "samples/BASSOON/BASSOON A#1.aif" 0 0 0
f835 0 0 1 "samples/BASSOON/BASSOON C2.aif" 0 0 0
f836 0 0 1 "samples/BASSOON/BASSOON D2.aif" 0 0 0
f837 0 0 1 "samples/BASSOON/BASSOON E2.aif" 0 0 0
f838 0 0 1 "samples/BASSOON/BASSOON F#2.aif" 0 0 0
f839 0 0 1 "samples/BASSOON/BASSOON G#2.aif" 0 0 0
f840 0 0 1 "samples/BASSOON/BASS A#2.aif" 0 0 0
f841 0 0 1 "samples/BASSOON/BASS C3.aif" 0 0 0
f842 0 0 1 "samples/BASSOON/BASS D3.aif" 0 0 0
f843 0 0 1 "samples/BASSOON/BASS E3.aif" 0 0 0
f844 0 0 1 "samples/BASSOON/BASS F#3.aif" 0 0 0
f845 0 0 1 "samples/BASSOON/BASS G#3.aif" 0 0 0
f846 0 0 1 "samples/BASSOON/BASS A#3.aif" 0 0 0
f847 0 0 1 "samples/BASSOON/BASS C4.aif" 0 0 0
f848 0 0 1 "samples/BASSOON/BASS D4.aif" 0 0 0
f849 0 0 1 "samples/BASSOON/BASS E4.aif" 0 0 0
f854 0 0 1 "samples/B- CLARINET/CLARBB D3-f.aif" 0 0 0
f855 0 0 1 "samples/B- CLARINET/CLARBB E3-f.aif" 0 0 0
f856 0 0 1 "samples/B- CLARINET/CLARBB F#3-f.aif" 0 0 0
f857 0 0 1 "samples/B- CLARINET/CLARBB G#3-f.aif" 0 0 0
f858 0 0 1 "samples/B- CLARINET/CLARBB A#3-f.aif" 0 0 0
f859 0 0 1 "samples/B- CLARINET/CLARBB C4-f.aif" 0 0 0
f860 0 0 1 "samples/B- CLARINET/CLARBB E4-f.aif" 0 0 0
f861 0 0 1 "samples/B- CLARINET/CLARBB F#4-f.aif" 0 0 0
f862 0 0 1 "samples/B- CLARINET/CLARBB G#4-f.aif" 0 0 0
f863 0 0 1 "samples/B- CLARINET/CLARBB A#4-f.aif" 0 0 0
f864 0 0 1 "samples/B- CLARINET/CLARBB C5-f.aif" 0 0 0
f865 0 0 1 "samples/B- CLARINET/CLARBB D5-f.aif" 0 0 0
f866 0 0 1 "samples/B- CLARINET/CLARBB E5-f.aif" 0 0 0
f867 0 0 1 "samples/B- CLARINET/CLARBB F#5-f.aif" 0 0 0
f868 0 0 1 "samples/B- CLARINET/CLARBB G#5-f.aif" 0 0 0
f869 0 0 1 "samples/B- CLARINET/CLARBB A#5-f.aif" 0 0 0
f870 0 0 1 "samples/B- CLARINET/CLARBB C6-f.aif" 0 0 0
f871 0 0 1 "samples/B- CLARINET/CLARBB D6-f.aif" 0 0 0
f876 0 0 1 "samples/FLUTE NO-VIB/FLUTENV C3.aif" 0 0 0
f877 0 0 1 "samples/FLUTE NO-VIB/FLUTENV D3.aif" 0 0 0
f878 0 0 1 "samples/FLUTE NO-VIB/FLUTENVF#3.aif" 0 0 0
f879 0 0 1 "samples/FLUTE NO-VIB/FLUTENVA#3.aif" 0 0 0
f880 0 0 1 "samples/FLUTE NO-VIB/FLUTENV E4.aif" 0 0 0
f881 0 0 1 "samples/FLUTE NO-VIB/FLUTENV A4.aif" 0 0 0
f882 0 0 1 "samples/FLUTE NO-VIB/FLUTENV B4.aif" 0 0 0
f883 0 0 1 "samples/FLUTE NO-VIB/FLUTENVC#5.aif" 0 0 0
f884 0 0 1 "samples/FLUTE NO-VIB/FLUTENVD#5.aif" 0 0 0
f885 0 0 1 "samples/FLUTE NO-VIB/FLUTENV F5.aif" 0 0 0
f886 0 0 1 "samples/FLUTE NO-VIB/FLUTENV G5.aif" 0 0 0
f887 0 0 1 "samples/FLUTE NO-VIB/FLUTENV A5.aif" 0 0 0
f888 0 0 1 "samples/FLUTE NO-VIB/FLUTENV B5.aif" 0 0 0
f889 0 0 1 "samples/FLUTE NO-VIB/FLUTENV C6.aif" 0 0 0
f894 0 0 1 "samples/OBOE/OBOE A#3-f.aif" 0 0 0
f895 0 0 1 "samples/OBOE/OBOE C4.aif" 0 0 0
f896 0 0 1 "samples/OBOE/OBOE D4-f.aif" 0 0 0
f897 0 0 1 "samples/OBOE/OBOE E4-f.aif" 0 0 0
f898 0 0 1 "samples/OBOE/OBOE F#4.aif" 0 0 0
f899 0 0 1 "samples/OBOE/OBOE G#4-f.aif" 0 0 0
f900 0 0 1 "samples/OBOE/OBOE A#4-f.aif" 0 0 0
f901 0 0 1 "samples/OBOE/OBOE C5-f.aif" 0 0 0
f902 0 0 1 "samples/OBOE/OBOE D5-f.aif" 0 0 0
f903 0 0 1 "samples/OBOE/OBOE E5.aif" 0 0 0
f904 0 0 1 "samples/OBOE/OBOE G#5.aif" 0 0 0
f905 0 0 1 "samples/OBOE/OBOE A#5-f.aif" 0 0 0
f906 0 0 1 "samples/OBOE/OBOE C6-f.aif" 0 0 0
f907 0 0 1 "samples/OBOE/OBOE D6-f.aif" 0 0 0
f908 0 0 1 "samples/OBOE/OBOE E6-f.aif" 0 0 0
f913 0 0 1 "samples/FRENCH HORN/F.HORN D2.aif" 0 0 0
f914 0 0 1 "samples/FRENCH HORN/F.HORN E2.aif" 0 0 0
f915 0 0 1 "samples/FRENCH HORN/F.HORN F#2.aif" 0 0 0
f916 0 0 1 "samples/FRENCH HORN/F.HORN G#2.aif" 0 0 0
f917 0 0 1 "samples/FRENCH HORN/F.HORN A#2.aif" 0 0 0
f918 0 0 1 "samples/FRENCH HORN/F.HORN D3.aif" 0 0 0
f919 0 0 1 "samples/FRENCH HORN/F.HORN E3.aif" 0 0 0
f920 0 0 1 "samples/FRENCH HORN/F.HORN F#3.aif" 0 0 0
f921 0 0 1 "samples/FRENCH HORN/F.HORN G#3.aif" 0 0 0
f922 0 0 1 "samples/FRENCH HORN/F.HORN A#3.aif" 0 0 0
f923 0 0 1 "samples/FRENCH HORN/F.HORN C4.aif" 0 0 0
f924 0 0 1 "samples/FRENCH HORN/F.HORN D4.aif" 0 0 0
f925 0 0 1 "samples/FRENCH HORN/F.HORN E4.aif" 0 0 0
f926 0 0 1 "samples/FRENCH HORN/F.HORN F#4.aif" 0 0 0
f927 0 0 1 "samples/FRENCH HORN/F.HORN A#4.aif" 0 0 0
f928 0 0 1 "samples/FRENCH HORN/F.HORN C5.aif" 0 0 0
f929 0 0 1 "samples/FRENCH HORN/F.HORN D5-f.aif" 0 0 0
f934 0 0 1 "samples/VIOLIN W-VIB/VIOLING#3.aif" 0 0 0
f935 0 0 1 "samples/VIOLIN W-VIB/VIOLINA#3.aif" 0 0 0
f936 0 0 1 "samples/VIOLIN W-VIB/VIOLINC4.aif" 0 0 0
f937 0 0 1 "samples/VIOLIN W-VIB/VIOLIND4.aif" 0 0 0
f938 0 0 1 "samples/VIOLIN W-VIB/VIOLINE4.aif" 0 0 0
f939 0 0 1 "samples/VIOLIN W-VIB/VIOLINF#4.aif" 0 0 0
f940 0 0 1 "samples/VIOLIN W-VIB/VIOLING#4.aif" 0 0 0
f941 0 0 1 "samples/VIOLIN W-VIB/VIOLINA#4.aif" 0 0 0
f942 0 0 1 "samples/VIOLIN W-VIB/VIOLINC#5.aif" 0 0 0
f943 0 0 1 "samples/VIOLIN W-VIB/VIOLIND#5.aif" 0 0 0
f944 0 0 1 "samples/VIOLIN W-VIB/VIOLINF5.aif" 0 0 0
f945 0 0 1 "samples/VIOLIN W-VIB/VIOLING5.aif" 0 0 0
f946 0 0 1 "samples/VIOLIN W-VIB/VIOLINA5.aif" 0 0 0
f947 0 0 1 "samples/VIOLIN W-VIB/VIOLINB5.aif" 0 0 0
f948 0 0 1 "samples/VIOLIN W-VIB/VIOLINC#6.aif" 0 0 0
f949 0 0 1 "samples/VIOLIN W-VIB/VIOLIND#6.aif" 0 0 0
f950 0 0 1 "samples/VIOLIN W-VIB/VIOLINF6.aif" 0 0 0
f951 0 0 1 "samples/VIOLIN W-VIB/VIOLING6.aif" 0 0 0
f952 0 0 1 "samples/VIOLIN W-VIB/VIOLINA6.aif" 0 0 0
f957 0 0 1 "samples/VIOLA W-VIB/VIOLAV C#3.aif" 0 0 0
f958 0 0 1 "samples/VIOLA W-VIB/VIOLAV D3.aif" 0 0 0
f959 0 0 1 "samples/VIOLA W-VIB/VIOLAV E3.aif" 0 0 0
f960 0 0 1 "samples/VIOLA W-VIB/VIOLAV F#3.aif" 0 0 0
f961 0 0 1 "samples/VIOLA W-VIB/VIOLAV G#3.aif" 0 0 0
f962 0 0 1 "samples/VIOLA W-VIB/VIOLAV A#3.aif" 0 0 0
f963 0 0 1 "samples/VIOLA W-VIB/VIOLAV C4.aif" 0 0 0
f964 0 0 1 "samples/VIOLA W-VIB/VIOLAV D4.aif" 0 0 0
f965 0 0 1 "samples/VIOLA W-VIB/VIOLAV E4.aif" 0 0 0
f966 0 0 1 "samples/VIOLA W-VIB/VIOLAV F#4.aif" 0 0 0
f967 0 0 1 "samples/VIOLA W-VIB/VIOLAV G#4.aif" 0 0 0
f968 0 0 1 "samples/VIOLA W-VIB/VIOLAV A#4.aif" 0 0 0
f969 0 0 1 "samples/VIOLA W-VIB/VIOLAV C5.aif" 0 0 0
f970 0 0 1 "samples/VIOLA W-VIB/VIOLAV D#5.aif" 0 0 0
f971 0 0 1 "samples/VIOLA W-VIB/VIOLAV F#5.aif" 0 0 0
f972 0 0 1 "samples/VIOLA W-VIB/VIOLAV A5.aif" 0 0 0
f973 0 0 1 "samples/VIOLA W-VIB/VIOLAV B5.aif" 0 0 0
f974 0 0 1 "samples/VIOLA W-VIB/VIOLAV C#6.aif" 0 0 0
f979 0 0 1 "samples/CELLO W-VIB/CELLOV C#2.aif" 0 0 0
f980 0 0 1 "samples/CELLO W-VIB/CELLOV D#2.aif" 0 0 0
f981 0 0 1 "samples/CELLO W-VIB/CELLOV F2.aif" 0 0 0
f982 0 0 1 "samples/CELLO W-VIB/CELLOV G2.aif" 0 0 0
f983 0 0 1 "samples/CELLO W-VIB/CELLOV A2.aif" 0 0 0
f984 0 0 1 "samples/CELLO W-VIB/CELLOV B2.aif" 0 0 0
f985 0 0 1 "samples/CELLO W-VIB/CELLOV C#3.aif" 0 0 0
f986 0 0 1 "samples/CELLO W-VIB/CELLOV D#3.aif" 0 0 0
f987 0 0 1 "samples/CELLO W-VIB/CELLOV F3.aif" 0 0 0
f988 0 0 1 "samples/CELLO W-VIB/CELLOV G3.aif" 0 0 0
f989 0 0 1 "samples/CELLO W-VIB/CELLOV A3.aif" 0 0 0
f990 0 0 1 "samples/CELLO W-VIB/CELLOV B3.aif" 0 0 0
f991 0 0 1 "samples/CELLO W-VIB/CELLOV C#4.aif" 0 0 0
f992 0 0 1 "samples/CELLO W-VIB/CELLOV D#4.aif" 0 0 0
f993 0 0 1 "samples/CELLO W-VIB/CELLOV F4.aif" 0 0 0
f994 0 0 1 "samples/CELLO W-VIB/CELLOV G4.aif" 0 0 0
f995 0 0 1 "samples/CELLO W-VIB/CELLOV A4.aif" 0 0 0
f996 0 0 1 "samples/CELLO W-VIB/CELLOV B4.aif" 0 0 0
f997 0 0 1 "samples/CELLO W-VIB/CELLOV C#5.aif" 0 0 0
f998 0 0 1 "samples/CELLO W-VIB/CELLOV D#5.aif" 0 0 0
f1003 0 0 1 "samples/Baritone Guitar/H1B-19b.wav" 0 0 0
f1004 0 0 1 "samples/Baritone Guitar/H2C#-6.wav" 0 0 0
f1005 0 0 1 "samples/Baritone Guitar/H2D#-6.wav" 0 0 0
f1006 0 0 1 "samples/Baritone Guitar/H2E-15.wav" 0 0 0
f1007 0 0 1 "samples/Baritone Guitar/H2F#-2.wav" 0 0 0
f1008 0 0 1 "samples/Baritone Guitar/H2G#-7.wav" 0 0 0
f1009 0 0 1 "samples/Baritone Guitar/H2A-8.wav" 0 0 0
f1010 0 0 1 "samples/Baritone Guitar/H2B+3.wav" 0 0 0
f1011 0 0 1 "samples/Baritone Guitar/H3C#-4.wav" 0 0 0
f1012 0 0 1 "samples/Baritone Guitar/H3D-12.wav" 0 0 0
f1013 0 0 1 "samples/Baritone Guitar/H3E-11.wav" 0 0 0
f1014 0 0 1 "samples/Baritone Guitar/H3F#-5.wav" 0 0 0
f1015 0 0 1 "samples/Baritone Guitar/H3G#-6.wav" 0 0 0
f1016 0 0 1 "samples/Baritone Guitar/H3A#+2.wav" 0 0 0
f1017 0 0 1 "samples/Baritone Guitar/H3B-16.wav" 0 0 0
f1018 0 0 1 "samples/Baritone Guitar/H4C#+3.wav" 0 0 0
f1019 0 0 1 "samples/Baritone Guitar/H4D#+0.wav" 0 0 0
f1020 0 0 1 "samples/Baritone Guitar/H4F+24.wav" 0 0 0
f1021 0 0 1 "samples/Baritone Guitar/H4G+5.wav" 0 0 0
f1022 0 0 1 "samples/Baritone Guitar/H4A-5.wav" 0 0 0
f1023 0 0 1 "samples/Baritone Guitar/H4B+3.wav" 0 0 0
f1024 0 0 1 "samples/Baritone Guitar/H5C#+0.wav" 0 0 0
f1025 0 0 1 "samples/Baritone Guitar/H5D#+0.wav" 0 0 0
f1026 0 0 1 "samples/Baritone Guitar/H5F+0.wav" 0 0 0
f1027 0 0 1 "samples/Baritone Guitar/H5G+0.wav" 0 0 0
f1028 0 0 1 "samples/Baritone Guitar/H5A-5.wav" 0 0 0
f1029 0 0 1 "samples/Baritone Guitar/H5B+13.wav" 0 0 0
f1034 0 0 1 "samples/ErnieBall-038/2Em9s.aif" 0 0 0
f1035 0 0 1 "samples/ErnieBall-038/2F#p0s.aif" 0 0 0
f1036 0 0 1 "samples/ErnieBall-038/2G#m3.aif" 0 0 0
f1037 0 0 1 "samples/ErnieBall-030/2Am4.aif" 0 0 0
f1038 0 0 1 "samples/ErnieBall-030/2Bm3.aif" 0 0 0
f1039 0 0 1 "samples/ErnieBall-030/3C#m10s.aif" 0 0 0
f1040 0 0 1 "samples/ErnieBall-022/3Dm3.aif" 0 0 0
f1041 0 0 1 "samples/ErnieBall-022/3Em4.aif" 0 0 0
f1042 0 0 1 "samples/ErnieBall-022/3F#m4.aif" 0 0 0
f1043 0 0 1 "samples/ErnieBall-014/3Gm6.aif" 0 0 0
f1044 0 0 1 "samples/ErnieBall-014/3Ap0.aif" 0 0 0
f1045 0 0 1 "samples/ErnieBall-011/3Bm5.aif" 0 0 0
f1046 0 0 1 "samples/ErnieBall-011/4Cp1.aif" 0 0 0
f1047 0 0 1 "samples/ErnieBall-011/4Dm2.aif" 0 0 0
f1048 0 0 1 "samples/ErnieBall-011/4Em5.aif" 0 0 0
f1049 0 0 1 "samples/ErnieBall-011/4F#m5.aif" 0 0 0
f1050 0 0 1 "samples/ErnieBall-011/4G#p0.aif" 0 0 0
f1051 0 0 1 "samples/ErnieBall-011/4A#m2.aif" 0 0 0
f1052 0 0 1 "samples/ErnieBall-011/5Cp0.aif" 0 0 0
f1053 0 0 1 "samples/ErnieBall-011/5Dp0.aif" 0 0 0
f1054 0 0 1 "samples/ErnieBall-011/5Ep0.aif" 0 0 0
f1055 0 0 1 "samples/ErnieBall-011/5F#p2.aif" 0 0 0
f1056 0 0 1 "samples/ErnieBall-011/5G#m2.aif" 0 0 0
f1057 0 0 1 "samples/ErnieBall-011/5A#m3.aif" 0 0 0
f1058 0 0 1 "samples/ErnieBall-011/6Cp0.aif" 0 0 0
f1059 0 0 1 "samples/ErnieBall-011/6Dp1.aif" 0 0 0
f1060 0 0 1 "samples/ErnieBall-011/6Em1.aif" 0 0 0
f1061 0 0 1 "samples/ErnieBall-011/6F#p0.aif" 0 0 0
f1062 0 0 1 "samples/ErnieBall-011/6G#p0.aif" 0 0 0
f1063 0 0 1 "samples/ErnieBall-008/6A#m13.aif" 0 0 0
f1064 0 0 1 "samples/ErnieBall-008/7Cm15.aif" 0 0 0
f1065 0 0 1 "samples/ErnieBall-008/7Dm29.aif" 0 0 0
f1066 0 0 1 "samples/ErnieBall-008/7F#m16.aif" 0 0 0
f1067 0 0 1 "samples/ErnieBall-008/7G#m47.aif" 0 0 0
f1068 0 0 1 "samples/ErnieBall-008/7A#p28.aif" 0 0 0
f1069 0 0 1 "samples/ErnieBall-008/8Cm37.aif" 0 0 0
f1074 0 0 1 "samples/LongString-024/String0Bp1.aif" 0 0 0
f1075 0 0 1 "samples/LongString-024/String1Cp1.aif" 0 0 0
f1076 0 0 1 "samples/LongString-024/String1Dm3.aif" 0 0 0
f1077 0 0 1 "samples/LongString-024/String1Em1.aif" 0 0 0
f1078 0 0 1 "samples/LongString-024/String1Fp1.aif" 0 0 0
f1079 0 0 1 "samples/LongString-024/String1Gm2.aif" 0 0 0
f1080 0 0 1 "samples/LongString-024/String1Ap0.aif" 0 0 0
f1081 0 0 1 "samples/LongString-024/String1Bp0.aif" 0 0 0
f1082 0 0 1 "samples/LongString-024/String2Cp0.aif" 0 0 0
f1083 0 0 1 "samples/LongString-024/String2Dp0.aif" 0 0 0
f1084 0 0 1 "samples/LongString-024/String2Ep0.aif" 0 0 0
f1085 0 0 1 "samples/LongString-024/String2Fp2.aif" 0 0 0
f1086 0 0 1 "samples/LongString-024/String2Gp5.aif" 0 0 0
f1087 0 0 1 "samples/LongString-024/String2Ap0.aif" 0 0 0
f1088 0 0 1 "samples/LongString-024/String2Bp0.aif" 0 0 0
f1089 0 0 1 "samples/LongString-024/String3Cp0.aif" 0 0 0
f1090 0 0 1 "samples/LongString-024/String3Dp0.aif" 0 0 0
f1091 0 0 1 "samples/LongString-024/String3Em2.aif" 0 0 0
f1092 0 0 1 "samples/LongString-024/String3Fm5.aif" 0 0 0
f1093 0 0 1 "samples/LongString-024/String3Gp0.aif" 0 0 0
f1094 0 0 1 "samples/LongString-024/String3Ap1.aif" 0 0 0
f1095 0 0 1 "samples/LongString-024/String3Bm1.aif" 0 0 0
f1096 0 0 1 "samples/LongString-024/String4Cm1.aif" 0 0 0
f1097 0 0 1 "samples/LongString-024/String4Dp0.aif" 0 0 0
f1098 0 0 1 "samples/LongString-024/String4Ep0.aif" 0 0 0
f1099 0 0 1 "samples/LongString-024/String4Fm5.aif" 0 0 0
f1100 0 0 1 "samples/LongString-024/String4Gm5.aif" 0 0 0
f1101 0 0 1 "samples/LongString-024/String4Ap0.aif" 0 0 0
f1102 0 0 1 "samples/LongString-024/String4Bp3.aif" 0 0 0
f1103 0 0 1 "samples/LongString-024/String5Cm3.aif" 0 0 0
f1108 0 0 1 "samples/Strings/String3D#m49.aif" 0 0 0
f1109 0 0 1 "samples/Strings/String3Fm44.aif" 0 0 0
f1110 0 0 1 "samples/Strings/String3G#m9.aif" 0 0 0
f1111 0 0 1 "samples/Strings/String3Ap23.aif" 0 0 0
f1112 0 0 1 "samples/Strings/String3A#p22.aif" 0 0 0
f1113 0 0 1 "samples/Strings/String3Bm5.aif" 0 0 0
f1114 0 0 1 "samples/Strings/String4Cp16.aif" 0 0 0
f1115 0 0 1 "samples/Strings/String4C#p10.aif" 0 0 0
f1116 0 0 1 "samples/Strings/String4Dm22.aif" 0 0 0
f1117 0 0 1 "samples/Strings/String4D#m17.aif" 0 0 0
f1118 0 0 1 "samples/Strings/String4Em5.aif" 0 0 0
f1119 0 0 1 "samples/Strings/String4F#p2.aif" 0 0 0
f1120 0 0 1 "samples/Strings/String4G#m3.aif" 0 0 0
f1121 0 0 1 "samples/Strings/String4A#p2.aif" 0 0 0
f1122 0 0 1 "samples/Strings/String5Cm27.aif" 0 0 0
f1123 0 0 1 "samples/Strings/String5Dm30.aif" 0 0 0
f1124 0 0 1 "samples/Strings/String5Em5.aif" 0 0 0
f1125 0 0 1 "samples/Strings/String5F#p6.aif" 0 0 0
f1126 0 0 1 "samples/Strings/String5G#m3.aif" 0 0 0
f1127 0 0 1 "samples/Strings/String5Bp10.aif" 0 0 0
f1128 0 0 1 "samples/Strings/String6C#m11.aif" 0 0 0
f1129 0 0 1 "samples/Strings/String6D#p0.aif" 0 0 0
f1134 0 0 1 "samples/Bass FingerP/Piano 0 G +4.aif" 0 0 0
f1135 0 0 1 "samples/Bass FingerP/Piano 0 G# -30.aif" 0 0 0
f1136 0 0 1 "samples/Bass FingerP/Piano 0 A# -21.aif" 0 0 0
f1137 0 0 1 "samples/Bass FingerP/Piano 1 C -11.aif" 0 0 0
f1138 0 0 1 "samples/Bass FingerP/Piano 1 D +9.aif" 0 0 0
f1139 0 0 1 "samples/Bass FingerP/Piano 1 G +17.aif" 0 0 0
f1140 0 0 1 "samples/Bass FingerP/Piano 1 A +22.aif" 0 0 0
f1141 0 0 1 "samples/Bass FingerP/Piano 2 C -10.aif" 0 0 0
f1142 0 0 1 "samples/Bass FingerP/Piano 2 D -38.aif" 0 0 0
f1143 0 0 1 "samples/Bass FingerP/Piano 2 E +14.aif" 0 0 0
f1144 0 0 1 "samples/Bass FingerP/Piano 2 F# +17.aif" 0 0 0
f1145 0 0 1 "samples/Bass FingerP/Piano 2 A -32.aif" 0 0 0
f1146 0 0 1 "samples/Bass FingerP/Piano 2 A# -1.aif" 0 0 0
f1147 0 0 1 "samples/Bass FingerP/Piano 3 C +16.aif" 0 0 0
f1148 0 0 1 "samples/Bass FingerP/Piano 3 D +46.aif" 0 0 0
f1149 0 0 1 "samples/Bass FingerP/Piano 3 F -30.aif" 0 0 0
f1150 0 0 1 "samples/Bass FingerP/Piano 3 G# -1.aif" 0 0 0
f1151 0 0 1 "samples/Bass FingerP/Piano 3 A# +39.aif" 0 0 0
f1152 0 0 1 "samples/Bass FingerP/Piano 4 D -5.aif" 0 0 0
f1153 0 0 1 "samples/Bass FingerP/Piano 4 F# -2.aif" 0 0 0
f1154 0 0 1 "samples/Bass FingerP/Piano 4 A +32.aif" 0 0 0
f1155 0 0 1 "samples/Bass FingerP/Piano 5 D -41.aif" 0 0 0
f1160 0 0 1 "samples/TRUMPET-C/TRUMPETC F#3.aif" 0 0 0
f1161 0 0 1 "samples/TRUMPET-C/TRUMPETC G#3.aif" 0 0 0
f1162 0 0 1 "samples/TRUMPET-C/TRUMPETC A#3.aif" 0 0 0
f1163 0 0 1 "samples/TRUMPET-C/TRUMPETCC4.aif" 0 0 0
f1164 0 0 1 "samples/TRUMPET-C/TRUMPETCD4.aif" 0 0 0
f1165 0 0 1 "samples/TRUMPET-C/TRUMPETCE4.aif" 0 0 0
f1166 0 0 1 "samples/TRUMPET-C/TRUMPETC F#4.aif" 0 0 0
f1167 0 0 1 "samples/TRUMPET-C/TRUMPETC G#4.aif" 0 0 0
f1168 0 0 1 "samples/TRUMPET-C/TRUMPETC A#4.aif" 0 0 0
f1169 0 0 1 "samples/TRUMPET-C/TRUMPETCC5.aif" 0 0 0
f1170 0 0 1 "samples/TRUMPET-C/TRUMPETCD5.aif" 0 0 0
f1171 0 0 1 "samples/TRUMPET-C/TRUMPETCE5.aif" 0 0 0
f1172 0 0 1 "samples/TRUMPET-C/TRUMPETC F#5.aif" 0 0 0
f1173 0 0 1 "samples/TRUMPET-C/TRUMPETC G#5.aif" 0 0 0
f1174 0 0 1 "samples/TRUMPET-C/TRUMPETC A#5.aif" 0 0 0
f1175 0 0 1 "samples/TRUMPET-C/TRUMPETCC6.aif" 0 0 0
f1176 0 0 1 "samples/TRUMPET-C/TRUMPETCD6.aif" 0 0 0
f1181 0 0 1 "samples/TROMBONE-TNR/TNRBONEE2.aif" 0 0 0
f1182 0 0 1 "samples/TROMBONE-TNR/TNRBONEG2.aif" 0 0 0
f1183 0 0 1 "samples/TROMBONE-TNR/TNRBONEA#2.aif" 0 0 0
f1184 0 0 1 "samples/TROMBONE-TNR/TNRBONEC#3.aif" 0 0 0
f1185 0 0 1 "samples/TROMBONE-TNR/TNRBONEE3.aif" 0 0 0
f1186 0 0 1 "samples/TROMBONE-TNR/TNRBONEG3.aif" 0 0 0
f1187 0 0 1 "samples/TROMBONE-TNR/TNRBONEA#3.aif" 0 0 0
f1188 0 0 1 "samples/TROMBONE-TNR/TNRBONEC#4.aif" 0 0 0
f1189 0 0 1 "samples/TROMBONE-TNR/TNRBONEE4.aif" 0 0 0
f1190 0 0 1 "samples/TROMBONE-TNR/TNRBONEG4.aif" 0 0 0
f1191 0 0 1 "samples/TROMBONE-TNR/TNRBONEA#4.aif" 0 0 0
f1196 0 0 1 "samples/TUBA/TUBA C2.aif" 0 0 0
f1197 0 0 1 "samples/TUBA/TUBA D2.aif" 0 0 0
f1198 0 0 1 "samples/TUBA/TUBA F2.aif" 0 0 0
f1199 0 0 1 "samples/TUBA/TUBA G2.aif" 0 0 0
f1200 0 0 1 "samples/TUBA/TUBA A2.aif" 0 0 0
f1201 0 0 1 "samples/TUBA/TUBA B2.aif" 0 0 0
f1202 0 0 1 "samples/TUBA/TUBA C#3.aif" 0 0 0
f1203 0 0 1 "samples/TUBA/TUBA D#3.aif" 0 0 0
f1204 0 0 1 "samples/TUBA/TUBA F3.aif" 0 0 0
f1205 0 0 1 "samples/TUBA/TUBA G3.aif" 0 0 0
f1206 0 0 1 "samples/TUBA/TUBA A3.aif" 0 0 0
f1207 0 0 1 "samples/TUBA/TUBA B3.aif" 0 0 0
f1208 0 0 1 "samples/TUBA/TUBA C#4.aif" 0 0 0
f1209 0 0 1 "samples/TUBA/TUBA D#4.aif" 0 0 0
f1210 0 0 1 "samples/TUBA/TUBA F4.aif" 0 0 0
f1211 0 0 1 "samples/TUBA/TUBA G4.aif" 0 0 0
f1216 0 0 1 "samples/sine/triangle.wav" 0 0 0
f1221 0 0 1 "./samples/Bosendor/25 emp A0.wav" 0 0 0
f1222 0 0 1 "./samples/Bosendor/25 emp B0-.wav" 0 0 0
f1223 0 0 1 "./samples/Bosendor/25 emp C1-.wav" 0 0 0
f1224 0 0 1 "./samples/Bosendor/25 emp D1-.wav" 0 0 0
f1225 0 0 1 "./samples/Bosendor/25 emp E1-.wav" 0 0 0
f1226 0 0 1 "./samples/Bosendor/25 emp F1-.wav" 0 0 0
f1227 0 0 1 "./samples/Bosendor/25 emp G1-.wav" 0 0 0
f1228 0 0 1 "./samples/Bosendor/25 emp A1.wav" 0 0 0
f1229 0 0 1 "./samples/Bosendor/25 emp B1-.wav" 0 0 0
f1230 0 0 1 "./samples/Bosendor/25 emp C2-.wav" 0 0 0
f1231 0 0 1 "./samples/Bosendor/25 emp D2-.wav" 0 0 0
f1232 0 0 1 "./samples/Bosendor/25 emp E2-.wav" 0 0 0
f1233 0 0 1 "./samples/Bosendor/25 emp F2-.wav" 0 0 0
f1234 0 0 1 "./samples/Bosendor/25 emp G2-.wav" 0 0 0
f1235 0 0 1 "./samples/Bosendor/25 emp A2-.wav" 0 0 0
f1236 0 0 1 "./samples/Bosendor/25 emp B2-.wav" 0 0 0
f1237 0 0 1 "./samples/Bosendor/25 emp C3-.wav" 0 0 0
f1238 0 0 1 "./samples/Bosendor/25 emp B3-.wav" 0 0 0
f1239 0 0 1 "./samples/Bosendor/25 emp D4-.wav" 0 0 0
f1240 0 0 1 "./samples/Bosendor/25 emp E4-.wav" 0 0 0
f1241 0 0 1 "./samples/Bosendor/25 emp B4-.wav" 0 0 0
f1242 0 0 1 "./samples/Bosendor/25 emp C5-.wav" 0 0 0
f1243 0 0 1 "./samples/Bosendor/25 emp D5-.wav" 0 0 0
f1244 0 0 1 "./samples/Bosendor/25 emp E5-.wav" 0 0 0
f1245 0 0 1 "./samples/Bosendor/25 emp F5-.wav" 0 0 0
f1246 0 0 1 "./samples/Bosendor/25 emp G5-.wav" 0 0 0
f1247 0 0 1 "./samples/Bosendor/25 emp C6-.wav" 0 0 0
f1248 0 0 1 "./samples/Bosendor/25 emp D6-.wav" 0 0 0
f1249 0 0 1 "./samples/Bosendor/25 emp E6-.wav" 0 0 0
f1250 0 0 1 "./samples/Bosendor/25 emp F6-.wav" 0 0 0
f1251 0 0 1 "./samples/Bosendor/25 emp G6-.wav" 0 0 0
f1252 0 0 1 "./samples/Bosendor/25 emp A6-.wav" 0 0 0
f1253 0 0 1 "./samples/Bosendor/25 emp B6-.wav" 0 0 0
f1254 0 0 1 "./samples/Bosendor/25 emp C7-.wav" 0 0 0
f1255 0 0 1 "./samples/Bosendor/25 emp D7-.wav" 0 0 0
f1256 0 0 1 "./samples/Bosendor/25 emp E7-.wav" 0 0 0
f1257 0 0 1 "./samples/Bosendor/25 emp F7-.wav" 0 0 0
f1258 0 0 1 "./samples/Bosendor/25 emp G7-.wav" 0 0 0
f1259 0 0 1 "./samples/Bosendor/25 emp A7-.wav" 0 0 0
f1260 0 0 1 "./samples/Bosendor/25 emp B7-.wav" 0 0 0
f1261 0 0 1 "./samples/Bosendor/25 emp C8-.wav" 0 0 0
f1266 0 0 1 "./samples/Bosendor/31 emp A0.wav" 0 0 0
f1267 0 0 1 "./samples/Bosendor/31 emp B0-.wav" 0 0 0
f1268 0 0 1 "./samples/Bosendor/31 emp C1-.wav" 0 0 0
f1269 0 0 1 "./samples/Bosendor/31 emp D1-.wav" 0 0 0
f1270 0 0 1 "./samples/Bosendor/31 emp E1-.wav" 0 0 0
f1271 0 0 1 "./samples/Bosendor/31 emp F1-.wav" 0 0 0
f1272 0 0 1 "./samples/Bosendor/31 emp G1-.wav" 0 0 0
f1273 0 0 1 "./samples/Bosendor/31 emp A1.wav" 0 0 0
f1274 0 0 1 "./samples/Bosendor/31 emp B1-.wav" 0 0 0
f1275 0 0 1 "./samples/Bosendor/31 emp C2-.wav" 0 0 0
f1276 0 0 1 "./samples/Bosendor/31 emp D2-.wav" 0 0 0
f1277 0 0 1 "./samples/Bosendor/31 emp E2-.wav" 0 0 0
f1278 0 0 1 "./samples/Bosendor/31 emp F2-.wav" 0 0 0
f1279 0 0 1 "./samples/Bosendor/31 emp G2-.wav" 0 0 0
f1280 0 0 1 "./samples/Bosendor/31 emp A2-.wav" 0 0 0
f1281 0 0 1 "./samples/Bosendor/31 emp B2-.wav" 0 0 0
f1282 0 0 1 "./samples/Bosendor/31 emp C3-.wav" 0 0 0
f1283 0 0 1 "./samples/Bosendor/31 emp D3-.wav" 0 0 0
f1284 0 0 1 "./samples/Bosendor/31 emp E3-.wav" 0 0 0
f1285 0 0 1 "./samples/Bosendor/31 emp F3-.wav" 0 0 0
f1286 0 0 1 "./samples/Bosendor/31 emp G3-.wav" 0 0 0
f1287 0 0 1 "./samples/Bosendor/31 emp A3-.wav" 0 0 0
f1288 0 0 1 "./samples/Bosendor/31 emp B3-.wav" 0 0 0
f1289 0 0 1 "./samples/Bosendor/31 emp C4-.wav" 0 0 0
f1290 0 0 1 "./samples/Bosendor/31 emp D4-.wav" 0 0 0
f1291 0 0 1 "./samples/Bosendor/31 emp E4-.wav" 0 0 0
f1292 0 0 1 "./samples/Bosendor/31 emp F4-.wav" 0 0 0
f1293 0 0 1 "./samples/Bosendor/31 emp G4-.wav" 0 0 0
f1294 0 0 1 "./samples/Bosendor/31 emp A4-.wav" 0 0 0
f1295 0 0 1 "./samples/Bosendor/31 emp B4-.wav" 0 0 0
f1296 0 0 1 "./samples/Bosendor/31 emp C5-.wav" 0 0 0
f1297 0 0 1 "./samples/Bosendor/31 emp D5-.wav" 0 0 0
f1298 0 0 1 "./samples/Bosendor/31 emp E5-.wav" 0 0 0
f1299 0 0 1 "./samples/Bosendor/31 emp F5-.wav" 0 0 0
f1300 0 0 1 "./samples/Bosendor/31 emp G5-.wav" 0 0 0
f1301 0 0 1 "./samples/Bosendor/31 emp A5-.wav" 0 0 0
f1302 0 0 1 "./samples/Bosendor/31 emp B5-.wav" 0 0 0
f1303 0 0 1 "./samples/Bosendor/31 emp C6-.wav" 0 0 0
f1304 0 0 1 "./samples/Bosendor/31 emp D6-.wav" 0 0 0
f1305 0 0 1 "./samples/Bosendor/31 emp E6-.wav" 0 0 0
f1306 0 0 1 "./samples/Bosendor/31 emp F6-.wav" 0 0 0
f1307 0 0 1 "./samples/Bosendor/31 emp G6-.wav" 0 0 0
f1308 0 0 1 "./samples/Bosendor/31 emp A6-.wav" 0 0 0
f1309 0 0 1 "./samples/Bosendor/31 emp C7-.wav" 0 0 0
f1310 0 0 1 "./samples/Bosendor/31 emp D7-.wav" 0 0 0
f1311 0 0 1 "./samples/Bosendor/31 emp E7-.wav" 0 0 0
f1312 0 0 1 "./samples/Bosendor/31 emp F7-.wav" 0 0 0
f1313 0 0 1 "./samples/Bosendor/31 emp G7-.wav" 0 0 0
f1314 0 0 1 "./samples/Bosendor/31 emp A7-.wav" 0 0 0
f1315 0 0 1 "./samples/Bosendor/31 emp B7-.wav" 0 0 0
f1316 0 0 1 "./samples/Bosendor/31 emp C8-.wav" 0 0 0
f1321 0 0 1 "./samples/Bosendor/39 emp A0.wav" 0 0 0
f1322 0 0 1 "./samples/Bosendor/39 emp B0-.wav" 0 0 0
f1323 0 0 1 "./samples/Bosendor/39 emp C1-.wav" 0 0 0
f1324 0 0 1 "./samples/Bosendor/39 emp D1-.wav" 0 0 0
f1325 0 0 1 "./samples/Bosendor/39 emp E1-.wav" 0 0 0
f1326 0 0 1 "./samples/Bosendor/39 emp F1-.wav" 0 0 0
f1327 0 0 1 "./samples/Bosendor/39 emp G1-.wav" 0 0 0
f1328 0 0 1 "./samples/Bosendor/39 emp A1.wav" 0 0 0
f1329 0 0 1 "./samples/Bosendor/39 emp C2-.wav" 0 0 0
f1330 0 0 1 "./samples/Bosendor/39 emp D2-.wav" 0 0 0
f1331 0 0 1 "./samples/Bosendor/39 emp E2-.wav" 0 0 0
f1332 0 0 1 "./samples/Bosendor/39 emp F2-.wav" 0 0 0
f1333 0 0 1 "./samples/Bosendor/39 emp G2-.wav" 0 0 0
f1334 0 0 1 "./samples/Bosendor/39 emp A2-.wav" 0 0 0
f1335 0 0 1 "./samples/Bosendor/39 emp B2-.wav" 0 0 0
f1336 0 0 1 "./samples/Bosendor/39 emp C3-.wav" 0 0 0
f1337 0 0 1 "./samples/Bosendor/39 emp E3-.wav" 0 0 0
f1338 0 0 1 "./samples/Bosendor/39 emp G3-.wav" 0 0 0
f1339 0 0 1 "./samples/Bosendor/39 emp B3-.wav" 0 0 0
f1340 0 0 1 "./samples/Bosendor/39 emp C4-.wav" 0 0 0
f1341 0 0 1 "./samples/Bosendor/39 emp D4-.wav" 0 0 0
f1342 0 0 1 "./samples/Bosendor/39 emp C5-.wav" 0 0 0
f1343 0 0 1 "./samples/Bosendor/39 emp D5-.wav" 0 0 0
f1344 0 0 1 "./samples/Bosendor/39 emp E5-.wav" 0 0 0
f1345 0 0 1 "./samples/Bosendor/39 emp F5-.wav" 0 0 0
f1346 0 0 1 "./samples/Bosendor/39 emp G5-.wav" 0 0 0
f1347 0 0 1 "./samples/Bosendor/39 emp B5-.wav" 0 0 0
f1348 0 0 1 "./samples/Bosendor/39 emp C6-.wav" 0 0 0
f1349 0 0 1 "./samples/Bosendor/39 emp D6-.wav" 0 0 0
f1350 0 0 1 "./samples/Bosendor/39 emp E6-.wav" 0 0 0
f1351 0 0 1 "./samples/Bosendor/39 emp F6-.wav" 0 0 0
f1352 0 0 1 "./samples/Bosendor/39 emp G6-.wav" 0 0 0
f1353 0 0 1 "./samples/Bosendor/39 emp A6-.wav" 0 0 0
f1354 0 0 1 "./samples/Bosendor/39 emp B6-.wav" 0 0 0
f1355 0 0 1 "./samples/Bosendor/39 emp C7-.wav" 0 0 0
f1356 0 0 1 "./samples/Bosendor/39 emp D7-.wav" 0 0 0
f1357 0 0 1 "./samples/Bosendor/39 emp E7-.wav" 0 0 0
f1358 0 0 1 "./samples/Bosendor/39 emp F7-.wav" 0 0 0
f1359 0 0 1 "./samples/Bosendor/39 emp G7-.wav" 0 0 0
f1360 0 0 1 "./samples/Bosendor/39 emp A7-.wav" 0 0 0
f1361 0 0 1 "./samples/Bosendor/39 emp B7-.wav" 0 0 0
f1362 0 0 1 "./samples/Bosendor/39 emp C8-.wav" 0 0 0
f1367 0 0 1 "./samples/Bosendor/47 emp A0.wav" 0 0 0
f1368 0 0 1 "./samples/Bosendor/47 emp B0-.wav" 0 0 0
f1369 0 0 1 "./samples/Bosendor/47 emp C1-.wav" 0 0 0
f1370 0 0 1 "./samples/Bosendor/47 emp D1-.wav" 0 0 0
f1371 0 0 1 "./samples/Bosendor/47 emp E1-.wav" 0 0 0
f1372 0 0 1 "./samples/Bosendor/47 emp F1-.wav" 0 0 0
f1373 0 0 1 "./samples/Bosendor/47 emp G1-.wav" 0 0 0
f1374 0 0 1 "./samples/Bosendor/47 emp A1.wav" 0 0 0
f1375 0 0 1 "./samples/Bosendor/47 emp B1-.wav" 0 0 0
f1376 0 0 1 "./samples/Bosendor/47 emp D2-.wav" 0 0 0
f1377 0 0 1 "./samples/Bosendor/47 emp E2-.wav" 0 0 0
f1378 0 0 1 "./samples/Bosendor/47 emp F2-.wav" 0 0 0
f1379 0 0 1 "./samples/Bosendor/47 emp G2-.wav" 0 0 0
f1380 0 0 1 "./samples/Bosendor/47 emp A2-.wav" 0 0 0
f1381 0 0 1 "./samples/Bosendor/47 emp B2-.wav" 0 0 0
f1382 0 0 1 "./samples/Bosendor/47 emp C3-.wav" 0 0 0
f1383 0 0 1 "./samples/Bosendor/47 emp D3-.wav" 0 0 0
f1384 0 0 1 "./samples/Bosendor/47 emp E3-.wav" 0 0 0
f1385 0 0 1 "./samples/Bosendor/47 emp F3-.wav" 0 0 0
f1386 0 0 1 "./samples/Bosendor/47 emp G3-.wav" 0 0 0
f1387 0 0 1 "./samples/Bosendor/47 emp A3-.wav" 0 0 0
f1388 0 0 1 "./samples/Bosendor/47 emp B3-.wav" 0 0 0
f1389 0 0 1 "./samples/Bosendor/47 emp C4-.wav" 0 0 0
f1390 0 0 1 "./samples/Bosendor/47 emp D4-.wav" 0 0 0
f1391 0 0 1 "./samples/Bosendor/47 emp E4-.wav" 0 0 0
f1392 0 0 1 "./samples/Bosendor/47 emp F4-.wav" 0 0 0
f1393 0 0 1 "./samples/Bosendor/47 emp G4-.wav" 0 0 0
f1394 0 0 1 "./samples/Bosendor/47 emp A4-.wav" 0 0 0
f1395 0 0 1 "./samples/Bosendor/47 emp B4-.wav" 0 0 0
f1396 0 0 1 "./samples/Bosendor/47 emp C5-.wav" 0 0 0
f1397 0 0 1 "./samples/Bosendor/47 emp D5-.wav" 0 0 0
f1398 0 0 1 "./samples/Bosendor/47 emp E5-.wav" 0 0 0
f1399 0 0 1 "./samples/Bosendor/47 emp F5-.wav" 0 0 0
f1400 0 0 1 "./samples/Bosendor/47 emp G5-.wav" 0 0 0
f1401 0 0 1 "./samples/Bosendor/47 emp A5-.wav" 0 0 0
f1402 0 0 1 "./samples/Bosendor/47 emp B5-.wav" 0 0 0
f1403 0 0 1 "./samples/Bosendor/47 emp C6-.wav" 0 0 0
f1404 0 0 1 "./samples/Bosendor/47 emp D6-.wav" 0 0 0
f1405 0 0 1 "./samples/Bosendor/47 emp E6-.wav" 0 0 0
f1406 0 0 1 "./samples/Bosendor/47 emp F6-.wav" 0 0 0
f1407 0 0 1 "./samples/Bosendor/47 emp G6-.wav" 0 0 0
f1408 0 0 1 "./samples/Bosendor/47 emp A6-.wav" 0 0 0
f1409 0 0 1 "./samples/Bosendor/47 emp B6-.wav" 0 0 0
f1410 0 0 1 "./samples/Bosendor/47 emp C7-.wav" 0 0 0
f1411 0 0 1 "./samples/Bosendor/47 emp D7-.wav" 0 0 0
f1412 0 0 1 "./samples/Bosendor/47 emp E7-.wav" 0 0 0
f1413 0 0 1 "./samples/Bosendor/47 emp F7-.wav" 0 0 0
f1414 0 0 1 "./samples/Bosendor/47 emp G7-.wav" 0 0 0
f1415 0 0 1 "./samples/Bosendor/47 emp A7-.wav" 0 0 0
f1416 0 0 1 "./samples/Bosendor/47 emp B7-.wav" 0 0 0
f1417 0 0 1 "./samples/Bosendor/47 emp C8-.wav" 0 0 0
f1422 0 0 1 "./samples/Bosendor/63 emp A0.wav" 0 0 0
f1423 0 0 1 "./samples/Bosendor/63 emp B0-.wav" 0 0 0
f1424 0 0 1 "./samples/Bosendor/63 emp C1-.wav" 0 0 0
f1425 0 0 1 "./samples/Bosendor/63 emp D1-.wav" 0 0 0
f1426 0 0 1 "./samples/Bosendor/63 emp E1-.wav" 0 0 0
f1427 0 0 1 "./samples/Bosendor/63 emp F1-.wav" 0 0 0
f1428 0 0 1 "./samples/Bosendor/63 emp G1-.wav" 0 0 0
f1429 0 0 1 "./samples/Bosendor/63 emp A1.wav" 0 0 0
f1430 0 0 1 "./samples/Bosendor/63 emp B1-.wav" 0 0 0
f1431 0 0 1 "./samples/Bosendor/63 emp C2-.wav" 0 0 0
f1432 0 0 1 "./samples/Bosendor/63 emp D2-.wav" 0 0 0
f1433 0 0 1 "./samples/Bosendor/63 emp E2-.wav" 0 0 0
f1434 0 0 1 "./samples/Bosendor/63 emp F2-.wav" 0 0 0
f1435 0 0 1 "./samples/Bosendor/63 emp G2-.wav" 0 0 0
f1436 0 0 1 "./samples/Bosendor/63 emp A2-.wav" 0 0 0
f1437 0 0 1 "./samples/Bosendor/63 emp B2-.wav" 0 0 0
f1438 0 0 1 "./samples/Bosendor/63 emp C3-.wav" 0 0 0
f1439 0 0 1 "./samples/Bosendor/63 emp D3-.wav" 0 0 0
f1440 0 0 1 "./samples/Bosendor/63 emp E3-.wav" 0 0 0
f1441 0 0 1 "./samples/Bosendor/63 emp F3-.wav" 0 0 0
f1442 0 0 1 "./samples/Bosendor/63 emp G3-.wav" 0 0 0
f1443 0 0 1 "./samples/Bosendor/63 emp A3-.wav" 0 0 0
f1444 0 0 1 "./samples/Bosendor/63 emp B3-.wav" 0 0 0
f1445 0 0 1 "./samples/Bosendor/63 emp C4-.wav" 0 0 0
f1446 0 0 1 "./samples/Bosendor/63 emp D4-.wav" 0 0 0
f1447 0 0 1 "./samples/Bosendor/63 emp E4-.wav" 0 0 0
f1448 0 0 1 "./samples/Bosendor/63 emp F4-.wav" 0 0 0
f1449 0 0 1 "./samples/Bosendor/63 emp G4-.wav" 0 0 0
f1450 0 0 1 "./samples/Bosendor/63 emp A4-.wav" 0 0 0
f1451 0 0 1 "./samples/Bosendor/63 emp B4-.wav" 0 0 0
f1452 0 0 1 "./samples/Bosendor/63 emp C5-.wav" 0 0 0
f1453 0 0 1 "./samples/Bosendor/63 emp D5-.wav" 0 0 0
f1454 0 0 1 "./samples/Bosendor/63 emp E5-.wav" 0 0 0
f1455 0 0 1 "./samples/Bosendor/63 emp F5-.wav" 0 0 0
f1456 0 0 1 "./samples/Bosendor/63 emp G5-.wav" 0 0 0
f1457 0 0 1 "./samples/Bosendor/63 emp A5-.wav" 0 0 0
f1458 0 0 1 "./samples/Bosendor/63 emp B5-.wav" 0 0 0
f1459 0 0 1 "./samples/Bosendor/63 emp C6-.wav" 0 0 0
f1460 0 0 1 "./samples/Bosendor/63 emp D6-.wav" 0 0 0
f1461 0 0 1 "./samples/Bosendor/63 emp E6-.wav" 0 0 0
f1462 0 0 1 "./samples/Bosendor/63 emp F6-.wav" 0 0 0
f1463 0 0 1 "./samples/Bosendor/63 emp G6-.wav" 0 0 0
f1464 0 0 1 "./samples/Bosendor/63 emp A6-.wav" 0 0 0
f1465 0 0 1 "./samples/Bosendor/63 emp B6-.wav" 0 0 0
f1466 0 0 1 "./samples/Bosendor/63 emp C7-.wav" 0 0 0
f1467 0 0 1 "./samples/Bosendor/63 emp D7-.wav" 0 0 0
f1468 0 0 1 "./samples/Bosendor/63 emp E7-.wav" 0 0 0
f1469 0 0 1 "./samples/Bosendor/63 emp F7-.wav" 0 0 0
f1470 0 0 1 "./samples/Bosendor/63 emp G7-.wav" 0 0 0
f1471 0 0 1 "./samples/Bosendor/63 emp A7-.wav" 0 0 0
f1472 0 0 1 "./samples/Bosendor/63 emp B7-.wav" 0 0 0
f1473 0 0 1 "./samples/Bosendor/63 emp C8-.wav" 0 0 0
f1478 0 0 1 "./samples/Bosendor/78 emp B0-.wav" 0 0 0
f1479 0 0 1 "./samples/Bosendor/78 emp C1-.wav" 0 0 0
f1480 0 0 1 "./samples/Bosendor/78 emp D1-.wav" 0 0 0
f1481 0 0 1 "./samples/Bosendor/78 emp E1-.wav" 0 0 0
f1482 0 0 1 "./samples/Bosendor/78 emp F1-.wav" 0 0 0
f1483 0 0 1 "./samples/Bosendor/78 emp G1-.wav" 0 0 0
f1484 0 0 1 "./samples/Bosendor/78 emp A1.wav" 0 0 0
f1485 0 0 1 "./samples/Bosendor/78 emp B1-.wav" 0 0 0
f1486 0 0 1 "./samples/Bosendor/78 emp C2-.wav" 0 0 0
f1487 0 0 1 "./samples/Bosendor/78 emp D2-.wav" 0 0 0
f1488 0 0 1 "./samples/Bosendor/78 emp E2-.wav" 0 0 0
f1489 0 0 1 "./samples/Bosendor/78 emp F2-.wav" 0 0 0
f1490 0 0 1 "./samples/Bosendor/78 emp G2-.wav" 0 0 0
f1491 0 0 1 "./samples/Bosendor/78 emp A2-.wav" 0 0 0
f1492 0 0 1 "./samples/Bosendor/78 emp B2-.wav" 0 0 0
f1493 0 0 1 "./samples/Bosendor/78 emp C3-.wav" 0 0 0
f1494 0 0 1 "./samples/Bosendor/78 emp D3-.wav" 0 0 0
f1495 0 0 1 "./samples/Bosendor/78 emp E3-.wav" 0 0 0
f1496 0 0 1 "./samples/Bosendor/78 emp F3-.wav" 0 0 0
f1497 0 0 1 "./samples/Bosendor/78 emp G3-.wav" 0 0 0
f1498 0 0 1 "./samples/Bosendor/78 emp A3-.wav" 0 0 0
f1499 0 0 1 "./samples/Bosendor/78 emp B3-.wav" 0 0 0
f1500 0 0 1 "./samples/Bosendor/78 emp C4-.wav" 0 0 0
f1501 0 0 1 "./samples/Bosendor/78 emp D4-.wav" 0 0 0
f1502 0 0 1 "./samples/Bosendor/78 emp E4-.wav" 0 0 0
f1503 0 0 1 "./samples/Bosendor/78 emp F4-.wav" 0 0 0
f1504 0 0 1 "./samples/Bosendor/78 emp G4-.wav" 0 0 0
f1505 0 0 1 "./samples/Bosendor/78 emp A4-.wav" 0 0 0
f1506 0 0 1 "./samples/Bosendor/78 emp B4-.wav" 0 0 0
f1507 0 0 1 "./samples/Bosendor/78 emp C5-.wav" 0 0 0
f1508 0 0 1 "./samples/Bosendor/78 emp D5-.wav" 0 0 0
f1509 0 0 1 "./samples/Bosendor/78 emp E5-.wav" 0 0 0
f1510 0 0 1 "./samples/Bosendor/78 emp F5-.wav" 0 0 0
f1511 0 0 1 "./samples/Bosendor/78 emp G5-.wav" 0 0 0
f1512 0 0 1 "./samples/Bosendor/78 emp A5-.wav" 0 0 0
f1513 0 0 1 "./samples/Bosendor/78 emp B5-.wav" 0 0 0
f1514 0 0 1 "./samples/Bosendor/78 emp C6-.wav" 0 0 0
f1515 0 0 1 "./samples/Bosendor/78 emp D6-.wav" 0 0 0
f1516 0 0 1 "./samples/Bosendor/78 emp E6-.wav" 0 0 0
f1517 0 0 1 "./samples/Bosendor/78 emp F6-.wav" 0 0 0
f1518 0 0 1 "./samples/Bosendor/78 emp G6-.wav" 0 0 0
f1519 0 0 1 "./samples/Bosendor/78 emp A6-.wav" 0 0 0
f1520 0 0 1 "./samples/Bosendor/78 emp B6-.wav" 0 0 0
f1521 0 0 1 "./samples/Bosendor/78 emp C7-.wav" 0 0 0
f1522 0 0 1 "./samples/Bosendor/78 emp D7-.wav" 0 0 0
f1523 0 0 1 "./samples/Bosendor/78 emp E7-.wav" 0 0 0
f1524 0 0 1 "./samples/Bosendor/78 emp F7-.wav" 0 0 0
f1525 0 0 1 "./samples/Bosendor/78 emp G7-.wav" 0 0 0
f1526 0 0 1 "./samples/Bosendor/78 emp A7-.wav" 0 0 0
f1527 0 0 1 "./samples/Bosendor/78 emp B7-.wav" 0 0 0
f1528 0 0 1 "./samples/Bosendor/78 emp C8-.wav" 0 0 0
f1533 0 0 1 "./samples/Bosendor/85 emp A0.wav" 0 0 0
f1534 0 0 1 "./samples/Bosendor/85 emp B0-.wav" 0 0 0
f1535 0 0 1 "./samples/Bosendor/85 emp C1-.wav" 0 0 0
f1536 0 0 1 "./samples/Bosendor/85 emp D1-.wav" 0 0 0
f1537 0 0 1 "./samples/Bosendor/85 emp E1-.wav" 0 0 0
f1538 0 0 1 "./samples/Bosendor/85 emp F1-.wav" 0 0 0
f1539 0 0 1 "./samples/Bosendor/85 emp G1-.wav" 0 0 0
f1540 0 0 1 "./samples/Bosendor/85 emp A1.wav" 0 0 0
f1541 0 0 1 "./samples/Bosendor/85 emp B1-.wav" 0 0 0
f1542 0 0 1 "./samples/Bosendor/85 emp C2-.wav" 0 0 0
f1543 0 0 1 "./samples/Bosendor/85 emp D2-.wav" 0 0 0
f1544 0 0 1 "./samples/Bosendor/85 emp E2-.wav" 0 0 0
f1545 0 0 1 "./samples/Bosendor/85 emp F2-.wav" 0 0 0
f1546 0 0 1 "./samples/Bosendor/85 emp G2-.wav" 0 0 0
f1547 0 0 1 "./samples/Bosendor/85 emp A2-.wav" 0 0 0
f1548 0 0 1 "./samples/Bosendor/85 emp B2-.wav" 0 0 0
f1549 0 0 1 "./samples/Bosendor/85 emp C3-.wav" 0 0 0
f1550 0 0 1 "./samples/Bosendor/85 emp D3-.wav" 0 0 0
f1551 0 0 1 "./samples/Bosendor/85 emp E3-.wav" 0 0 0
f1552 0 0 1 "./samples/Bosendor/85 emp F3-.wav" 0 0 0
f1553 0 0 1 "./samples/Bosendor/85 emp G3-.wav" 0 0 0
f1554 0 0 1 "./samples/Bosendor/85 emp A3-.wav" 0 0 0
f1555 0 0 1 "./samples/Bosendor/85 emp B3-.wav" 0 0 0
f1556 0 0 1 "./samples/Bosendor/85 emp C4-.wav" 0 0 0
f1557 0 0 1 "./samples/Bosendor/85 emp D4-.wav" 0 0 0
f1558 0 0 1 "./samples/Bosendor/85 emp E4-.wav" 0 0 0
f1559 0 0 1 "./samples/Bosendor/85 emp F4-.wav" 0 0 0
f1560 0 0 1 "./samples/Bosendor/85 emp G4-.wav" 0 0 0
f1561 0 0 1 "./samples/Bosendor/85 emp A4-.wav" 0 0 0
f1562 0 0 1 "./samples/Bosendor/85 emp B4-.wav" 0 0 0
f1563 0 0 1 "./samples/Bosendor/85 emp C5-.wav" 0 0 0
f1564 0 0 1 "./samples/Bosendor/85 emp D5-.wav" 0 0 0
f1565 0 0 1 "./samples/Bosendor/85 emp E5-.wav" 0 0 0
f1566 0 0 1 "./samples/Bosendor/85 emp F5-.wav" 0 0 0
f1567 0 0 1 "./samples/Bosendor/85 emp G5-.wav" 0 0 0
f1568 0 0 1 "./samples/Bosendor/85 emp A5-.wav" 0 0 0
f1569 0 0 1 "./samples/Bosendor/85 emp B5-.wav" 0 0 0
f1570 0 0 1 "./samples/Bosendor/85 emp C6-.wav" 0 0 0
f1571 0 0 1 "./samples/Bosendor/85 emp D6-.wav" 0 0 0
f1572 0 0 1 "./samples/Bosendor/85 emp E6-.wav" 0 0 0
f1573 0 0 1 "./samples/Bosendor/85 emp F6-.wav" 0 0 0
f1574 0 0 1 "./samples/Bosendor/85 emp G6-.wav" 0 0 0
f1575 0 0 1 "./samples/Bosendor/85 emp A6-.wav" 0 0 0
f1576 0 0 1 "./samples/Bosendor/85 emp B6-.wav" 0 0 0
f1577 0 0 1 "./samples/Bosendor/85 emp C7-.wav" 0 0 0
f1578 0 0 1 "./samples/Bosendor/85 emp D7-.wav" 0 0 0
f1579 0 0 1 "./samples/Bosendor/85 emp E7-.wav" 0 0 0
f1580 0 0 1 "./samples/Bosendor/85 emp F7-.wav" 0 0 0
f1581 0 0 1 "./samples/Bosendor/85 emp G7-.wav" 0 0 0
f1582 0 0 1 "./samples/Bosendor/85 emp A7-.wav" 0 0 0
f1583 0 0 1 "./samples/Bosendor/85 emp B7-.wav" 0 0 0
f1584 0 0 1 "./samples/Bosendor/85 emp C8-.wav" 0 0 0
f1589 0 0 1 "./samples/Bosendor/99 emp A0.wav" 0 0 0
f1590 0 0 1 "./samples/Bosendor/99 emp B0-.wav" 0 0 0
f1591 0 0 1 "./samples/Bosendor/99 emp C1-.wav" 0 0 0
f1592 0 0 1 "./samples/Bosendor/99 emp D1-.wav" 0 0 0
f1593 0 0 1 "./samples/Bosendor/99 emp E1-.wav" 0 0 0
f1594 0 0 1 "./samples/Bosendor/99 emp F1-.wav" 0 0 0
f1595 0 0 1 "./samples/Bosendor/99 emp G1-.wav" 0 0 0
f1596 0 0 1 "./samples/Bosendor/99 emp A1.wav" 0 0 0
f1597 0 0 1 "./samples/Bosendor/99 emp B1-.wav" 0 0 0
f1598 0 0 1 "./samples/Bosendor/99 emp C2-.wav" 0 0 0
f1599 0 0 1 "./samples/Bosendor/99 emp D2-.wav" 0 0 0
f1600 0 0 1 "./samples/Bosendor/99 emp E2-.wav" 0 0 0
f1601 0 0 1 "./samples/Bosendor/99 emp F2-.wav" 0 0 0
f1602 0 0 1 "./samples/Bosendor/99 emp G2-.wav" 0 0 0
f1603 0 0 1 "./samples/Bosendor/99 emp A2-.wav" 0 0 0
f1604 0 0 1 "./samples/Bosendor/99 emp B2-.wav" 0 0 0
f1605 0 0 1 "./samples/Bosendor/99 emp C3-.wav" 0 0 0
f1606 0 0 1 "./samples/Bosendor/99 emp D3-.wav" 0 0 0
f1607 0 0 1 "./samples/Bosendor/99 emp E3-.wav" 0 0 0
f1608 0 0 1 "./samples/Bosendor/99 emp F3-.wav" 0 0 0
f1609 0 0 1 "./samples/Bosendor/99 emp G3-.wav" 0 0 0
f1610 0 0 1 "./samples/Bosendor/99 emp A3-.wav" 0 0 0
f1611 0 0 1 "./samples/Bosendor/99 emp B3-.wav" 0 0 0
f1612 0 0 1 "./samples/Bosendor/99 emp C4-.wav" 0 0 0
f1613 0 0 1 "./samples/Bosendor/99 emp D4-.wav" 0 0 0
f1614 0 0 1 "./samples/Bosendor/99 emp E4-.wav" 0 0 0
f1615 0 0 1 "./samples/Bosendor/99 emp F4-.wav" 0 0 0
f1616 0 0 1 "./samples/Bosendor/99 emp G4-.wav" 0 0 0
f1617 0 0 1 "./samples/Bosendor/99 emp A4-.wav" 0 0 0
f1618 0 0 1 "./samples/Bosendor/99 emp B4-.wav" 0 0 0
f1619 0 0 1 "./samples/Bosendor/99 emp C5-.wav" 0 0 0
f1620 0 0 1 "./samples/Bosendor/99 emp D5-.wav" 0 0 0
f1621 0 0 1 "./samples/Bosendor/99 emp E5-.wav" 0 0 0
f1622 0 0 1 "./samples/Bosendor/99 emp F5-.wav" 0 0 0
f1623 0 0 1 "./samples/Bosendor/99 emp G5-.wav" 0 0 0
f1624 0 0 1 "./samples/Bosendor/99 emp A5-.wav" 0 0 0
f1625 0 0 1 "./samples/Bosendor/99 emp B5-.wav" 0 0 0
f1626 0 0 1 "./samples/Bosendor/99 emp C6-.wav" 0 0 0
f1627 0 0 1 "./samples/Bosendor/99 emp D6-.wav" 0 0 0
f1628 0 0 1 "./samples/Bosendor/99 emp E6-.wav" 0 0 0
f1629 0 0 1 "./samples/Bosendor/99 emp F6-.wav" 0 0 0
f1630 0 0 1 "./samples/Bosendor/99 emp G6-.wav" 0 0 0
f1631 0 0 1 "./samples/Bosendor/99 emp A6-.wav" 0 0 0
f1632 0 0 1 "./samples/Bosendor/99 emp B6-.wav" 0 0 0
f1633 0 0 1 "./samples/Bosendor/99 emp C7-.wav" 0 0 0
f1634 0 0 1 "./samples/Bosendor/99 emp D7-.wav" 0 0 0
f1635 0 0 1 "./samples/Bosendor/99 emp E7-.wav" 0 0 0
f1636 0 0 1 "./samples/Bosendor/99 emp F7-.wav" 0 0 0
f1637 0 0 1 "./samples/Bosendor/99 emp G7-.wav" 0 0 0
f1638 0 0 1 "./samples/Bosendor/99 emp A7-.wav" 0 0 0
f1639 0 0 1 "./samples/Bosendor/99 emp B7-.wav" 0 0 0
f1640 0 0 1 "./samples/Bosendor/99 emp C8-.wav" 0 0 0
f1645 0 0 1 "./samples/Bosendor/113 emp A0.wav" 0 0 0
f1646 0 0 1 "./samples/Bosendor/113 emp B0-.wav" 0 0 0
f1647 0 0 1 "./samples/Bosendor/113 emp C1-.wav" 0 0 0
f1648 0 0 1 "./samples/Bosendor/113 emp D1-.wav" 0 0 0
f1649 0 0 1 "./samples/Bosendor/113 emp E1-.wav" 0 0 0
f1650 0 0 1 "./samples/Bosendor/113 emp F1-.wav" 0 0 0
f1651 0 0 1 "./samples/Bosendor/113 emp G1-.wav" 0 0 0
f1652 0 0 1 "./samples/Bosendor/113 emp A1.wav" 0 0 0
f1653 0 0 1 "./samples/Bosendor/113 emp B1-.wav" 0 0 0
f1654 0 0 1 "./samples/Bosendor/113 emp C2-.wav" 0 0 0
f1655 0 0 1 "./samples/Bosendor/113 emp D2-.wav" 0 0 0
f1656 0 0 1 "./samples/Bosendor/113 emp E2-.wav" 0 0 0
f1657 0 0 1 "./samples/Bosendor/113 emp F2-.wav" 0 0 0
f1658 0 0 1 "./samples/Bosendor/113 emp A2-.wav" 0 0 0
f1659 0 0 1 "./samples/Bosendor/113 emp B2-.wav" 0 0 0
f1660 0 0 1 "./samples/Bosendor/113 emp C3-.wav" 0 0 0
f1661 0 0 1 "./samples/Bosendor/113 emp D3-.wav" 0 0 0
f1662 0 0 1 "./samples/Bosendor/113 emp E3-.wav" 0 0 0
f1663 0 0 1 "./samples/Bosendor/113 emp F3-.wav" 0 0 0
f1664 0 0 1 "./samples/Bosendor/113 emp G3-.wav" 0 0 0
f1665 0 0 1 "./samples/Bosendor/113 emp A3-.wav" 0 0 0
f1666 0 0 1 "./samples/Bosendor/113 emp B3-.wav" 0 0 0
f1667 0 0 1 "./samples/Bosendor/113 emp C4-.wav" 0 0 0
f1668 0 0 1 "./samples/Bosendor/113 emp D4-.wav" 0 0 0
f1669 0 0 1 "./samples/Bosendor/113 emp E4-.wav" 0 0 0
f1670 0 0 1 "./samples/Bosendor/113 emp F4-.wav" 0 0 0
f1671 0 0 1 "./samples/Bosendor/113 emp G4-.wav" 0 0 0
f1672 0 0 1 "./samples/Bosendor/113 emp A4-.wav" 0 0 0
f1673 0 0 1 "./samples/Bosendor/113 emp B4-.wav" 0 0 0
f1674 0 0 1 "./samples/Bosendor/113 emp C5-.wav" 0 0 0
f1675 0 0 1 "./samples/Bosendor/113 emp D5-.wav" 0 0 0
f1676 0 0 1 "./samples/Bosendor/113 emp E5-.wav" 0 0 0
f1677 0 0 1 "./samples/Bosendor/113 emp F5-.wav" 0 0 0
f1678 0 0 1 "./samples/Bosendor/113 emp G5-.wav" 0 0 0
f1679 0 0 1 "./samples/Bosendor/113 emp A5-.wav" 0 0 0
f1680 0 0 1 "./samples/Bosendor/113 emp B5-.wav" 0 0 0
f1681 0 0 1 "./samples/Bosendor/113 emp C6-.wav" 0 0 0
f1682 0 0 1 "./samples/Bosendor/113 emp D6-.wav" 0 0 0
f1683 0 0 1 "./samples/Bosendor/113 emp E6-.wav" 0 0 0
f1684 0 0 1 "./samples/Bosendor/113 emp F6-.wav" 0 0 0
f1685 0 0 1 "./samples/Bosendor/113 emp G6-.wav" 0 0 0
f1686 0 0 1 "./samples/Bosendor/113 emp A6-.wav" 0 0 0
f1687 0 0 1 "./samples/Bosendor/113 emp B6-.wav" 0 0 0
f1688 0 0 1 "./samples/Bosendor/113 emp C7-.wav" 0 0 0
f1689 0 0 1 "./samples/Bosendor/113 emp D7-.wav" 0 0 0
f1690 0 0 1 "./samples/Bosendor/113 emp E7-.wav" 0 0 0
f1691 0 0 1 "./samples/Bosendor/113 emp F7-.wav" 0 0 0
f1692 0 0 1 "./samples/Bosendor/113 emp G7-.wav" 0 0 0
f1693 0 0 1 "./samples/Bosendor/113 emp A7-.wav" 0 0 0
f1694 0 0 1 "./samples/Bosendor/113 emp B7-.wav" 0 0 0
f1695 0 0 1 "./samples/Bosendor/113 emp C8-.wav" 0 0 0
f1700 0 0 1 "./samples/Bosendor/127 emp A0.wav" 0 0 0
f1701 0 0 1 "./samples/Bosendor/127 emp B0-.wav" 0 0 0
f1702 0 0 1 "./samples/Bosendor/127 emp C1-.wav" 0 0 0
f1703 0 0 1 "./samples/Bosendor/127 emp D1-.wav" 0 0 0
f1704 0 0 1 "./samples/Bosendor/127 emp E1-.wav" 0 0 0
f1705 0 0 1 "./samples/Bosendor/127 emp F1-.wav" 0 0 0
f1706 0 0 1 "./samples/Bosendor/127 emp G1-.wav" 0 0 0
f1707 0 0 1 "./samples/Bosendor/127 emp A1.wav" 0 0 0
f1708 0 0 1 "./samples/Bosendor/127 emp B1-.wav" 0 0 0
f1709 0 0 1 "./samples/Bosendor/127 emp C2-.wav" 0 0 0
f1710 0 0 1 "./samples/Bosendor/127 emp D2-.wav" 0 0 0
f1711 0 0 1 "./samples/Bosendor/127 emp E2-.wav" 0 0 0
f1712 0 0 1 "./samples/Bosendor/127 emp F2-.wav" 0 0 0
f1713 0 0 1 "./samples/Bosendor/127 emp G2-.wav" 0 0 0
f1714 0 0 1 "./samples/Bosendor/127 emp A2-.wav" 0 0 0
f1715 0 0 1 "./samples/Bosendor/127 emp B2-.wav" 0 0 0
f1716 0 0 1 "./samples/Bosendor/127 emp D3-.wav" 0 0 0
f1717 0 0 1 "./samples/Bosendor/127 emp E3-.wav" 0 0 0
f1718 0 0 1 "./samples/Bosendor/127 emp F3-.wav" 0 0 0
f1719 0 0 1 "./samples/Bosendor/127 emp G3-.wav" 0 0 0
f1720 0 0 1 "./samples/Bosendor/127 emp A3-.wav" 0 0 0
f1721 0 0 1 "./samples/Bosendor/127 emp B3-.wav" 0 0 0
f1722 0 0 1 "./samples/Bosendor/127 emp C4-.wav" 0 0 0
f1723 0 0 1 "./samples/Bosendor/127 emp D4-.wav" 0 0 0
f1724 0 0 1 "./samples/Bosendor/127 emp E4-.wav" 0 0 0
f1725 0 0 1 "./samples/Bosendor/127 emp F4-.wav" 0 0 0
f1726 0 0 1 "./samples/Bosendor/127 emp G4-.wav" 0 0 0
f1727 0 0 1 "./samples/Bosendor/127 emp A4-.wav" 0 0 0
f1728 0 0 1 "./samples/Bosendor/127 emp B4-.wav" 0 0 0
f1729 0 0 1 "./samples/Bosendor/127 emp C5-.wav" 0 0 0
f1730 0 0 1 "./samples/Bosendor/127 emp D5-.wav" 0 0 0
f1731 0 0 1 "./samples/Bosendor/127 emp E5-.wav" 0 0 0
f1732 0 0 1 "./samples/Bosendor/127 emp F5-.wav" 0 0 0
f1733 0 0 1 "./samples/Bosendor/127 emp G5-.wav" 0 0 0
f1734 0 0 1 "./samples/Bosendor/127 emp A5-.wav" 0 0 0
f1735 0 0 1 "./samples/Bosendor/127 emp B5-.wav" 0 0 0
f1736 0 0 1 "./samples/Bosendor/127 emp C6-.wav" 0 0 0
f1737 0 0 1 "./samples/Bosendor/127 emp D6-.wav" 0 0 0
f1738 0 0 1 "./samples/Bosendor/127 emp E6-.wav" 0 0 0
f1739 0 0 1 "./samples/Bosendor/127 emp F6-.wav" 0 0 0
f1740 0 0 1 "./samples/Bosendor/127 emp G6-.wav" 0 0 0
f1741 0 0 1 "./samples/Bosendor/127 emp A6-.wav" 0 0 0
f1742 0 0 1 "./samples/Bosendor/127 emp B6-.wav" 0 0 0
f1743 0 0 1 "./samples/Bosendor/127 emp C7-.wav" 0 0 0
f1744 0 0 1 "./samples/Bosendor/127 emp D7-.wav" 0 0 0
f1745 0 0 1 "./samples/Bosendor/127 emp E7-.wav" 0 0 0
f1746 0 0 1 "./samples/Bosendor/127 emp F7-.wav" 0 0 0
f1747 0 0 1 "./samples/Bosendor/127 emp G7-.wav" 0 0 0
f1748 0 0 1 "./samples/Bosendor/127 emp A7-.wav" 0 0 0
f1749 0 0 1 "./samples/Bosendor/127 emp B7-.wav" 0 0 0
f1750 0 0 1 "./samples/Bosendor/127 emp C8-.wav" 0 0 0
;              1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18  19  20   21   22   23   24   25   26   27   28   29   30   31   32   33   34   35   36   37   38 
f1 0 64 -2 0 601 630 652 667 683 705 726 742 766 787 807 830 850 872 890 909 930 953 975 999 1030 1070 1104 1130 1156 1177 1192 1212 1217 1262 1317 1363 1418 1474 1529 1585 1641 1696 
f2 0 64 -2 0 1 2 2 2 2 2 2 1 2 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 2 2 2 1 5 5 5 5 5 5 5 5 5 5
;Inst Start        Dur  Vel    Ton   Oct   Voice Stere Envlp Gliss Upsamp R-Env 2nd-gl 3rd Mult Line # ; Channel
;p1   p2           p3   p4     p5    p6    p7    p8    p9    p10   p11    p12   p13   p14  p15; Channel

f5000.0 0.0 256.0 -6.0 1.0 128.0 1.002316 128.0 1.004632 
f5001.0 0.0 256.0 -6.0 1.0 128.0 1.002606 128.0 1.005212 
f5002.0 0.0 256.0 -6.0 1.0 128.0 0.9965459999999999 128.0 0.993092 
f5003.0 0.0 256.0 -6.0 1.0 128.0 1.00406 128.0 1.00812 
f5004.0 0.0 256.0 -6.0 1.0 128.0 0.99827 128.0 0.99654 
f5005.0 0.0 256.0 -6.0 1.0 128.0 1.001736 128.0 1.003472 
;Inst	Sta	Hold	Vel	Ton	Oct	Voi	Ste	En1	Gls	Ups	Ren	2gl	3gl	Vol
i 1	0.0004013605442176882	12.625	61	204	7	17	4	16	0	1	16	0	0	0.5009235345346933	
i 1	0.001204081632653061	0.2525	73	702	3	24	15	16	0	2	16	0	0	4.0	
i 1	0.004414965986394558	3.0300000000000002	61	204	4	14	5	16	0	2	16	0	0	6.513827711769258	
i 1	0.0052176870748299325	6.0600000000000005	63	1088	3	13	7	1	0	2	1	0	0	2.605531084707703	
i 1	0.006823129251700678	0.2525	71	204	5	5	2	8	0	-1	8	0	0	6.0	
i 1	0.00682312925170068	0.505	75	204	5	1	8	2	0	1	2	0	0	10.0	
i 1	0.0092312925170068	0.2525	77	1088	4	4	1	16	0	2	16	0	0	4.0	
i 1	0.01083673469387755	3.0300000000000002	63	204	3	14	8	16	0	2	16	0	0	6.513827711769258	
i 1	0.011639455782312923	1.01	72	204	4	1	7	2	0	-2	2	0	0	10.0	
i 1	0.012442176870748299	1.5150000000000001	77	204	7	2	12	17	0	1	17	0	0	4.0	
i 1	0.012442176870748299	1.5150000000000001	74	204	5	5	16	8	0	-2	8	0	0	6.0	
i 1	0.014047619047619047	9.09	61	1088	4	7	7	16	0	1	16	0	0	5.211062169415406	
i 1	0.017258503401360543	0.2525	74	702	4	5	12	2	0	-2	2	0	0	6.0	
i 1	0.23033333333333333	0.2525	77	702	5	9	14	17	0	2	17	0	0	3.0	
i 1	0.23354421768707484	0.2525	74	702	4	4	5	16	0	1	16	0	0	4.0	
i 1	0.2680612244897959	0.2525	71	702	4	5	9	8	0	-1	8	0	0	6.0	
i 1	0.4875578231292517	0.2525	75	702	5	1	4	8	0	-2	8	0	0	10.0	
i 1	0.5028095238095238	0.505	77	1088	4	4	2	16	0	2	16	0	0	4.0	
i 1	0.5188639455782313	0.2525	77	702	5	9	15	17	0	1	17	0	0	3.0	
i 1	0.761639455782313	2.2725	75	204	5	1	15	2	0	1	2	0	0	10.0	
i 1	0.9987959183673469	0.2525	77	702	5	9	12	17	0	2	17	0	0	3.0	
i 1	1.0020068027210884	0.2525	72	702	5	1	14	2	0	1	2	0	0	10.0	
i 1	1.0044149659863946	0.2525	77	702	5	9	13	17	0	1	17	0	0	3.0	
i 1	1.0092312925170068	1.2625	73	702	3	24	12	16	0	2	16	0	0	4.0	
i 1	1.0196666666666667	0.2525	71	1088	4	5	2	8	0	-1	8	0	0	6.0	
i 1	1.2311360544217687	0.505	71	204	5	5	7	8	0	-1	8	0	0	6.0	
i 1	1.2375578231292517	0.505	77	1088	4	4	10	16	0	2	16	0	0	4.0	
i 1	1.2688639455782313	0.2525	72	1088	4	24	15	8	0	1	8	0	0	11.0	
i 1	1.4899659863945578	0.2525	71	1088	4	5	1	2	0	-2	2	0	0	6.0	
i 1	1.5028095238095238	1.5150000000000001	77	204	6	2	7	16	0	2	16	0	0	4.0	
i 1	1.735952380952381	0.2525	74	702	4	4	8	16	0	1	16	0	0	4.0	
i 1	1.738360544217687	1.7675	71	1088	4	5	4	8	0	-1	8	0	0	6.0	
i 1	1.7407687074829932	0.2525	72	1088	4	1	15	2	0	1	2	0	0	10.0	
i 1	1.751204081632653	1.01	73	702	3	24	12	16	0	2	16	0	0	4.0	
i 1	1.75521768707483	0.2525	72	702	5	1	5	2	0	1	2	0	0	10.0	
i 1	1.7672585034013606	0.505	74	204	5	5	16	8	0	-2	8	0	0	6.0	
i 1	2.0132448979591837	0.2525	77	1088	4	4	4	16	0	2	16	0	0	4.0	
i 1	2.018061224489796	0.7575000000000001	72	1088	4	24	16	8	0	1	8	0	0	11.0	
i 1	2.2560204081632653	0.7575000000000001	73	702	1	24	11	16	0	252	16	307	0	4.0	
i 1	2.268061224489796	0.2525	74	702	4	5	5	2	0	-2	2	0	0	6.0	
i 1	2.4803333333333333	1.2625	72	1088	4	1	6	2	0	1	2	0	0	10.0	
i 1	2.4851496598639455	0.2525	71	204	5	5	14	8	0	-1	8	0	0	6.0	
i 1	2.9827414965986394	1.2625	76	702	3	20	12	16	0	1	16	0	0	0.7914432566067586	
i 1	2.9827414965986394	9.09	61	204	6	14	8	16	0	2	16	0	0	6.513827711769258	
i 1	2.983544217687075	3.0300000000000002	63	204	4	14	2	16	0	2	16	0	0	6.513827711769258	
i 1	2.988360544217687	2.2725	72	204	7	1	8	2	0	-2	2	0	0	10.0	
i 1	2.9979931972789116	1.2625	76	702	2	20	3	16	0	1	16	0	0	0.7914432566067586	
i 1	3.0108367346938776	9.595	63	204	7	17	5	1	0	1	1	0	0	0.5009235345346933	
i 1	3.2311360544217687	1.7675	77	1088	5	3	8	16	0	1	16	0	0	4.0	
i 1	3.2327414965986394	0.2525	77	702	5	9	16	17	0	1	17	0	0	3.0	
i 1	3.235952380952381	0.2525	72	1088	4	24	16	8	0	1	8	0	0	11.0	
i 1	3.2520068027210884	0.2525	71	1088	4	5	8	2	0	-2	2	0	0	6.0	
i 1	3.25521768707483	1.2625	74	204	7	5	15	8	0	-2	8	0	0	6.0	
i 1	3.48434693877551	0.505	71	702	4	5	15	8	0	-1	8	0	0	6.0	
i 1	3.488360544217687	0.2525	76	702	1	20	3	16	0	1	16	0	0	0.7914432566067586	
i 1	3.489965986394558	0.505	77	204	7	2	3	16	0	2	16	0	0	4.0	
i 1	3.4915714285714285	0.2525	75	204	4	1	6	2	0	1	2	0	0	10.0	
i 1	3.757625850340136	0.505	77	702	5	3	6	17	0	1	17	0	0	4.0	
i 1	3.988360544217687	0.2525	74	702	4	5	12	2	0	-2	2	0	0	6.0	
i 1	4.009231292517007	0.2525	75	702	4	1	14	8	0	-2	8	0	0	10.0	
i 1	4.010034013605442	0.2525	71	1088	4	5	16	2	0	-2	2	0	0	6.0	
i 1	4.0148503401360545	0.2525	75	702	4	24	12	2	0	1	2	0	0	11.0	
i 1	4.2415714285714285	0.2525	77	702	5	9	6	17	0	1	17	0	0	3.0	
i 1	4.252809523809524	1.2625	76	702	1	24	1	17	0	1	17	0	0	4.791443256606758	
i 1	4.261639455782313	1.7675	73	702	3	20	9	16	0	2	16	0	0	0.7914432566067586	
i 1	4.262442176870748	0.505	72	1088	4	1	2	2	0	1	2	0	0	10.0	
i 1	4.269666666666667	0.505	71	702	4	5	4	8	0	-1	8	0	0	6.0	
i 1	4.503612244897959	1.5150000000000001	71	204	5	5	10	8	0	-1	8	0	0	6.0	
i 1	4.517258503401361	2.2725	77	204	7	2	8	17	0	1	17	0	0	4.0	
i 1	4.745585034013605	0.505	71	702	4	5	1	8	0	-1	8	0	0	6.0	
i 1	4.751204081632653	0.2525	75	702	4	24	5	2	0	1	2	0	0	11.0	
i 1	4.996387755102041	0.2525	77	1088	4	4	8	16	0	2	16	0	0	4.0	
i 1	5.006823129251701	0.505	75	702	4	1	13	2	0	1	2	0	0	10.0	
i 1	5.018863945578231	1.01	75	204	4	1	5	2	0	1	2	0	0	10.0	
i 1	5.231136054421769	0.2525	71	1088	4	5	9	2	0	-2	2	0	0	6.0	
i 1	5.240768707482993	0.2525	74	702	4	4	1	16	0	1	16	0	0	4.0	
i 1	5.254414965986395	0.505	71	702	4	5	4	8	0	-1	8	0	0	6.0	
i 1	5.497993197278912	0.505	73	1088	1	20	5	17	0	2	17	0	0	0.7914432566067586	
i 1	5.50521768707483	0.2525	74	702	4	5	2	2	0	-2	2	0	0	6.0	
i 1	5.514047619047619	1.2625	72	1088	4	24	10	8	0	1	8	0	0	11.0	
i 1	5.768061224489796	0.2525	73	204	3	20	2	16	0	1	16	0	0	0.7914432566067586	
i 1	5.981136054421769	0.2525	75	702	4	1	11	8	0	-2	8	0	0	10.0	
i 1	5.9851496598639455	6.565	63	204	6	14	12	16	0	2	16	0	0	6.513827711769258	
i 1	5.986755102040816	3.0300000000000002	63	1088	3	13	1	1	0	2	1	0	0	2.605531084707703	
i 1	5.988360544217687	6.565	61	1088	6	17	5	1	0	2	1	0	0	0.5009235345346933	
i 1	5.996387755102041	1.01	73	702	3	24	2	16	0	2	16	0	0	4.791443256606758	
i 1	5.997993197278912	1.5150000000000001	71	1088	4	5	15	8	0	-1	8	0	0	6.0	
i 1	6.002006802721088	1.01	76	702	2	20	13	16	0	2	16	0	0	0.7914432566067586	
i 1	6.009231292517007	0.2525	75	702	4	24	2	2	0	1	2	0	0	11.0	
i 1	6.232741496598639	0.2525	77	702	5	9	8	17	0	2	17	0	0	3.0	
i 1	6.247190476190476	0.2525	75	702	4	1	3	2	0	1	2	0	0	10.0	
i 1	6.252809523809524	1.01	77	204	7	2	8	16	0	2	16	0	0	4.0	
i 1	6.2648503401360545	0.2525	72	204	7	1	9	2	0	-2	2	0	0	10.0	
i 1	6.2648503401360545	0.2525	76	702	3	20	5	16	0	1	16	0	0	0.7914432566067586	
i 1	6.489163265306122	0.2525	72	702	6	1	9	2	0	1	2	0	0	10.0	
i 1	6.493176870748299	1.7675	72	1088	3	1	1	2	0	1	2	0	0	10.0	
i 1	6.506823129251701	0.2525	73	702	3	24	11	16	0	2	16	0	0	4.791443256606758	
i 1	6.514047619047619	0.2525	74	702	4	5	2	2	0	-2	2	0	0	6.0	
i 1	6.748795918367347	1.2625	73	702	1	24	11	16	0	252	16	307	0	4.791443256606758	
i 1	6.754414965986395	0.505	74	204	7	5	7	8	0	-2	8	0	0	6.0	
i 1	6.759231292517007	0.505	75	204	7	1	6	2	0	1	2	0	0	10.0	
i 1	6.766455782312925	0.2525	77	702	5	9	13	17	0	1	17	0	0	3.0	
i 1	6.981136054421769	0.2525	71	702	4	5	6	8	0	-1	8	0	0	6.0	
i 1	6.997190476190476	0.2525	76	1088	2	20	3	16	0	2	16	0	0	0.7914432566067586	
i 1	6.999598639455782	0.2525	72	702	4	1	4	2	0	1	2	0	0	10.0	
i 1	7.00521768707483	0.2525	74	702	4	4	11	16	0	1	16	0	0	4.0	
i 1	7.013244897959184	1.7675	77	1088	4	4	14	16	0	2	16	0	0	4.0	
i 1	7.018061224489796	1.01	73	702	3	20	6	16	0	2	16	0	0	0.7914432566067586	
i 1	7.236755102040816	0.2525	75	702	4	24	15	2	0	1	2	0	0	11.0	
i 1	7.242374149659864	0.7575000000000001	71	1088	4	5	6	2	0	-2	2	0	0	6.0	
i 1	7.24478231292517	0.7575000000000001	77	702	5	3	13	17	0	1	17	0	0	4.0	
i 1	7.247993197278912	0.505	76	702	1	24	10	17	0	2	17	0	0	4.791443256606758	
i 1	7.256020408163265	0.505	76	702	2	20	6	17	0	2	17	0	0	0.7914432566067586	
i 1	7.481136054421769	0.2525	71	204	7	5	2	8	0	-1	8	0	0	6.0	
i 1	7.489163265306122	0.2525	75	702	4	1	16	8	0	-2	8	0	0	10.0	
i 1	7.496387755102041	0.2525	75	204	7	1	11	2	0	1	2	0	0	10.0	
i 1	7.500401360544218	0.2525	71	702	4	5	11	8	0	-1	8	0	0	6.0	
i 1	7.735952380952381	0.7575000000000001	72	204	7	1	4	2	0	-2	2	0	0	10.0	
i 1	7.739163265306122	0.2525	77	702	5	9	4	17	0	1	17	0	0	3.0	
i 1	7.74478231292517	1.7675	74	204	7	5	14	8	0	-2	8	0	0	6.0	
i 1	7.750401360544218	0.2525	76	1088	2	20	1	17	0	1	17	0	0	0.7914432566067586	
i 1	7.757625850340136	0.7575000000000001	73	702	3	24	10	16	0	2	16	0	0	4.791443256606758	
i 1	7.768863945578231	0.2525	76	1088	1	24	4	17	0	2	17	0	0	4.791443256606758	
i 1	7.769666666666667	0.2525	74	702	4	5	15	2	0	-2	2	0	0	6.0	
i 1	7.983544217687075	0.2525	73	702	1	24	9	16	0	2	16	0	0	4.791443256606758	
i 1	7.998795918367347	0.505	73	702	2	20	11	16	0	1	16	0	0	0.7914432566067586	
i 1	8.006020408163264	0.2525	77	204	7	2	8	17	0	1	17	0	0	4.0	
i 1	8.247993197278912	0.2525	75	702	4	1	15	2	0	1	2	0	0	10.0	
i 1	8.269666666666666	0.505	75	702	4	24	16	2	0	1	2	0	0	11.0	
i 1	8.497993197278912	0.2525	76	1088	2	20	2	17	0	2	17	0	0	0.7914432566067586	
i 1	8.499598639455783	0.7575000000000001	75	204	7	1	16	2	0	1	2	0	0	10.0	
i 1	8.50842857142857	0.505	73	702	3	20	8	16	0	2	16	0	0	0.7914432566067586	
i 1	8.513244897959183	1.7675	77	1088	5	3	10	16	0	1	16	0	0	4.0	
i 1	8.730333333333334	0.2525	73	702	2	20	8	17	0	1	17	0	0	0.7914432566067586	
i 1	8.735952380952382	0.2525	72	1088	3	1	10	2	0	1	2	0	0	10.0	
i 1	8.743979591836736	0.2525	71	1088	4	5	15	2	0	-2	2	0	0	6.0	
i 1	8.743979591836736	0.2525	73	702	1	24	5	16	0	2	16	0	0	4.791443256606758	
i 1	8.7568231292517	1.01	71	204	7	5	4	8	0	-1	8	0	0	6.0	
i 1	8.766455782312924	0.2525	76	702	2	20	10	16	0	2	16	0	0	0.7914432566067586	
i 1	8.986755102040817	0.2525	77	702	5	9	16	17	0	1	17	0	0	3.0	
i 1	8.997190476190477	3.535	63	1088	5	13	7	1	0	2	1	0	0	2.605531084707703	
i 1	8.997993197278912	0.2525	77	1088	4	4	11	16	0	2	16	0	0	4.0	
i 1	9.013244897959183	3.0300000000000002	61	1088	4	7	15	16	0	1	16	0	0	5.211062169415406	
i 1	9.014850340136054	3.535	63	1088	6	17	7	16	0	1	16	0	0	0.5009235345346933	
i 1	9.015653061224489	0.2525	72	204	7	1	9	2	0	-2	2	0	0	10.0	
i 1	9.247190476190477	1.2625	71	1088	4	5	6	8	0	-1	8	0	0	6.0	
i 1	9.254414965986394	0.505	75	702	4	1	14	2	0	1	2	0	0	10.0	
i 1	9.257625850340135	1.5150000000000001	72	1088	3	24	1	8	0	1	8	0	0	11.0	
i 1	9.264047619047618	0.505	77	702	5	3	14	17	0	1	17	0	0	4.0	
i 1	9.50842857142857	0.2525	73	702	3	20	6	16	0	2	16	0	0	0.6335246007848028	
i 1	9.736755102040817	0.2525	74	204	7	5	10	8	0	-2	8	0	0	6.0	
i 1	9.748795918367348	0.2525	75	702	4	1	11	8	0	-2	8	0	0	10.0	
i 1	9.757625850340135	0.2525	75	204	7	1	11	2	0	1	2	0	0	10.0	
i 1	9.759231292517006	2.2725	73	702	1	24	12	16	0	2	16	0	0	4.633524600784803	
i 1	9.760034013605441	2.525	76	702	2	20	13	16	0	1	16	0	0	0.6335246007848028	
i 1	9.764047619047618	0.2525	74	702	4	5	4	2	0	-1	2	0	0	6.0	
i 1	9.765653061224489	0.7575000000000001	77	204	7	2	14	17	0	1	17	0	0	4.0	
i 1	9.768061224489795	0.7575000000000001	76	702	1	24	4	16	0	252	16	307	0	4.633524600784803	
i 1	10.005217687074829	0.2525	75	702	4	24	5	2	0	1	2	0	0	11.0	
i 1	10.005217687074829	0.2525	71	1088	6	5	12	2	0	-2	2	0	0	6.0	
i 1	10.01725850340136	0.2525	76	702	2	20	10	17	0	1	17	0	0	0.6335246007848028	
i 1	10.259231292517006	0.505	74	702	4	4	12	16	0	1	16	0	0	4.0	
i 1	10.262442176870747	1.7675	72	1088	6	1	12	2	0	1	2	0	0	10.0	
i 1	10.26725850340136	2.02	77	204	7	2	7	16	0	2	16	0	0	4.0	
i 1	10.483544217687076	0.7575000000000001	77	1088	5	3	1	16	0	1	16	0	0	4.0	
i 1	10.494782312925171	1.7675	71	1088	6	5	5	2	0	-2	2	0	0	6.0	
i 1	10.495585034013606	0.2525	76	702	2	24	5	16	0	2	16	0	0	4.633524600784803	
i 1	10.511639455782312	0.2525	75	702	4	1	1	2	0	1	2	0	0	10.0	
i 1	10.76725850340136	1.2625	72	204	7	1	9	2	0	-2	2	0	0	10.0	
i 1	10.768061224489795	1.5150000000000001	76	702	1	24	5	16	0	252	16	307	0	4.633524600784803	
i 1	10.989163265306123	0.505	71	702	4	5	16	8	0	-1	8	0	0	6.0	
i 1	11.005217687074829	0.2525	77	702	5	9	11	17	0	1	17	0	0	3.0	
i 1	11.264047619047618	0.2525	77	204	7	2	4	17	0	1	17	0	0	4.0	
i 1	11.509231292517006	0.2525	77	702	5	3	8	17	0	1	17	0	0	4.0	
i 1	11.519666666666666	0.2525	75	702	4	24	12	2	0	1	2	0	0	11.0	
i 1	11.743979591836736	0.7575000000000001	77	1088	4	4	4	16	0	2	16	0	0	4.0	
i 1	11.744782312925171	0.505	73	702	2	20	6	17	0	1	17	0	0	0.6335246007848028	
i 1	11.753612244897958	0.2525	71	702	4	5	5	8	0	-1	8	0	0	6.0	
i 1	11.984346938775511	0.2525	76	702	1	20	12	16	0	1	16	0	0	0.6335246007848028	
i 1	11.985149659863946	0.505	61	1088	5	7	13	16	0	1	16	0	0	5.211062169415406	
i 1	11.987557823129253	0.505	61	204	5	14	13	16	0	2	16	0	0	6.513827711769258	
i 1	11.989965986394559	0.2525	72	702	4	1	10	2	0	1	2	0	0	10.0	
i 1	11.990768707482994	0.2525	73	702	2	24	4	16	0	2	16	0	0	4.633524600784803	
i 1	11.994782312925171	0.2525	76	702	2	20	6	17	0	1	17	0	0	0.6335246007848028	
i 1	12.000401360544217	0.505	77	204	7	2	8	17	0	1	17	0	0	4.0	
i 1	12.001204081632652	0.505	73	702	3	20	11	16	0	2	16	0	0	0.6335246007848028	
i 1	12.012442176870747	0.505	63	702	4	18	3	16	0	1	16	0	0	0.5009235345346933	
i 1	12.012442176870747	0.505	74	204	7	5	12	8	0	-2	8	0	0	6.0	
i 1	12.014047619047618	0.505	72	204	4	1	4	2	0	-2	2	0	0	10.0	
i 1	12.231938775510205	0.2525	73	1088	2	20	14	16	0	1	16	0	0	0.6335246007848028	
i 1	12.2431768707483	0.2525	77	702	5	3	16	17	0	1	17	0	0	4.0	
i 1	12.250401360544217	0.2525	75	702	4	24	5	2	0	1	2	0	0	11.0	
i 1	12.251204081632652	0.2525	72	1088	4	24	3	8	0	1	8	0	0	11.0	
i 1	12.263244897959183	0.2525	71	1088	6	5	4	8	0	-1	8	0	0	6.0	
i 1	12.48113605442177	0.505	74	1088	5	9	6	16	0	1	16	0	0	3.0	
i 1	12.48274149659864	5.555	63	702	6	17	16	16	0	2	16	0	0	0.5009235345346933	
i 1	12.484346938775511	0.505	76	386	3	24	12	16	0	2	16	0	0	4.633524600784803	
i 1	12.489163265306123	1.01	74	702	6	2	11	17	0	2	17	0	0	4.0	
i 1	12.490768707482994	2.525	61	702	6	17	13	16	0	2	16	0	0	0.5009235345346933	
i 1	12.493979591836736	12.625	63	1088	4	18	15	1	0	2	1	0	0	0.5009235345346933	
i 1	12.497190476190477	7.07	63	386	6	17	16	1	0	2	1	0	0	0.5009235345346933	
i 1	12.497993197278912	12.625	61	702	5	14	1	16	0	1	16	0	0	6.513827711769258	
i 1	12.499598639455783	1.2625	76	386	2	20	8	17	0	1	17	0	0	0.6335246007848028	
i 1	12.502809523809523	2.525	61	702	5	14	10	1	0	2	1	0	0	6.513827711769258	
i 1	12.504414965986394	0.2525	74	386	6	5	13	8	0	-1	8	0	0	6.0	
i 1	12.505217687074829	5.555	63	386	5	13	11	1	0	2	1	0	0	2.605531084707703	
i 1	12.509231292517006	0.2525	74	702	6	5	7	8	0	-1	8	0	0	6.0	
i 1	12.510034013605441	7.07	61	386	6	7	4	1	0	2	1	0	0	5.211062169415406	
i 1	12.513244897959183	1.7675	72	386	4	24	13	8	0	1	8	0	0	11.0	
i 1	12.51886394557823	7.07	61	386	6	17	13	16	0	2	16	0	0	0.5009235345346933	
i 1	12.733544217687076	0.505	72	1088	3	1	2	2	0	-2	2	0	0	10.0	
i 1	12.736755102040817	0.2525	75	386	6	1	8	2	0	1	2	0	0	10.0	
i 1	12.746387755102042	1.7675	74	386	6	5	3	8	0	-1	8	0	0	6.0	
i 1	12.748795918367348	0.2525	74	386	5	3	8	17	0	1	17	0	0	4.0	
i 1	12.760836734693877	0.2525	74	386	4	5	4	2	0	-1	2	0	0	6.0	
i 1	12.98113605442177	0.505	75	386	4	24	15	2	0	1	2	0	0	11.0	
i 1	12.985952380952382	0.2525	74	386	4	4	14	16	0	1	16	0	0	4.0	
i 1	13.004414965986394	1.5150000000000001	76	386	1	24	6	16	0	2	16	0	0	4.633524600784803	
i 1	13.005217687074829	0.7575000000000001	74	702	6	5	14	8	0	-1	8	0	0	6.0	
i 1	13.009231292517006	0.505	71	386	4	5	9	8	0	-2	8	0	0	6.0	
i 1	13.018061224489795	2.02	77	702	6	2	12	17	0	1	17	0	0	4.0	
i 1	13.48113605442177	0.2525	77	386	5	3	6	16	0	2	16	0	0	4.0	
i 1	13.485952380952382	0.2525	71	702	6	5	1	8	0	-1	8	0	0	6.0	
i 1	13.499598639455783	0.2525	74	1088	5	9	12	16	0	1	16	0	0	3.0	
i 1	13.500401360544217	0.2525	76	1088	2	20	7	17	0	2	17	0	0	0.6335246007848028	
i 1	13.519666666666666	0.2525	75	702	6	1	3	2	0	-2	2	0	0	10.0	
i 1	13.747190476190477	0.505	74	1088	5	9	5	17	0	1	17	0	0	3.0	
i 1	13.753612244897958	0.2525	74	386	4	5	13	2	0	-1	2	0	0	6.0	
i 1	13.765653061224489	0.7575000000000001	75	386	6	1	14	2	0	1	2	0	0	10.0	
i 1	13.768061224489795	0.505	73	702	3	20	8	16	0	2	16	0	0	0.6335246007848028	
i 1	13.769666666666666	0.2525	72	1088	3	1	5	2	0	-2	2	0	0	10.0	
i 1	13.769666666666666	1.5150000000000001	76	1088	2	24	10	17	0	2	17	0	0	4.633524600784803	
i 1	13.981938775510205	0.2525	73	702	3	20	5	16	0	2	16	0	0	0.6335246007848028	
i 1	13.98274149659864	0.7575000000000001	71	702	6	5	6	8	0	-1	8	0	0	6.0	
i 1	13.989965986394559	1.5150000000000001	72	702	4	1	13	8	0	-2	8	0	0	10.0	
i 1	14.23113605442177	0.2525	74	386	4	4	7	16	0	1	16	0	0	4.0	
i 1	14.251204081632652	0.7575000000000001	76	1088	2	20	6	16	0	2	16	0	0	0.6335246007848028	
i 1	14.252006802721088	0.2525	73	1088	2	20	9	16	0	2	16	0	0	0.6335246007848028	
i 1	14.262442176870747	0.2525	71	1088	4	5	3	2	0	-1	2	0	0	6.0	
i 1	14.481938775510205	0.505	71	386	4	5	13	8	0	-2	8	0	0	6.0	
i 1	14.487557823129253	0.7575000000000001	77	386	5	3	7	16	0	2	16	0	0	4.0	
i 1	14.489163265306123	1.01	74	702	6	5	5	8	0	-1	8	0	0	6.0	
i 1	14.50842857142857	0.2525	73	386	3	20	9	16	0	2	16	0	0	0.6335246007848028	
i 1	14.510836734693877	0.2525	72	386	4	24	15	8	0	1	8	0	0	11.0	
i 1	14.739163265306123	0.2525	71	1088	4	5	4	2	0	-2	2	0	0	6.0	
i 1	14.739965986394559	0.7575000000000001	76	386	2	20	12	17	0	1	17	0	0	0.6335246007848028	
i 1	14.739965986394559	3.2825	76	386	1	24	10	16	0	2	16	0	0	4.633524600784803	
i 1	14.747190476190477	0.2525	72	1088	3	1	16	2	0	-2	2	0	0	10.0	
i 1	14.76886394557823	0.2525	75	702	6	1	12	2	0	-2	2	0	0	10.0	
i 1	14.980333333333334	2.02	75	702	4	1	14	2	0	-2	2	0	0	10.0	
i 1	14.993979591836736	9.09	61	702	6	17	8	16	0	2	16	0	0	0.5009235345346933	
i 1	14.993979591836736	10.1	61	702	5	14	14	1	0	2	1	0	0	6.513827711769258	
i 1	14.997190476190477	1.7675	74	386	4	4	6	16	0	1	16	0	0	4.0	
i 1	15.0068231292517	0.2525	71	1088	6	5	15	2	0	-2	2	0	0	6.0	
i 1	15.018061224489795	10.1	63	1088	4	18	5	1	0	2	1	0	0	0.5009235345346933	
i 1	15.23274149659864	0.2525	75	386	6	1	3	2	0	1	2	0	0	10.0	
i 1	15.248795918367348	0.2525	74	386	4	4	12	16	0	1	16	0	0	4.0	
i 1	15.252809523809523	0.7575000000000001	73	386	3	20	9	16	0	2	16	0	0	0.6335246007848028	
i 1	15.48113605442177	0.2525	76	386	3	20	8	17	0	1	17	0	0	0.6335246007848028	
i 1	15.492374149659865	0.2525	72	1088	6	1	9	2	0	-2	2	0	0	10.0	
i 1	15.506020408163264	1.7675	74	386	6	5	1	8	0	-1	8	0	0	6.0	
i 1	15.510034013605441	0.2525	74	1088	5	9	7	16	0	1	16	0	0	3.0	
i 1	15.512442176870747	0.2525	76	702	3	20	14	17	0	1	17	0	0	0.6335246007848028	
i 1	15.514850340136054	0.2525	75	386	4	24	14	2	0	1	2	0	0	11.0	
i 1	15.515653061224489	0.505	76	1088	2	24	14	17	0	2	17	0	0	4.633524600784803	
i 1	15.731938775510205	0.2525	73	1088	2	20	12	17	0	2	17	0	0	0.6335246007848028	
i 1	15.737557823129253	0.2525	76	386	2	20	16	17	0	1	17	0	0	0.6335246007848028	
i 1	15.761639455782312	0.2525	73	1088	2	20	5	16	0	2	16	0	0	0.6335246007848028	
i 1	16.001204081632654	0.2525	77	702	6	2	6	17	0	1	17	0	0	4.0	
i 1	16.24638775510204	1.7675	76	386	2	20	16	17	0	1	17	0	0	0.6335246007848028	
i 1	16.250401360544217	0.2525	73	1088	2	20	15	17	0	1	17	0	0	0.6335246007848028	
i 1	16.256020408163266	2.525	74	702	6	2	12	17	0	2	17	0	0	4.0	
i 1	16.257625850340137	1.2625	72	386	4	24	14	8	0	1	8	0	0	11.0	
i 1	16.257625850340137	0.7575000000000001	77	386	5	3	1	16	0	2	16	0	0	4.0	
i 1	16.266455782312924	0.2525	75	1088	3	1	13	2	0	-2	2	0	0	10.0	
i 1	16.50361224489796	0.2525	74	386	4	5	8	2	0	-1	2	0	0	6.0	
i 1	16.75361224489796	0.2525	76	1088	2	24	10	17	0	2	17	0	0	4.633524600784803	
i 1	16.754414965986395	0.2525	74	1088	5	9	8	17	0	1	17	0	0	3.0	
i 1	16.759231292517008	2.02	74	386	6	5	12	8	0	-1	8	0	0	6.0	
i 1	16.764850340136054	0.2525	75	386	4	24	2	2	0	1	2	0	0	11.0	
i 1	16.981938775510205	0.2525	74	386	4	5	11	2	0	-1	2	0	0	6.0	
i 1	16.993979591836734	0.2525	74	1088	5	9	2	16	0	1	16	0	0	3.0	
i 1	16.997993197278912	1.01	75	386	6	1	7	2	0	1	2	0	0	10.0	
i 1	17.23916326530612	0.2525	71	386	4	5	6	8	0	-2	8	0	0	6.0	
i 1	17.240768707482992	0.2525	74	702	6	5	15	8	0	-1	8	0	0	6.0	
i 1	17.481938775510205	0.505	76	1088	2	20	11	16	0	1	16	0	0	0.6335246007848028	
i 1	17.483544217687076	0.2525	72	386	4	1	8	2	0	1	2	0	0	10.0	
i 1	17.511639455782312	0.2525	75	1088	3	1	5	2	0	-2	2	0	0	10.0	
i 1	17.51725850340136	0.505	76	1088	2	24	4	17	0	2	17	0	0	4.633524600784803	
i 1	17.7431768707483	0.2525	73	386	1	20	11	16	0	2	16	0	0	0.6335246007848028	
i 1	17.75842857142857	0.2525	75	702	4	1	15	2	0	-2	2	0	0	10.0	
i 1	17.981136054421768	0.2525	73	702	3	20	15	16	0	1	16	0	0	0.03877098875326901	
i 1	17.98996598639456	1.5150000000000001	63	386	5	13	11	1	0	2	1	0	0	2.605531084707703	
i 1	17.990768707482992	1.01	73	386	1	20	1	16	0	2	16	0	0	0.03877098875326901	
i 1	17.992374149659863	1.7675	72	702	4	1	3	8	0	-2	8	0	0	10.0	
i 1	17.9931768707483	7.07	63	702	6	17	2	16	0	2	16	0	0	0.5009235345346933	
i 1	17.99478231292517	0.505	76	386	3	20	8	17	0	1	17	0	0	0.03877098875326901	
i 1	18.001204081632654	0.505	75	386	4	1	5	2	0	1	2	0	0	10.0	
i 1	18.002809523809525	0.2525	76	1088	2	24	9	17	0	2	17	0	0	4.038770988753269	
i 1	18.01244217687075	7.07	61	386	4	19	16	16	0	1	16	0	0	0.5009235345346933	
i 1	18.013244897959183	1.7675	77	702	6	2	1	17	0	1	17	0	0	4.0	
i 1	18.230333333333334	0.2525	71	386	4	5	2	8	0	-2	8	0	0	6.0	
i 1	18.23755782312925	1.5150000000000001	74	702	6	5	2	8	0	-1	8	0	0	6.0	
i 1	18.243979591836734	1.01	76	1088	1	24	3	17	0	252	17	307	0	4.038770988753269	
i 1	18.48595238095238	0.7575000000000001	73	1088	2	20	5	17	0	2	17	0	0	0.03877098875326901	
i 1	18.49478231292517	0.7575000000000001	75	702	4	1	7	2	0	-2	2	0	0	10.0	
i 1	18.504414965986395	1.01	73	386	1	24	6	17	0	252	17	307	0	4.038770988753269	
i 1	18.5068231292517	1.01	76	1088	2	20	7	16	0	1	16	0	0	0.03877098875326901	
i 1	18.51083673469388	0.2525	76	386	2	20	12	17	0	1	17	0	0	0.03877098875326901	
i 1	18.51404761904762	0.2525	72	386	3	1	10	2	0	1	2	0	0	10.0	
i 1	18.51404761904762	0.505	71	702	4	5	16	8	0	-1	8	0	0	6.0	
i 1	18.73916326530612	0.7575000000000001	74	386	4	4	6	16	0	1	16	0	0	4.0	
i 1	18.754414965986395	0.2525	77	386	5	3	12	16	0	2	16	0	0	4.0	
i 1	18.7568231292517	0.2525	72	1088	6	1	16	2	0	-2	2	0	0	10.0	
i 1	18.990768707482992	0.2525	74	386	6	5	5	8	0	-1	8	0	0	6.0	
i 1	19.007625850340137	0.7575000000000001	76	386	2	24	10	16	0	2	16	0	0	4.038770988753269	
i 1	19.231938775510205	0.2525	73	702	3	20	1	17	0	1	17	0	0	0.03877098875326901	
i 1	19.238360544217688	0.2525	73	702	3	20	3	17	0	2	17	0	0	0.03877098875326901	
i 1	19.250401360544217	0.2525	77	386	5	3	14	16	0	2	16	0	0	4.0	
i 1	19.2568231292517	0.2525	74	386	6	5	1	8	0	-1	8	0	0	6.0	
i 1	19.26083673469388	2.02	76	1088	2	24	4	17	0	2	17	0	0	4.038770988753269	
i 1	19.269666666666666	0.2525	72	386	4	24	1	8	0	1	8	0	0	11.0	
i 1	19.48274149659864	11.11	61	702	5	13	4	16	0	2	16	0	0	2.605531084707703	
i 1	19.483544217687076	0.505	74	386	4	4	12	16	0	1	16	0	0	4.0	
i 1	19.486755102040817	1.5150000000000001	63	702	6	7	12	16	0	2	16	0	0	5.211062169415406	
i 1	19.48755782312925	1.2625	77	702	5	3	5	17	0	1	17	0	0	4.0	
i 1	19.49157142857143	0.2525	76	1088	2	20	2	16	0	2	16	0	0	0.03877098875326901	
i 1	19.493979591836734	4.545	61	702	6	17	8	16	0	2	16	0	0	0.5009235345346933	
i 1	19.502006802721088	1.5150000000000001	71	702	4	5	1	8	0	-1	8	0	0	6.0	
i 1	19.502006802721088	0.2525	76	1088	2	20	14	17	0	1	17	0	0	0.03877098875326901	
i 1	19.509231292517008	0.2525	73	386	2	24	12	17	0	1	17	0	0	4.038770988753269	
i 1	19.513244897959183	0.505	71	702	6	5	13	8	0	-2	8	0	0	6.0	
i 1	19.51404761904762	1.5150000000000001	61	702	6	17	8	1	0	1	1	0	0	0.5009235345346933	
i 1	19.514850340136054	1.2625	75	702	4	1	8	2	0	1	2	0	0	10.0	
i 1	19.519666666666666	0.7575000000000001	75	702	4	24	13	8	0	-2	8	0	0	11.0	
i 1	19.733544217687076	0.2525	74	386	4	5	6	2	0	-1	2	0	0	6.0	
i 1	19.743979591836734	0.2525	76	702	3	24	9	17	0	2	17	0	0	4.038770988753269	
i 1	19.745585034013605	0.2525	77	702	4	4	1	16	0	2	16	0	0	4.0	
i 1	19.747190476190475	0.7575000000000001	76	1088	2	20	12	16	0	1	16	0	0	0.03877098875326901	
i 1	19.76565306122449	0.2525	75	1088	6	1	2	2	0	-2	2	0	0	10.0	
i 1	19.995585034013605	0.7575000000000001	76	386	2	24	4	16	0	2	16	0	0	4.038770988753269	
i 1	19.99638775510204	1.01	74	702	6	5	10	8	0	-1	8	0	0	6.0	
i 1	20.000401360544217	0.2525	74	702	6	2	12	17	0	2	17	0	0	4.0	
i 1	20.004414965986395	0.2525	77	702	6	2	15	17	0	1	17	0	0	4.0	
i 1	20.248795918367346	0.2525	71	1088	6	5	11	2	0	-1	2	0	0	6.0	
i 1	20.252006802721088	2.02	72	702	4	1	12	8	0	-2	8	0	0	10.0	
i 1	20.26565306122449	0.2525	73	702	3	20	16	16	0	1	16	0	0	0.03877098875326901	
i 1	20.481938775510205	0.7575000000000001	76	1088	2	20	11	16	0	2	16	0	0	0.03877098875326901	
i 1	20.486755102040817	0.2525	74	702	6	5	9	8	0	-2	8	0	0	6.0	
i 1	20.497993197278912	0.2525	75	386	4	24	13	2	0	1	2	0	0	11.0	
i 1	20.50361224489796	1.7675	74	702	6	2	16	17	0	2	17	0	0	4.0	
i 1	20.731136054421768	0.2525	72	1088	6	1	11	2	0	-2	2	0	0	10.0	
i 1	20.745585034013605	0.2525	75	702	4	1	16	2	0	-2	2	0	0	10.0	
i 1	20.764850340136054	0.2525	74	386	4	5	15	2	0	-1	2	0	0	6.0	
i 1	20.981136054421768	0.505	71	702	6	5	13	8	0	-2	8	0	0	6.0	
i 1	20.98274149659864	1.7675	74	702	4	5	13	8	0	-1	8	0	0	6.0	
i 1	20.986755102040817	9.595	63	702	5	7	9	16	0	2	16	0	0	5.211062169415406	
i 1	20.99157142857143	4.04	61	386	4	19	1	1	0	1	1	0	0	0.5009235345346933	
i 1	20.999598639455783	0.2525	75	702	4	1	1	2	0	1	2	0	0	10.0	
i 1	21.0068231292517	0.7575000000000001	76	1088	2	20	15	16	0	1	16	0	0	0.03877098875326901	
i 1	21.00842857142857	0.505	74	386	4	4	12	16	0	1	16	0	0	4.0	
i 1	21.009231292517008	0.7575000000000001	76	1088	2	20	4	16	0	1	16	0	0	0.03877098875326901	
i 1	21.01565306122449	9.09	61	702	6	17	15	1	0	1	1	0	0	0.5009235345346933	
i 1	21.2431768707483	0.2525	76	386	2	24	10	16	0	2	16	0	0	4.038770988753269	
i 1	21.483544217687076	0.2525	75	702	4	24	15	8	0	-2	8	0	0	11.0	
i 1	21.486755102040817	2.2725	77	702	6	2	13	17	0	1	17	0	0	4.0	
i 1	21.48916326530612	0.2525	74	386	6	5	6	2	0	-1	2	0	0	6.0	
i 1	21.492374149659863	0.2525	71	386	4	5	15	8	0	-2	8	0	0	6.0	
i 1	21.497190476190475	1.7675	73	386	2	20	4	16	0	2	16	0	0	0.03877098875326901	
i 1	21.51083673469388	1.7675	73	386	2	24	4	17	0	1	17	0	0	4.038770988753269	
i 1	21.519666666666666	0.2525	74	1088	5	9	10	16	0	1	16	0	0	3.0	
i 1	21.747993197278912	0.505	72	1088	6	1	9	2	0	-2	2	0	0	10.0	
i 1	21.754414965986395	0.2525	72	386	6	1	13	2	0	1	2	0	0	10.0	
i 1	21.764850340136054	2.2725	74	702	6	5	14	8	0	-2	8	0	0	6.0	
i 1	21.986755102040817	0.2525	76	1088	2	20	14	16	0	1	16	0	0	0.03877098875326901	
i 1	22.00521768707483	0.7575000000000001	75	702	4	1	9	2	0	-2	2	0	0	10.0	
i 1	22.2431768707483	0.2525	72	386	6	1	13	2	0	1	2	0	0	10.0	
i 1	22.247190476190475	0.2525	74	386	6	5	7	2	0	-1	2	0	0	6.0	
i 1	22.25361224489796	0.2525	75	702	4	24	16	8	0	-2	8	0	0	11.0	
i 1	22.263244897959183	0.2525	76	1088	2	20	14	16	0	2	16	0	0	0.03877098875326901	
i 1	22.268061224489795	0.505	74	1088	5	9	6	17	0	1	17	0	0	3.0	
i 1	22.481938775510205	1.5150000000000001	72	702	4	1	9	8	0	-2	8	0	0	10.0	
i 1	22.502006802721088	0.2525	76	1088	2	20	8	16	0	1	16	0	0	0.03877098875326901	
i 1	22.506020408163266	0.505	71	386	4	5	16	8	0	-2	8	0	0	6.0	
i 1	22.51003401360544	0.2525	74	386	5	3	11	17	0	1	17	0	0	4.0	
i 1	22.73274149659864	0.2525	77	702	5	3	10	17	0	1	17	0	0	4.0	
i 1	22.735149659863946	0.2525	71	702	6	5	1	8	0	-1	8	0	0	6.0	
i 1	22.73996598639456	0.2525	75	702	4	1	16	2	0	1	2	0	0	10.0	
i 1	22.740768707482992	0.2525	77	702	4	4	1	16	0	2	16	0	0	4.0	
i 1	22.749598639455783	1.01	76	1088	2	24	12	17	0	2	17	0	0	4.038770988753269	
i 1	22.764850340136054	0.2525	75	702	4	24	16	8	0	-2	8	0	0	11.0	
i 1	22.769666666666666	0.7575000000000001	76	1088	2	20	11	16	0	2	16	0	0	0.03877098875326901	
i 1	22.985149659863946	0.2525	72	386	6	1	9	2	0	1	2	0	0	10.0	
i 1	22.98595238095238	0.505	72	1088	6	1	12	2	0	-2	2	0	0	10.0	
i 1	22.986755102040817	0.505	74	702	4	5	5	8	0	-1	8	0	0	6.0	
i 1	23.230333333333334	2.02	75	702	4	1	7	2	0	1	2	0	0	10.0	
i 1	23.23595238095238	0.7575000000000001	77	702	4	4	7	16	0	2	16	0	0	4.0	
i 1	23.240768707482992	0.2525	76	1088	2	20	6	16	0	1	16	0	0	0.03877098875326901	
i 1	23.24638775510204	0.2525	74	702	6	2	13	17	0	2	17	0	0	4.0	
i 1	23.259231292517008	0.2525	71	1088	6	5	16	2	0	-2	2	0	0	6.0	
i 1	23.259231292517008	1.2625	76	386	2	24	12	16	0	2	16	0	0	4.038770988753269	
i 1	23.480333333333334	0.505	71	702	6	5	15	8	0	-2	8	0	0	6.0	
i 1	23.485149659863946	0.505	73	702	3	20	3	17	0	2	17	0	0	0.03877098875326901	
i 1	23.488360544217688	0.2525	76	702	3	20	6	17	0	1	17	0	0	0.03877098875326901	
i 1	23.493979591836734	1.7675	77	702	5	3	6	17	0	1	17	0	0	4.0	
i 1	23.738360544217688	0.505	76	1088	2	20	1	16	0	1	16	0	0	0.03877098875326901	
i 1	23.748795918367346	1.2625	71	702	6	5	9	8	0	-1	8	0	0	6.0	
i 1	23.768061224489795	0.2525	72	1088	6	1	6	2	0	-2	2	0	0	10.0	
i 1	23.769666666666666	0.2525	74	702	6	2	10	17	0	2	17	0	0	4.0	
i 1	23.981136054421768	0.505	71	702	4	5	14	8	0	-2	8	0	0	6.0	
i 1	23.98434693877551	0.2525	75	702	4	24	9	8	0	-2	8	0	0	11.0	
i 1	23.99638775510204	6.565	61	702	6	17	15	16	0	2	16	0	0	0.5009235345346933	
i 1	24.0068231292517	0.2525	74	386	6	5	3	2	0	-1	2	0	0	6.0	
i 1	24.0068231292517	0.2525	73	1088	2	20	2	16	0	1	16	0	0	0.03877098875326901	
i 1	24.00842857142857	0.505	74	386	4	4	6	16	0	1	16	0	0	4.0	
i 1	24.011639455782312	1.01	61	702	6	17	8	16	0	2	16	0	0	0.5009235345346933	
i 1	24.01565306122449	0.2525	74	1088	5	9	16	16	0	1	16	0	0	3.0	
i 1	24.019666666666666	0.505	72	1088	3	1	10	2	0	-2	2	0	0	10.0	
i 1	24.23274149659864	0.2525	73	702	3	20	12	17	0	1	17	0	0	0.03877098875326901	
i 1	24.2431768707483	0.2525	73	702	3	20	16	17	0	2	17	0	0	0.03877098875326901	
i 1	24.25842857142857	0.2525	77	702	6	2	6	17	0	1	17	0	0	4.0	
i 1	24.48434693877551	0.505	76	1088	2	24	9	17	0	2	17	0	0	4.038770988753269	
i 1	24.50521768707483	0.505	77	702	4	4	15	16	0	2	16	0	0	4.0	
i 1	24.514850340136054	0.2525	71	386	6	5	8	8	0	-2	8	0	0	6.0	
i 1	24.518863945578232	0.505	73	1088	2	20	9	17	0	2	17	0	0	0.03877098875326901	
i 1	24.730333333333334	0.2525	75	702	4	1	9	2	0	-2	2	0	0	10.0	
i 1	24.7431768707483	0.2525	72	1088	3	1	4	2	0	-2	2	0	0	10.0	
i 1	24.74638775510204	0.7575000000000001	74	702	6	5	8	8	0	-2	8	0	0	6.0	
i 1	24.75521768707483	0.2525	77	702	6	2	4	17	0	1	17	0	0	4.0	
i 1	24.98274149659864	1.01	77	204	6	9	5	17	0	2	17	0	0	3.0	
i 1	24.983544217687076	0.7575000000000001	72	906	4	1	8	2	0	-2	2	0	0	10.0	
i 1	24.983544217687076	1.7675	73	204	2	24	14	17	0	1	17	0	0	4.038770988753269	
i 1	24.98434693877551	8.08	61	204	5	19	11	16	0	2	16	0	0	0.5009235345346933	
i 1	24.992374149659863	1.7675	73	204	3	20	8	16	0	2	16	0	0	0.03877098875326901	
i 1	24.993979591836734	2.02	63	906	6	17	16	1	0	1	1	0	0	0.5009235345346933	
i 1	25.002006802721088	11.11	61	204	5	19	7	1	0	2	1	0	0	0.5009235345346933	
i 1	25.002809523809525	5.05	63	204	5	18	4	16	0	2	16	0	0	0.5009235345346933	
i 1	25.00521768707483	1.7675	77	906	6	2	11	16	0	2	16	0	0	4.0	
i 1	25.006020408163266	1.2625	75	702	4	24	8	8	0	-2	8	0	0	11.0	
i 1	25.006020408163266	11.11	61	906	6	17	3	1	0	1	1	0	0	0.5009235345346933	
i 1	25.0068231292517	12.625	61	906	5	14	8	16	0	2	16	0	0	6.513827711769258	
i 1	25.00842857142857	1.5150000000000001	71	702	4	5	5	8	0	-2	8	0	0	6.0	
i 1	25.01003401360544	0.505	73	204	3	20	12	17	0	2	17	0	0	0.03877098875326901	
i 1	25.011639455782312	2.02	61	204	5	18	2	1	0	2	1	0	0	0.5009235345346933	
i 1	25.01404761904762	0.2525	71	906	6	5	13	8	0	-1	8	0	0	6.0	
i 1	25.01565306122449	0.2525	73	204	3	24	9	17	0	1	17	0	0	4.038770988753269	
i 1	25.016455782312924	12.625	63	906	5	14	1	1	0	1	1	0	0	6.513827711769258	
i 1	25.23274149659864	0.2525	74	204	7	5	1	8	0	-2	8	0	0	6.0	
i 1	25.51404761904762	0.2525	76	204	3	20	13	16	0	1	16	0	0	0.03877098875326901	
i 1	25.518863945578232	0.2525	75	204	7	1	9	2	0	-2	2	0	0	10.0	
i 1	25.730333333333334	0.2525	74	204	5	4	9	17	0	2	17	0	0	4.0	
i 1	25.73434693877551	2.02	75	702	4	1	12	2	0	1	2	0	0	10.0	
i 1	25.747190476190475	0.2525	72	906	4	1	13	2	0	1	2	0	0	10.0	
i 1	25.759231292517008	0.2525	73	204	2	24	3	17	0	2	17	0	0	4.038770988753269	
i 1	25.985149659863946	0.2525	73	204	3	20	16	17	0	2	17	0	0	0.03877098875326901	
i 1	25.999598639455783	2.02	77	702	4	4	11	16	0	2	16	0	0	4.0	
i 1	26.01083673469388	0.2525	71	204	7	5	14	2	0	-1	2	0	0	6.0	
i 1	26.01404761904762	0.2525	74	702	6	5	6	8	0	-2	8	0	0	6.0	
i 1	26.240768707482992	1.7675	71	906	6	5	7	8	0	-1	8	0	0	6.0	
i 1	26.252809523809525	0.7575000000000001	73	204	2	20	2	17	0	2	17	0	0	0.03877098875326901	
i 1	26.259231292517008	0.7575000000000001	72	906	4	1	3	2	0	-2	2	0	0	10.0	
i 1	26.26083673469388	0.2525	74	204	6	9	7	17	0	1	17	0	0	3.0	
i 1	26.269666666666666	0.7575000000000001	76	204	2	20	5	17	0	1	17	0	0	0.03877098875326901	
i 1	26.488360544217688	0.505	74	702	6	5	15	8	0	-2	8	0	0	6.0	
i 1	26.501204081632654	0.505	74	204	5	4	3	17	0	2	17	0	0	4.0	
i 1	26.509231292517008	0.2525	71	204	7	5	10	2	0	-1	2	0	0	6.0	
i 1	26.731136054421768	0.2525	71	204	7	5	5	8	0	-1	8	0	0	6.0	
i 1	26.73274149659864	0.2525	73	204	2	24	10	17	0	2	17	0	0	4.038770988753269	
i 1	26.768061224489795	0.2525	74	204	6	9	3	17	0	1	17	0	0	3.0	
i 1	26.995585034013605	0.2525	72	204	7	1	11	2	0	1	2	0	0	10.0	
i 1	27.004414965986395	9.09	61	204	5	18	12	1	0	2	1	0	0	0.5009235345346933	
i 1	27.006020408163266	0.2525	77	906	6	2	6	16	0	2	16	0	0	4.0	
i 1	27.011639455782312	0.2525	75	702	4	24	2	8	0	-2	8	0	0	11.0	
i 1	27.019666666666666	10.605	63	906	6	17	16	1	0	1	1	0	0	0.5009235345346933	
i 1	27.23755782312925	2.02	77	702	5	3	6	17	0	1	17	0	0	4.0	
i 1	27.249598639455783	0.2525	74	204	5	4	7	17	0	2	17	0	0	4.0	
i 1	27.266455782312924	1.2625	72	906	4	1	1	2	0	1	2	0	0	10.0	
i 1	27.48755782312925	0.2525	71	204	7	5	2	2	0	-1	2	0	0	6.0	
i 1	27.497190476190475	0.2525	72	204	4	1	6	2	0	-2	2	0	0	10.0	
i 1	27.50842857142857	2.02	74	906	6	5	11	2	0	-1	2	0	0	6.0	
i 1	27.514850340136054	0.2525	73	204	3	24	9	17	0	1	17	0	0	4.0	
i 1	27.751204081632654	1.7675	72	906	4	1	2	2	0	-2	2	0	0	10.0	
i 1	27.75521768707483	0.2525	74	204	6	9	8	17	0	1	17	0	0	3.0	
i 1	27.76244217687075	0.2525	75	204	4	1	13	2	0	-2	2	0	0	10.0	
i 1	27.766455782312924	0.505	74	204	7	5	11	8	0	-2	8	0	0	6.0	
i 1	27.98595238095238	0.2525	74	906	6	2	14	16	0	2	16	0	0	4.0	
i 1	28.002809523809525	0.505	71	204	7	5	10	2	0	-1	2	0	0	6.0	
i 1	28.250401360544217	0.2525	71	204	7	5	5	8	0	-2	8	0	0	6.0	
i 1	28.264850340136054	0.505	73	204	1	24	11	17	0	252	17	307	0	4.0	
i 1	28.481136054421768	0.505	71	906	6	5	15	8	0	-1	8	0	0	6.0	
i 1	28.48595238095238	0.505	72	204	5	24	5	8	0	-2	8	0	0	11.0	
i 1	28.497190476190475	3.2825	73	204	2	24	5	17	0	1	17	0	0	4.0	
i 1	28.50842857142857	0.2525	74	204	7	5	13	8	0	-2	8	0	0	6.0	
i 1	28.73434693877551	0.2525	74	204	6	9	16	17	0	1	17	0	0	3.0	
i 1	28.748795918367346	2.02	74	906	6	2	6	16	0	2	16	0	0	4.0	
i 1	28.750401360544217	0.7575000000000001	73	204	3	24	14	17	0	1	17	0	0	4.0	
i 1	28.98434693877551	0.505	77	906	6	2	11	16	0	2	16	0	0	4.0	
i 1	28.98755782312925	0.7575000000000001	74	702	4	5	13	8	0	-2	8	0	0	6.0	
i 1	29.00842857142857	0.2525	71	204	7	5	15	8	0	-1	8	0	0	6.0	
i 1	29.01244217687075	1.01	72	906	4	1	16	2	0	1	2	0	0	10.0	
i 1	29.230333333333334	0.2525	74	204	5	4	10	17	0	2	17	0	0	4.0	
i 1	29.264850340136054	1.2625	71	702	6	5	5	8	0	-2	8	0	0	6.0	
i 1	29.48595238095238	0.505	75	702	4	24	11	8	0	-2	8	0	0	11.0	
i 1	29.48755782312925	0.2525	74	204	6	9	7	17	0	1	17	0	0	3.0	
i 1	29.490768707482992	0.2525	71	204	7	5	7	8	0	-1	8	0	0	6.0	
i 1	29.504414965986395	0.2525	75	702	4	1	9	2	0	1	2	0	0	10.0	
i 1	29.519666666666666	0.2525	77	702	4	4	6	16	0	2	16	0	0	4.0	
i 1	29.756020408163266	0.2525	71	906	6	5	2	8	0	-1	8	0	0	6.0	
i 1	29.757625850340137	0.505	72	204	4	1	14	2	0	-2	2	0	0	10.0	
i 1	29.76083673469388	0.2525	74	204	7	5	4	8	0	-2	8	0	0	6.0	
i 1	29.76725850340136	0.505	74	204	5	4	1	17	0	2	17	0	0	4.0	
i 1	29.981136054421768	0.505	61	702	6	17	16	1	0	1	1	0	0	0.5009235345346933	
i 1	29.98996598639456	1.01	72	906	5	1	13	2	0	1	2	0	0	10.0	
i 1	29.997190476190475	1.01	74	906	6	5	5	2	0	-1	2	0	0	6.0	
i 1	30.0068231292517	0.2525	72	204	3	1	10	2	0	1	2	0	0	10.0	
i 1	30.013244897959183	9.09	63	204	5	18	1	16	0	2	16	0	0	0.5009235345346933	
i 1	30.245585034013605	0.505	72	204	5	24	15	8	0	-2	8	0	0	11.0	
i 1	30.252006802721088	0.2525	71	204	7	5	15	8	0	-1	8	0	0	6.0	
i 1	30.26083673469388	0.2525	74	204	6	9	10	17	0	1	17	0	0	3.0	
i 1	30.26244217687075	0.2525	75	204	4	1	15	2	0	-2	2	0	0	10.0	
i 1	30.26404761904762	0.2525	77	702	4	4	5	16	0	2	16	0	0	4.0	
i 1	30.483544217687076	1.2625	72	906	4	1	1	2	0	-2	2	0	0	10.0	
i 1	30.490768707482992	7.07	61	590	5	13	10	16	0	1	16	0	0	2.605531084707703	
i 1	30.497993197278912	7.07	61	590	5	7	8	1	0	1	1	0	0	5.211062169415406	
i 1	30.499598639455783	0.7575000000000001	74	590	6	5	11	8	0	-1	8	0	0	6.0	
i 1	30.501204081632654	7.07	63	590	6	17	6	1	0	1	1	0	0	0.5009235345346933	
i 1	30.502006802721088	0.7575000000000001	74	590	4	4	3	16	0	2	16	0	0	4.0	
i 1	30.502006802721088	1.5150000000000001	74	590	6	5	6	8	0	-2	8	0	0	6.0	
i 1	30.51244217687075	2.2725	77	906	6	2	16	16	0	2	16	0	0	4.0	
i 1	30.518061224489795	2.525	63	590	6	17	14	1	0	2	1	0	0	0.5009235345346933	
i 1	30.730333333333334	0.505	75	204	4	1	12	2	0	-2	2	0	0	10.0	
i 1	30.731136054421768	0.2525	74	204	5	4	5	17	0	2	17	0	0	4.0	
i 1	30.993979591836734	0.505	71	204	7	5	7	8	0	-2	8	0	0	6.0	
i 1	31.006020408163266	0.2525	72	204	4	1	4	2	0	-2	2	0	0	10.0	
i 1	31.00842857142857	0.2525	74	204	6	9	10	17	0	1	17	0	0	3.0	
i 1	31.23916326530612	3.0300000000000002	73	204	3	24	4	17	0	1	17	0	0	4.0	
i 1	31.243979591836734	0.2525	72	906	5	1	2	2	0	1	2	0	0	10.0	
i 1	31.24638775510204	2.02	75	590	4	24	9	2	0	-2	2	0	0	11.0	
i 1	31.254414965986395	0.2525	71	204	7	5	16	2	0	-1	2	0	0	6.0	
i 1	31.26725850340136	3.0300000000000002	76	204	2	24	6	17	0	1	17	0	0	4.0	
i 1	31.269666666666666	0.505	74	906	6	2	16	16	0	2	16	0	0	4.0	
i 1	31.48434693877551	2.02	74	590	6	5	5	8	0	-1	8	0	0	6.0	
i 1	31.485149659863946	0.2525	74	906	6	5	1	2	0	-1	2	0	0	6.0	
i 1	31.49157142857143	0.505	72	590	4	1	12	2	0	-2	2	0	0	10.0	
i 1	31.763244897959183	0.505	72	906	5	1	4	2	0	1	2	0	0	10.0	
i 1	31.981136054421768	0.505	72	204	3	1	4	2	0	1	2	0	0	10.0	
i 1	31.98434693877551	0.2525	74	204	5	4	10	17	0	2	17	0	0	4.0	
i 1	31.988360544217688	2.02	74	906	6	2	15	16	0	2	16	0	0	4.0	
i 1	31.992374149659863	0.2525	74	204	4	5	12	8	0	-2	8	0	0	6.0	
i 1	32.0180612244898	0.2525	71	204	7	5	6	8	0	-1	8	0	0	6.0	
i 1	32.247190476190475	0.7575000000000001	74	590	4	4	14	16	0	2	16	0	0	4.0	
i 1	32.252809523809525	0.2525	75	204	4	1	15	2	0	-2	2	0	0	10.0	
i 1	32.252809523809525	0.505	71	204	7	5	6	8	0	-2	8	0	0	6.0	
i 1	32.26725850340136	0.7575000000000001	71	204	7	5	12	2	0	-1	2	0	0	6.0	
i 1	32.50120408163265	1.7675	72	590	4	1	6	2	0	-2	2	0	0	10.0	
i 1	32.51324489795918	0.2525	72	906	5	1	13	2	0	1	2	0	0	10.0	
i 1	32.74879591836735	0.2525	71	204	7	5	9	8	0	-1	8	0	0	6.0	
i 1	32.75441496598639	1.01	74	590	5	3	14	17	0	1	17	0	0	4.0	
i 1	32.764047619047616	0.2525	72	204	5	24	12	8	0	-2	8	0	0	11.0	
i 1	32.9819387755102	4.545	71	906	6	5	11	8	0	-1	8	0	0	6.0	
i 1	32.98675510204082	0.505	74	204	6	9	10	17	0	1	17	0	0	3.0	
i 1	32.99638775510204	4.545	63	590	6	17	10	1	0	2	1	0	0	0.5009235345346933	
i 1	33.00120408163265	0.2525	74	590	6	5	10	8	0	-2	8	0	0	6.0	
i 1	33.010836734693875	0.505	72	204	3	24	14	8	0	-2	8	0	0	11.0	
i 1	33.019666666666666	4.545	61	204	5	19	2	16	0	2	16	0	0	0.5009235345346933	
i 1	33.23755782312925	1.01	72	906	5	1	10	2	0	-2	2	0	0	10.0	
i 1	33.2680612244898	0.505	71	204	7	5	15	2	0	-1	2	0	0	6.0	
i 1	33.48434693877551	1.5150000000000001	77	906	6	2	4	16	0	2	16	0	0	4.0	
i 1	33.506020408163266	1.7675	72	906	5	1	7	2	0	1	2	0	0	10.0	
i 1	33.508428571428574	0.2525	71	204	7	5	5	8	0	-2	8	0	0	6.0	
i 1	33.73274149659864	0.2525	74	204	7	5	15	8	0	-2	8	0	0	6.0	
i 1	33.747190476190475	0.7575000000000001	74	204	5	4	9	17	0	2	17	0	0	4.0	
i 1	33.7568231292517	0.505	74	590	6	5	1	8	0	-1	8	0	0	6.0	
i 1	33.99237414965987	0.2525	74	590	4	4	12	16	0	2	16	0	0	4.0	
i 1	34.006020408163266	2.02	73	204	2	24	9	17	0	1	17	0	0	4.0	
i 1	34.235952380952384	0.7575000000000001	76	204	1	24	16	17	0	248	17	308	0	4.0	
i 1	34.24638775510204	0.2525	72	204	4	1	16	2	0	-2	2	0	0	10.0	
i 1	34.25441496598639	1.01	74	906	6	5	10	2	0	-1	2	0	0	6.0	
i 1	34.2568231292517	0.2525	74	204	6	3	16	17	0	1	17	0	0	4.0	
i 1	34.26725850340136	0.2525	72	204	3	1	16	2	0	1	2	0	0	10.0	
i 1	34.48434693877551	0.2525	72	204	3	24	6	8	0	-2	8	0	0	11.0	
i 1	34.49638775510204	2.02	74	590	4	4	10	16	0	2	16	0	0	4.0	
i 1	34.51003401360544	2.525	72	906	5	1	6	2	0	-2	2	0	0	10.0	
i 1	34.730333333333334	0.2525	74	590	6	5	5	8	0	-2	8	0	0	6.0	
i 1	34.98113605442177	0.505	74	204	7	5	4	8	0	-2	8	0	0	6.0	
i 1	34.983544217687076	0.7575000000000001	77	204	6	9	5	17	0	2	17	0	0	3.0	
i 1	34.99959863945578	0.2525	76	204	2	24	13	17	0	1	17	0	0	4.0	
i 1	35.006020408163266	0.2525	72	204	3	1	14	2	0	1	2	0	0	10.0	
i 1	35.25040136054422	0.2525	72	204	4	1	2	2	0	-2	2	0	0	10.0	
i 1	35.2568231292517	0.505	71	204	4	5	4	8	0	-1	8	0	0	6.0	
i 1	35.26244217687075	0.2525	75	204	4	1	9	2	0	-2	2	0	0	10.0	
i 1	35.4931768707483	0.2525	74	590	6	5	3	8	0	-1	8	0	0	6.0	
i 1	35.51324489795918	4.04	73	204	3	24	12	17	0	1	17	0	0	4.0	
i 1	35.7319387755102	0.2525	74	590	6	5	15	8	0	-2	8	0	0	6.0	
i 1	35.73755782312925	0.2525	71	204	7	5	12	2	0	-1	2	0	0	6.0	
i 1	35.75361224489796	0.2525	75	204	4	1	5	2	0	-2	2	0	0	10.0	
i 1	35.7568231292517	1.7675	74	590	5	3	10	17	0	1	17	0	0	4.0	
i 1	35.76244217687075	0.2525	72	204	3	24	10	8	0	-2	8	0	0	11.0	
i 1	35.76485034013606	0.2525	76	590	3	24	8	17	0	1	17	0	0	4.0	
i 1	35.983544217687076	1.01	74	590	6	5	8	8	0	-1	8	0	0	6.0	
i 1	35.98675510204082	0.7575000000000001	72	906	5	1	10	2	0	1	2	0	0	10.0	
i 1	35.99799319727891	1.5150000000000001	72	590	5	1	12	2	0	-2	2	0	0	10.0	
i 1	35.99959863945578	9.09	61	204	5	18	3	1	0	2	1	0	0	0.5009235345346933	
i 1	36.00441496598639	1.5150000000000001	61	204	5	19	8	1	0	2	1	0	0	0.5009235345346933	
i 1	36.0068231292517	1.01	73	204	2	24	6	17	0	1	17	0	0	4.0	
i 1	36.23434693877551	0.2525	74	204	7	5	4	8	0	-2	8	0	0	6.0	
i 1	36.48274149659864	0.7575000000000001	71	204	7	5	2	2	0	-1	2	0	0	6.0	
i 1	36.75200680272109	0.2525	72	204	3	24	13	8	0	-2	8	0	0	11.0	
i 1	36.993979591836734	0.505	72	906	5	1	5	2	0	1	2	0	0	10.0	
i 1	37.00120408163265	0.505	73	204	2	24	12	17	0	1	17	0	0	4.0	
i 1	37.00923129251701	0.2525	72	204	3	1	16	2	0	1	2	0	0	10.0	
i 1	37.01324489795918	0.2525	76	590	3	24	1	16	0	1	16	0	0	4.0	
i 1	37.014047619047616	0.2525	74	906	6	5	11	2	0	-1	2	0	0	6.0	
i 1	37.239163265306125	0.7575000000000001	74	204	7	5	3	8	0	-2	8	0	0	6.0	
i 1	37.256020408163266	0.2525	74	590	6	5	3	8	0	-2	8	0	0	6.0	
i 1	37.480333333333334	0.2525	74	1088	6	5	3	8	0	-2	8	0	0	6.0	
i 1	37.48274149659864	7.575	63	1088	5	14	15	1	0	1	1	0	0	6.513827711769258	
i 1	37.48434693877551	4.545	63	702	4	19	14	16	0	1	16	0	0	0.5009235345346933	
i 1	37.485952380952384	0.7575000000000001	77	1088	6	2	2	16	0	1	16	0	0	4.0	
i 1	37.488360544217684	5.555	61	702	5	13	11	16	0	1	16	0	0	2.605531084707703	
i 1	37.49076870748299	0.505	72	204	4	1	3	2	0	-2	2	0	0	10.0	
i 1	37.49638775510204	1.01	72	702	4	24	11	2	0	-2	2	0	0	11.0	
i 1	37.497190476190475	0.2525	73	702	2	24	16	17	0	2	17	0	0	4.0	
i 1	37.50040136054422	5.555	63	702	5	7	2	1	0	2	1	0	0	5.211062169415406	
i 1	37.50120408163265	1.5150000000000001	61	1088	6	17	14	16	0	2	16	0	0	0.5009235345346933	
i 1	37.502809523809525	4.545	61	702	6	17	15	1	0	1	1	0	0	0.5009235345346933	
i 1	37.502809523809525	7.575	61	702	4	19	5	1	0	2	1	0	0	0.5009235345346933	
i 1	37.50762585034013	5.555	63	702	6	17	15	16	0	1	16	0	0	0.5009235345346933	
i 1	37.50762585034013	2.02	71	702	6	5	11	8	0	-1	8	0	0	6.0	
i 1	37.510836734693875	2.02	74	702	4	4	2	16	0	2	16	0	0	4.0	
i 1	37.51324489795918	7.575	61	1088	5	14	8	16	0	2	16	0	0	6.513827711769258	
i 1	38.00120408163265	0.2525	71	204	7	5	8	8	0	-1	8	0	0	6.0	
i 1	38.00923129251701	2.2725	72	702	5	1	15	8	0	-2	8	0	0	10.0	
i 1	38.014047619047616	0.505	74	702	6	5	3	2	0	-2	2	0	0	6.0	
i 1	38.238360544217684	0.505	74	702	6	5	11	8	0	-2	8	0	0	6.0	
i 1	38.485952380952384	0.505	75	204	4	1	8	2	0	-2	2	0	0	10.0	
i 1	38.51244217687075	0.2525	74	1088	6	5	6	8	0	-1	8	0	0	6.0	
i 1	38.76244217687075	2.02	74	702	6	5	11	2	0	-2	2	0	0	6.0	
i 1	38.76485034013606	0.2525	74	1088	6	5	16	8	0	-2	8	0	0	6.0	
i 1	38.98274149659864	1.2625	73	702	2	24	4	17	0	2	17	0	0	4.0	
i 1	38.98434693877551	6.0600000000000005	63	204	5	18	4	16	0	2	16	0	0	0.5009235345346933	
i 1	38.9931768707483	3.0300000000000002	75	1088	5	1	6	2	0	-2	2	0	0	10.0	
i 1	39.002809523809525	0.2525	75	702	3	24	12	2	0	1	2	0	0	11.0	
i 1	39.00441496598639	2.02	77	1088	6	2	8	16	0	1	16	0	0	4.0	
i 1	39.2431768707483	0.505	75	1088	5	1	16	2	0	1	2	0	0	10.0	
i 1	39.24478231292517	0.2525	71	702	6	5	6	8	0	-1	8	0	0	6.0	
i 1	39.49638775510204	0.505	74	702	3	5	7	8	0	-2	8	0	0	6.0	
i 1	39.497190476190475	0.505	74	204	6	9	9	17	0	1	17	0	0	3.0	
i 1	39.49799319727891	0.505	71	204	7	5	10	8	0	-1	8	0	0	6.0	
i 1	39.50923129251701	0.2525	77	702	5	3	7	17	0	1	17	0	0	4.0	
i 1	39.7319387755102	0.2525	75	204	4	1	8	2	0	-2	2	0	0	10.0	
i 1	39.74076870748299	4.04	73	204	3	24	14	17	0	1	17	0	0	4.0	
i 1	39.98113605442177	0.2525	74	204	7	5	9	8	0	-2	8	0	0	6.0	
i 1	39.989163265306125	0.2525	77	204	6	9	6	17	0	2	17	0	0	3.0	
i 1	39.98996598639456	0.2525	75	702	3	24	1	2	0	1	2	0	0	11.0	
i 1	39.99237414965987	2.02	74	1088	6	5	3	8	0	-1	8	0	0	6.0	
i 1	39.99959863945578	0.505	74	702	4	4	10	16	0	2	16	0	0	4.0	
i 1	40.25361224489796	0.7575000000000001	74	1088	6	5	15	8	0	-2	8	0	0	6.0	
i 1	40.26003401360544	0.505	74	702	5	3	4	16	0	1	16	0	0	4.0	
i 1	40.497190476190475	0.2525	73	702	2	24	5	17	0	2	17	0	0	4.0	
i 1	40.50040136054422	1.5150000000000001	74	1088	6	2	15	17	0	2	17	0	0	4.0	
i 1	40.50923129251701	0.7575000000000001	75	1088	5	1	15	2	0	1	2	0	0	10.0	
i 1	40.735952380952384	0.2525	77	702	4	4	9	16	0	2	16	0	0	4.0	
i 1	40.756020408163266	0.7575000000000001	71	204	7	5	12	8	0	-1	8	0	0	6.0	
i 1	40.98996598639456	0.2525	74	702	3	5	11	8	0	-2	8	0	0	6.0	
i 1	41.006020408163266	0.2525	77	204	6	9	10	17	0	2	17	0	0	3.0	
i 1	41.01324489795918	0.2525	77	702	5	3	11	17	0	1	17	0	0	4.0	
i 1	41.230333333333334	1.7675	72	702	5	1	1	8	0	-2	8	0	0	10.0	
i 1	41.25200680272109	0.505	71	702	6	5	3	8	0	-1	8	0	0	6.0	
i 1	41.49478231292517	0.2525	74	702	3	5	2	8	0	-2	8	0	0	6.0	
i 1	41.519666666666666	2.02	77	1088	6	2	1	16	0	1	16	0	0	4.0	
i 1	41.74478231292517	1.2625	74	702	6	5	12	2	0	-2	2	0	0	6.0	
i 1	41.75361224489796	0.2525	71	204	7	5	10	8	0	-1	8	0	0	6.0	
i 1	41.75923129251701	0.7575000000000001	73	702	2	24	3	17	0	2	17	0	0	4.0	
i 1	41.98274149659864	3.0300000000000002	63	702	4	19	10	16	0	1	16	0	0	0.5009235345346933	
i 1	41.993979591836734	0.505	74	1088	6	5	6	8	0	-1	8	0	0	6.0	
i 1	41.997190476190475	0.7575000000000001	74	1088	6	5	7	8	0	-2	8	0	0	6.0	
i 1	42.26886394557823	0.505	77	702	5	3	13	17	0	1	17	0	0	4.0	
i 1	42.497190476190475	0.2525	75	1088	5	1	14	2	0	-2	2	0	0	10.0	
i 1	42.50040136054422	0.505	72	204	5	1	15	2	0	-2	2	0	0	10.0	
i 1	42.508428571428574	0.2525	73	702	2	24	7	16	0	2	16	0	0	4.0	
i 1	42.51485034013606	0.2525	74	204	7	5	13	8	0	-2	8	0	0	6.0	
i 1	42.73113605442177	1.2625	75	1088	5	1	11	2	0	1	2	0	0	10.0	
i 1	42.7319387755102	2.02	74	1088	6	5	10	8	0	-1	8	0	0	6.0	
i 1	42.75040136054422	0.2525	73	702	3	24	14	16	0	2	16	0	0	4.0	
i 1	42.76324489795918	0.2525	71	702	6	5	11	8	0	-1	8	0	0	6.0	
i 1	42.98113605442177	0.505	75	702	3	24	3	2	0	1	2	0	0	11.0	
i 1	42.98274149659864	0.2525	75	590	5	1	14	2	0	1	2	0	0	10.0	
i 1	42.983544217687076	0.505	71	590	6	5	4	2	0	-1	2	0	0	6.0	
i 1	42.99558503401361	2.02	61	590	6	17	15	16	0	1	16	0	0	0.5009235345346933	
i 1	42.99558503401361	2.02	63	590	5	13	1	1	0	2	1	0	0	2.605531084707703	
i 1	42.99959863945578	2.02	63	590	5	7	15	16	0	2	16	0	0	5.211062169415406	
i 1	43.00521768707483	1.7675	74	590	5	3	4	17	0	1	17	0	0	4.0	
i 1	43.23434693877551	1.7675	75	590	4	24	3	2	0	-2	2	0	0	11.0	
i 1	43.24076870748299	0.7575000000000001	73	702	2	24	14	17	0	2	17	0	0	4.0	
i 1	43.48755782312925	0.2525	77	702	4	4	11	16	0	2	16	0	0	4.0	
i 1	43.49076870748299	0.2525	75	702	3	1	9	2	0	-2	2	0	0	10.0	
i 1	43.49558503401361	0.7575000000000001	74	204	6	9	9	17	0	1	17	0	0	3.0	
i 1	43.50762585034013	0.2525	76	590	3	24	7	17	0	1	17	0	0	4.0	
i 1	43.73274149659864	1.01	73	702	2	24	6	16	0	2	16	0	0	4.0	
i 1	43.74237414965987	0.2525	72	204	5	1	16	2	0	-2	2	0	0	10.0	
i 1	43.76725850340136	0.505	77	204	6	9	9	17	0	2	17	0	0	3.0	
i 1	43.98113605442177	0.2525	71	204	7	5	14	8	0	-1	8	0	0	6.0	
i 1	43.997190476190475	0.505	75	702	3	1	3	2	0	-2	2	0	0	10.0	
i 1	44.00200680272109	0.2525	75	590	5	1	11	2	0	1	2	0	0	10.0	
i 1	44.00361224489796	0.505	71	702	6	5	3	8	0	-1	8	0	0	6.0	
i 1	44.23113605442177	0.505	75	1088	5	1	11	2	0	1	2	0	0	10.0	
i 1	44.23274149659864	0.2525	77	702	4	4	3	16	0	2	16	0	0	4.0	
i 1	44.238360544217684	0.7575000000000001	71	590	6	5	15	2	0	-1	2	0	0	6.0	
i 1	44.261639455782316	0.7575000000000001	74	1088	6	2	3	17	0	2	17	0	0	4.0	
i 1	44.48113605442177	0.505	71	590	6	5	2	2	0	-1	2	0	0	6.0	
i 1	44.4819387755102	3.0300000000000002	77	1088	6	2	14	16	0	1	16	0	0	4.0	
i 1	44.51886394557823	0.505	75	590	5	1	14	2	0	1	2	0	0	10.0	
i 1	44.74799319727891	0.2525	74	702	6	5	12	8	0	-2	8	0	0	6.0	
i 1	44.756020408163266	0.2525	77	204	6	9	11	17	0	2	17	0	0	3.0	
i 1	44.76324489795918	1.01	73	702	2	24	14	17	0	2	17	0	0	4.0	
i 1	44.764047619047616	0.2525	75	702	3	24	12	2	0	1	2	0	0	11.0	
i 1	44.98274149659864	0.505	75	1088	5	1	14	2	0	-2	2	0	0	7.794557119032869	
i 1	44.98274149659864	5.05	63	1088	5	25	3	16	0	1	16	0	0	0.39147284124284637	
i 1	44.98274149659864	10.605	63	204	5	26	10	1	0	1	1	0	0	0.39147284124284637	
i 1	44.98996598639456	10.605	61	204	5	26	9	16	0	2	16	0	0	0.39147284124284637	
i 1	44.99478231292517	5.05	63	702	4	19	12	16	0	1	16	0	0	3.506464741742853	
i 1	44.99478231292517	0.7575000000000001	71	590	6	5	14	2	0	-1	2	0	0	9.948905943535717	
i 1	44.99558503401361	0.2525	75	590	4	24	4	2	0	-2	2	0	0	8.79455711903287	
i 1	44.99638775510204	3.0300000000000002	61	204	5	18	9	1	0	2	1	0	0	3.506464741742853	
i 1	44.99799319727891	0.7575000000000001	61	590	5	25	12	1	0	2	1	0	0	0.39147284124284637	
i 1	45.00040136054422	0.7575000000000001	75	590	5	1	9	2	0	1	2	0	0	7.794557119032869	
i 1	45.00040136054422	0.505	74	590	5	3	8	17	0	1	17	0	0	4.0	
i 1	45.00120408163265	0.505	74	702	6	5	9	8	0	-2	8	0	0	9.948905943535717	
i 1	45.00762585034013	0.505	74	590	4	4	8	16	0	1	16	0	0	4.0	
i 1	45.01003401360544	6.0600000000000005	63	204	5	18	16	16	0	2	16	0	0	3.506464741742853	
i 1	45.01003401360544	5.05	63	1088	5	25	5	16	0	2	16	0	0	0.39147284124284637	
i 1	45.010836734693875	0.7575000000000001	63	590	5	25	3	1	0	1	1	0	0	0.39147284124284637	
i 1	45.01244217687075	5.05	61	702	4	19	9	1	0	2	1	0	0	3.506464741742853	
i 1	45.016455782312924	0.2525	74	204	7	5	2	8	0	-2	8	0	0	9.948905943535717	
i 1	45.24076870748299	2.02	73	204	3	24	2	17	0	1	17	0	0	4.0	
i 1	45.25762585034013	0.505	75	204	5	1	2	2	0	-2	2	0	0	7.794557119032869	
i 1	45.491571428571426	0.2525	74	204	6	9	16	17	0	1	17	0	0	3.0	
i 1	45.50361224489796	0.2525	77	702	5	3	9	17	0	1	17	0	0	4.0	
i 1	45.50441496598639	0.2525	71	702	6	5	7	8	0	-1	8	0	0	9.948905943535717	
i 1	45.510836734693875	0.505	75	702	3	24	3	2	0	1	2	0	0	8.79455711903287	
i 1	45.51244217687075	0.505	74	1088	6	5	1	8	0	-2	8	0	0	9.948905943535717	
i 1	45.73274149659864	0.2525	77	386	5	3	1	17	0	2	17	0	0	4.0	
i 1	45.73274149659864	4.2925	61	386	5	25	1	1	0	2	1	0	0	0.39147284124284637	
i 1	45.75120408163265	2.02	74	1088	6	5	4	8	0	-1	8	0	0	9.948905943535717	
i 1	45.75441496598639	0.2525	77	386	4	4	5	16	0	1	16	0	0	4.0	
i 1	45.75521768707483	0.505	75	386	5	1	15	2	0	-2	2	0	0	7.794557119032869	
i 1	45.76003401360544	4.2925	61	386	5	25	3	16	0	1	16	0	0	0.39147284124284637	
i 1	45.76324489795918	3.535	75	1088	5	1	9	2	0	-2	2	0	0	7.794557119032869	
i 1	45.76485034013606	0.505	71	386	6	5	5	2	0	-2	2	0	0	9.948905943535717	
i 1	45.985952380952384	0.7575000000000001	72	204	5	1	11	2	0	-2	2	0	0	7.794557119032869	
i 1	45.993979591836734	0.505	77	702	4	4	5	16	0	2	16	0	0	4.0	
i 1	46.01485034013606	0.2525	71	204	7	5	8	8	0	-1	8	0	0	9.948905943535717	
i 1	46.238360544217684	0.2525	75	1088	5	1	12	2	0	1	2	0	0	7.794557119032869	
i 1	46.239163265306125	0.2525	73	702	1	24	14	17	0	2	17	0	0	4.0	
i 1	46.24076870748299	0.2525	77	386	4	4	1	16	0	1	16	0	0	4.0	
i 1	46.25200680272109	0.505	71	702	6	5	16	8	0	-1	8	0	0	9.948905943535717	
i 1	46.25361224489796	0.2525	71	386	6	5	6	8	0	-2	8	0	0	9.948905943535717	
i 1	46.489163265306125	0.2525	77	386	5	3	13	17	0	2	17	0	0	4.0	
i 1	46.5068231292517	2.7775	75	386	5	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	46.51725850340136	0.2525	77	702	5	3	15	17	0	1	17	0	0	4.0	
i 1	46.73755782312925	2.02	74	1088	4	2	7	17	0	2	17	0	0	4.0	
i 1	46.74478231292517	0.505	74	204	7	5	6	8	0	-2	8	0	0	9.948905943535717	
i 1	46.752809523809525	0.2525	75	1088	5	1	4	2	0	1	2	0	0	7.794557119032869	
i 1	46.76485034013606	0.2525	74	1088	6	5	6	8	0	-2	8	0	0	9.948905943535717	
i 1	46.99799319727891	0.2525	75	386	4	24	2	2	0	-2	2	0	0	8.79455711903287	
i 1	46.99959863945578	0.2525	71	204	7	5	7	8	0	-1	8	0	0	9.948905943535717	
i 1	47.24237414965987	0.2525	71	702	6	5	13	8	0	-1	8	0	0	9.948905943535717	
i 1	47.243979591836734	1.01	74	1088	6	5	12	8	0	-2	8	0	0	9.948905943535717	
i 1	47.26565306122449	0.505	75	702	3	24	4	2	0	1	2	0	0	8.79455711903287	
i 1	47.491571428571426	1.5150000000000001	71	386	6	5	12	8	0	-2	8	0	0	9.948905943535717	
i 1	47.49638775510204	0.505	77	702	5	3	7	17	0	1	17	0	0	4.0	
i 1	47.502809523809525	0.2525	73	702	1	24	14	17	0	2	17	0	0	4.0	
i 1	47.5068231292517	0.2525	77	386	4	4	4	16	0	1	16	0	0	4.0	
i 1	47.510836734693875	0.505	73	204	3	24	10	17	0	1	17	0	0	4.0	
i 1	47.73434693877551	0.2525	71	702	6	5	3	8	0	-1	8	0	0	9.948905943535717	
i 1	47.73514965986394	0.505	77	204	6	9	12	17	0	2	17	0	0	3.0	
i 1	47.73996598639456	0.2525	73	386	2	24	1	17	0	1	17	0	0	4.0	
i 1	47.75200680272109	0.2525	75	702	3	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	47.98434693877551	2.02	77	386	5	3	11	17	0	2	17	0	0	4.0	
i 1	48.00441496598639	0.2525	74	204	7	5	12	8	0	-2	8	0	0	9.948905943535717	
i 1	48.0068231292517	2.02	61	702	3	27	14	16	0	1	16	0	0	12.738040549334222	
i 1	48.011639455782316	0.505	73	204	2	24	5	17	0	1	17	0	0	4.0	
i 1	48.0180612244898	0.7575000000000001	76	702	1	24	2	17	0	1	17	0	0	4.0	
i 1	48.01886394557823	0.2525	75	386	4	24	4	2	0	-2	2	0	0	8.79455711903287	
i 1	48.24558503401361	1.7675	75	1088	5	1	2	2	0	1	2	0	0	7.794557119032869	
i 1	48.256020408163266	0.505	71	204	7	5	14	8	0	-1	8	0	0	9.948905943535717	
i 1	48.260836734693875	0.2525	77	386	4	4	8	16	0	1	16	0	0	4.0	
i 1	48.266455782312924	0.2525	74	702	6	5	7	8	0	-2	8	0	0	9.948905943535717	
i 1	48.49879591836735	0.2525	77	702	5	3	7	17	0	1	17	0	0	4.0	
i 1	48.51565306122449	1.5150000000000001	74	1088	6	5	1	8	0	-2	8	0	0	9.948905943535717	
i 1	48.735952380952384	0.2525	76	386	2	24	4	16	0	1	16	0	0	4.0	
i 1	48.743979591836734	0.2525	74	702	6	5	16	8	0	-2	8	0	0	9.948905943535717	
i 1	48.76003401360544	1.2625	77	386	4	4	3	16	0	1	16	0	0	4.0	
i 1	48.98996598639456	0.2525	71	386	6	5	3	2	0	-2	2	0	0	9.948905943535717	
i 1	48.99076870748299	0.2525	71	702	6	5	7	8	0	-1	8	0	0	9.948905943535717	
i 1	49.01244217687075	1.01	73	702	2	24	5	17	0	2	17	0	0	4.0	
i 1	49.25441496598639	0.2525	72	204	5	1	4	2	0	-2	2	0	0	7.794557119032869	
i 1	49.26324489795918	0.2525	75	702	4	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	49.485952380952384	0.505	71	386	6	5	6	2	0	-2	2	0	0	9.948905943535717	
i 1	49.49558503401361	0.2525	75	386	4	24	15	2	0	-2	2	0	0	8.79455711903287	
i 1	49.49879591836735	0.7575000000000001	73	204	2	24	8	17	0	1	17	0	0	4.0	
i 1	49.51485034013606	0.2525	75	702	3	24	9	2	0	1	2	0	0	8.79455711903287	
i 1	49.51886394557823	0.2525	74	702	6	5	11	8	0	-2	8	0	0	9.948905943535717	
i 1	49.74959863945578	0.2525	76	386	2	24	8	16	0	2	16	0	0	4.0	
i 1	49.983544217687076	2.02	77	906	4	2	13	16	0	1	16	0	0	4.0	
i 1	49.983544217687076	3.535	71	590	6	5	10	2	0	-2	2	0	0	9.948905943535717	
i 1	49.98434693877551	5.555	63	204	5	19	12	16	0	2	16	0	0	3.506464741742853	
i 1	49.98514965986394	1.01	61	204	1	27	9	16	0	248	16	308	0	12.738040549334222	
i 1	49.98755782312925	11.11	61	906	5	25	4	16	0	2	16	0	0	0.39147284124284637	
i 1	49.989163265306125	11.11	63	906	5	25	1	1	0	2	1	0	0	0.39147284124284637	
i 1	49.993979591836734	1.7675	76	204	1	24	5	16	0	2	16	0	0	4.0	
i 1	49.997190476190475	11.11	63	590	5	25	7	1	0	2	1	0	0	0.39147284124284637	
i 1	50.00040136054422	0.2525	74	906	6	5	9	8	0	-1	8	0	0	9.948905943535717	
i 1	50.00120408163265	11.11	61	590	5	25	14	16	0	2	16	0	0	0.39147284124284637	
i 1	50.002809523809525	0.2525	71	590	6	5	10	2	0	-1	2	0	0	9.948905943535717	
i 1	50.00441496598639	0.505	77	906	4	2	15	17	0	2	17	0	0	4.0	
i 1	50.0068231292517	5.555	63	204	4	27	4	1	0	1	1	0	0	12.738040549334222	
i 1	50.011639455782316	2.7775	72	590	5	1	12	2	0	-2	2	0	0	7.794557119032869	
i 1	50.01565306122449	4.04	63	204	5	19	12	16	0	2	16	0	0	3.506464741742853	
i 1	50.239163265306125	0.505	71	204	7	5	6	8	0	-1	8	0	0	9.948905943535717	
i 1	50.25040136054422	0.2525	76	204	2	24	7	16	0	1	16	0	0	4.0	
i 1	50.252809523809525	0.2525	74	906	6	5	11	8	0	-1	8	0	0	9.948905943535717	
i 1	50.26485034013606	0.2525	74	590	5	3	15	17	0	2	17	0	0	4.0	
i 1	50.48274149659864	0.505	74	204	6	3	15	17	0	2	17	0	0	4.0	
i 1	50.5068231292517	0.7575000000000001	72	204	5	1	1	2	0	-2	2	0	0	7.794557119032869	
i 1	50.51886394557823	0.505	74	204	6	9	12	17	0	1	17	0	0	3.0	
i 1	50.74959863945578	0.505	74	906	6	5	5	8	0	-1	8	0	0	9.948905943535717	
i 1	50.76485034013606	0.2525	75	204	3	24	8	2	0	1	2	0	0	8.79455711903287	
i 1	50.98996598639456	4.545	61	204	4	27	2	16	0	1	16	0	0	12.738040549334222	
i 1	50.99799319727891	0.2525	77	204	6	9	10	17	0	2	17	0	0	3.0	
i 1	51.006020408163266	0.2525	76	204	2	24	16	16	0	1	16	0	0	4.0	
i 1	51.01324489795918	1.01	75	906	4	1	7	2	0	1	2	0	0	7.794557119032869	
i 1	51.01886394557823	0.2525	74	590	4	3	15	17	0	2	17	0	0	4.0	
i 1	51.23274149659864	0.505	71	204	7	5	2	8	0	-1	8	0	0	9.948905943535717	
i 1	51.235952380952384	0.2525	75	204	4	1	12	2	0	-2	2	0	0	7.794557119032869	
i 1	51.238360544217684	0.2525	71	204	7	5	16	8	0	-1	8	0	0	9.948905943535717	
i 1	51.25361224489796	0.2525	74	204	6	3	10	17	0	2	17	0	0	4.0	
i 1	51.266455782312924	2.2725	74	590	4	4	1	16	0	2	16	0	0	4.0	
i 1	51.4819387755102	0.505	74	906	6	5	12	8	0	-1	8	0	0	9.948905943535717	
i 1	51.48755782312925	0.505	77	204	6	9	2	17	0	2	17	0	0	3.0	
i 1	51.4931768707483	0.2525	75	204	5	1	6	2	0	-2	2	0	0	7.794557119032869	
i 1	51.51324489795918	1.7675	73	204	2	24	2	17	0	1	17	0	0	4.0	
i 1	51.74237414965987	0.2525	71	590	6	5	6	2	0	-1	2	0	0	9.948905943535717	
i 1	51.76244217687075	0.505	72	204	5	1	2	2	0	-2	2	0	0	7.794557119032869	
i 1	51.99237414965987	0.7575000000000001	76	204	2	24	9	16	0	1	16	0	0	4.0	
i 1	52.00120408163265	0.2525	74	204	5	4	9	16	0	1	16	0	0	4.0	
i 1	52.006020408163266	0.505	71	204	7	5	4	8	0	-1	8	0	0	9.948905943535717	
i 1	52.008428571428574	0.2525	75	204	5	1	5	2	0	-2	2	0	0	7.794557119032869	
i 1	52.014047619047616	0.2525	74	204	6	5	6	8	0	-2	8	0	0	9.948905943535717	
i 1	52.016455782312924	0.505	77	906	4	2	9	17	0	2	17	0	0	4.0	
i 1	52.238360544217684	0.2525	75	204	4	1	8	2	0	-2	2	0	0	7.794557119032869	
i 1	52.25200680272109	0.505	74	906	6	5	5	8	0	-1	8	0	0	9.948905943535717	
i 1	52.260836734693875	0.2525	73	590	2	24	11	16	0	1	16	0	0	4.0	
i 1	52.26244217687075	0.2525	77	906	4	2	13	16	0	1	16	0	0	4.0	
i 1	52.2680612244898	2.02	75	906	4	1	3	2	0	1	2	0	0	7.794557119032869	
i 1	52.48434693877551	0.505	74	590	4	3	7	17	0	2	17	0	0	4.0	
i 1	52.49076870748299	0.2525	74	204	7	5	3	8	0	-2	8	0	0	9.948905943535717	
i 1	52.50120408163265	0.7575000000000001	72	204	5	1	7	2	0	-2	2	0	0	7.794557119032869	
i 1	52.51244217687075	0.2525	76	204	1	24	7	17	0	2	17	0	0	4.0	
i 1	52.747190476190475	0.505	71	204	7	5	7	8	0	-1	8	0	0	9.948905943535717	
i 1	52.764047619047616	0.2525	72	590	4	24	15	8	0	1	8	0	0	8.79455711903287	
i 1	52.766455782312924	0.2525	74	204	6	5	8	8	0	-2	8	0	0	9.948905943535717	
i 1	52.98514965986394	0.7575000000000001	76	204	2	24	13	16	0	1	16	0	0	4.0	
i 1	53.00040136054422	0.2525	72	906	5	1	13	2	0	-2	2	0	0	7.794557119032869	
i 1	53.01003401360544	1.5150000000000001	77	906	4	2	11	16	0	1	16	0	0	4.0	
i 1	53.011639455782316	0.7575000000000001	74	906	6	5	5	8	0	-1	8	0	0	9.948905943535717	
i 1	53.25762585034013	0.7575000000000001	74	906	6	5	15	8	0	-1	8	0	0	9.948905943535717	
i 1	53.50441496598639	0.505	71	204	7	5	7	8	0	-1	8	0	0	9.948905943535717	
i 1	53.7319387755102	0.2525	71	204	7	5	4	8	0	-1	8	0	0	9.948905943535717	
i 1	53.76886394557823	1.2625	72	590	5	1	6	2	0	-2	2	0	0	7.794557119032869	
i 1	53.989163265306125	2.02	77	906	4	2	8	17	0	2	17	0	0	4.0	
i 1	53.991571428571426	1.5150000000000001	76	204	2	20	12	16	0	1	16	0	0	0.7587699775925509	
i 1	53.99478231292517	0.2525	74	906	6	5	2	8	0	-1	8	0	0	9.948905943535717	
i 1	53.99799319727891	0.2525	71	590	6	5	3	2	0	-2	2	0	0	9.948905943535717	
i 1	54.00120408163265	1.01	74	906	5	5	16	8	0	-1	8	0	0	9.948905943535717	
i 1	54.00200680272109	0.2525	74	204	6	9	15	17	0	1	17	0	0	3.0	
i 1	54.00762585034013	1.01	76	204	2	20	8	17	0	1	17	0	0	0.7587699775925509	
i 1	54.008428571428574	0.2525	73	204	1	20	8	16	0	1	16	0	0	0.7587699775925509	
i 1	54.24558503401361	0.2525	73	204	2	24	6	17	0	1	17	0	0	4.758769977592551	
i 1	54.247190476190475	0.7575000000000001	71	204	7	5	15	8	0	-1	8	0	0	9.948905943535717	
i 1	54.24959863945578	0.505	77	204	6	9	15	17	0	2	17	0	0	3.0	
i 1	54.264047619047616	2.2725	71	590	6	5	5	2	0	-1	2	0	0	9.948905943535717	
i 1	54.48514965986394	1.01	73	204	2	20	9	17	0	2	17	0	0	0.7587699775925509	
i 1	54.491571428571426	1.5150000000000001	75	906	4	1	5	2	0	1	2	0	0	7.794557119032869	
i 1	54.491571428571426	0.2525	74	590	4	3	11	17	0	2	17	0	0	4.0	
i 1	54.49638775510204	1.01	73	204	1	24	10	17	0	252	17	307	0	4.758769977592551	
i 1	54.5180612244898	0.7575000000000001	73	204	1	24	16	16	0	2	16	0	0	4.758769977592551	
i 1	54.73675510204082	0.2525	74	204	6	9	7	17	0	1	17	0	0	3.0	
i 1	54.74237414965987	0.2525	72	590	4	24	12	8	0	1	8	0	0	8.79455711903287	
i 1	54.74237414965987	0.2525	77	906	4	2	5	16	0	1	16	0	0	4.0	
i 1	54.993979591836734	0.2525	76	204	2	20	5	17	0	1	17	0	0	0.7587699775925509	
i 1	55.00120408163265	0.2525	71	204	6	5	10	8	0	-1	8	0	0	9.948905943535717	
i 1	55.010836734693875	0.505	75	204	4	24	14	2	0	1	2	0	0	8.79455711903287	
i 1	55.01565306122449	0.2525	74	906	6	5	11	8	0	-1	8	0	0	9.948905943535717	
i 1	55.019666666666666	0.505	75	204	4	1	14	2	0	-2	2	0	0	7.794557119032869	
i 1	55.25361224489796	0.2525	74	204	7	5	11	8	0	-2	8	0	0	9.948905943535717	
i 1	55.25762585034013	0.2525	73	590	2	24	4	16	0	2	16	0	0	4.758769977592551	
i 1	55.264047619047616	0.505	76	906	2	20	16	16	0	1	16	0	0	0.7587699775925509	
i 1	55.26485034013606	0.2525	71	204	7	5	13	8	0	-1	8	0	0	9.948905943535717	
i 1	55.4819387755102	5.555	61	203	4	27	3	1	0	2	1	0	0	12.738040549334222	
i 1	55.48274149659864	0.2525	77	203	6	3	1	17	0	2	17	0	0	4.0	
i 1	55.49478231292517	1.5150000000000001	63	203	5	19	15	1	0	1	1	0	0	3.506464741742853	
i 1	55.49478231292517	5.555	61	1172	4	26	12	1	0	1	1	0	0	0.39147284124284637	
i 1	55.49558503401361	5.555	63	1172	4	26	1	16	0	2	16	0	0	0.39147284124284637	
i 1	55.49558503401361	0.2525	71	1172	6	5	1	8	0	-2	8	0	0	9.948905943535717	
i 1	55.49959863945578	1.5150000000000001	72	590	5	1	4	2	0	-2	2	0	0	7.794557119032869	
i 1	55.50200680272109	4.04	74	590	4	3	15	17	0	2	17	0	0	4.0	
i 1	55.50521768707483	5.555	61	203	4	27	7	16	0	1	16	0	0	12.738040549334222	
i 1	55.50762585034013	2.2725	76	1172	2	20	1	16	0	2	16	0	0	0.7587699775925509	
i 1	55.51244217687075	0.505	74	906	6	5	15	8	0	-1	8	0	0	9.948905943535717	
i 1	55.516455782312924	0.2525	75	1172	5	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	55.730333333333334	0.2525	73	1172	2	20	6	16	0	1	16	0	0	0.7587699775925509	
i 1	55.738360544217684	2.02	74	906	5	5	9	8	0	-1	8	0	0	9.948905943535717	
i 1	55.741571428571426	0.2525	76	1172	2	20	16	16	0	2	16	0	0	0.7587699775925509	
i 1	55.743979591836734	0.7575000000000001	73	1172	2	24	16	17	0	1	17	0	0	4.758769977592551	
i 1	55.74638775510204	0.2525	73	203	1	24	2	17	0	2	17	0	0	4.758769977592551	
i 1	55.75120408163265	0.505	74	1172	5	9	11	16	0	1	16	0	0	3.0	
i 1	55.76725850340136	0.505	75	203	4	1	10	2	0	1	2	0	0	7.794557119032869	
i 1	55.98274149659864	0.2525	71	203	7	5	9	2	0	-1	2	0	0	9.948905943535717	
i 1	55.98755782312925	0.505	76	906	2	20	2	16	0	2	16	0	0	0.7587699775925509	
i 1	55.991571428571426	0.7575000000000001	73	203	1	24	13	17	0	2	17	0	0	4.758769977592551	
i 1	56.006020408163266	0.505	76	590	2	24	8	17	0	2	17	0	0	4.758769977592551	
i 1	56.01485034013606	0.505	75	1172	5	1	5	2	0	-2	2	0	0	7.794557119032869	
i 1	56.01485034013606	0.2525	74	590	4	4	16	16	0	2	16	0	0	4.0	
i 1	56.230333333333334	0.2525	72	203	4	24	9	2	0	-2	2	0	0	8.79455711903287	
i 1	56.23996598639456	0.505	77	203	6	3	8	17	0	2	17	0	0	4.0	
i 1	56.258428571428574	0.2525	74	203	7	5	9	2	0	-2	2	0	0	9.948905943535717	
i 1	56.266455782312924	0.2525	77	1172	5	9	14	17	0	2	17	0	0	3.0	
i 1	56.48514965986394	1.5150000000000001	73	1172	2	20	9	16	0	2	16	0	0	0.7587699775925509	
i 1	56.49237414965987	0.2525	75	906	4	1	10	2	0	1	2	0	0	7.794557119032869	
i 1	56.51003401360544	0.2525	72	590	4	24	8	8	0	1	8	0	0	8.79455711903287	
i 1	56.730333333333334	0.2525	71	1172	6	5	1	8	0	-1	8	0	0	9.948905943535717	
i 1	56.73274149659864	0.2525	74	1172	5	9	15	16	0	1	16	0	0	3.0	
i 1	56.74799319727891	0.2525	73	1172	2	20	9	16	0	1	16	0	0	0.7587699775925509	
i 1	56.7680612244898	0.505	71	590	6	5	3	2	0	-1	2	0	0	9.948905943535717	
i 1	56.769666666666666	0.505	77	906	4	2	2	17	0	2	17	0	0	4.0	
i 1	56.98675510204082	1.5150000000000001	72	590	4	1	4	2	0	-2	2	0	0	7.794557119032869	
i 1	56.99638775510204	1.2625	73	1172	2	24	10	17	0	1	17	0	0	4.758769977592551	
i 1	57.00040136054422	1.2625	74	590	4	4	8	16	0	2	16	0	0	4.0	
i 1	57.00120408163265	0.7575000000000001	72	590	4	24	13	8	0	1	8	0	0	8.79455711903287	
i 1	57.241571428571426	0.2525	77	906	4	2	6	16	0	1	16	0	0	4.0	
i 1	57.25200680272109	0.7575000000000001	74	906	5	5	9	8	0	-1	8	0	0	9.948905943535717	
i 1	57.25762585034013	0.7575000000000001	73	1172	2	20	12	16	0	1	16	0	0	0.7587699775925509	
i 1	57.2680612244898	0.2525	71	203	7	5	14	2	0	-1	2	0	0	9.948905943535717	
i 1	57.483544217687076	3.2825	71	590	6	5	5	2	0	-2	2	0	0	9.948905943535717	
i 1	57.49558503401361	0.2525	74	203	5	4	8	17	0	1	17	0	0	4.0	
i 1	57.743979591836734	0.2525	74	203	5	5	9	2	0	-2	2	0	0	9.948905943535717	
i 1	57.747190476190475	0.7575000000000001	73	203	1	24	16	17	0	2	17	0	0	4.758769977592551	
i 1	57.75040136054422	2.2725	75	906	4	1	3	2	0	1	2	0	0	7.794557119032869	
i 1	57.985952380952384	0.2525	73	590	2	24	7	16	0	1	16	0	0	4.758769977592551	
i 1	57.991571428571426	0.2525	71	590	6	5	7	2	0	-1	2	0	0	9.948905943535717	
i 1	57.997190476190475	0.2525	76	906	2	20	3	17	0	1	17	0	0	0.7587699775925509	
i 1	58.00120408163265	0.2525	72	906	4	1	7	2	0	-2	2	0	0	7.794557119032869	
i 1	58.01485034013606	0.2525	73	906	2	20	1	16	0	1	16	0	0	0.7587699775925509	
i 1	58.01725850340136	0.2525	71	1172	6	5	12	8	0	-1	8	0	0	9.948905943535717	
i 1	58.019666666666666	1.01	73	203	1	20	9	16	0	1	16	0	0	0.7587699775925509	
i 1	58.230333333333334	0.505	74	1172	4	9	8	16	0	1	16	0	0	3.0	
i 1	58.233544217687076	0.2525	76	1172	2	20	6	16	0	2	16	0	0	0.7587699775925509	
i 1	58.23514965986394	0.7575000000000001	72	590	4	24	1	8	0	1	8	0	0	8.79455711903287	
i 1	58.2431768707483	0.505	73	203	1	24	8	17	0	2	17	0	0	4.758769977592551	
i 1	58.48996598639456	0.505	71	590	6	5	7	2	0	-1	2	0	0	9.948905943535717	
i 1	58.4931768707483	0.2525	74	906	5	5	4	8	0	-1	8	0	0	9.948905943535717	
i 1	58.50040136054422	0.2525	72	906	4	1	11	2	0	-2	2	0	0	7.794557119032869	
i 1	58.51324489795918	0.7575000000000001	76	1172	2	20	5	16	0	2	16	0	0	0.7587699775925509	
i 1	58.741571428571426	0.2525	73	590	2	24	4	17	0	2	17	0	0	4.758769977592551	
i 1	58.74638775510204	0.2525	75	1172	5	1	3	2	0	-2	2	0	0	7.794557119032869	
i 1	58.74959863945578	2.2725	73	203	1	24	16	17	0	2	17	0	0	4.758769977592551	
i 1	58.756020408163266	2.2725	77	906	4	2	4	17	0	2	17	0	0	4.0	
i 1	58.7568231292517	0.7575000000000001	76	906	2	20	13	16	0	1	16	0	0	0.7587699775925509	
i 1	58.761639455782316	0.505	71	1172	6	5	15	8	0	-2	8	0	0	9.948905943535717	
i 1	58.766455782312924	0.7575000000000001	76	906	2	20	3	17	0	1	17	0	0	0.7587699775925509	
i 1	58.99558503401361	0.2525	77	1172	5	9	9	17	0	2	17	0	0	3.0	
i 1	58.99959863945578	0.2525	74	906	5	5	5	8	0	-1	8	0	0	9.948905943535717	
i 1	59.239163265306125	0.505	75	203	4	1	10	2	0	1	2	0	0	7.794557119032869	
i 1	59.24076870748299	0.505	77	906	4	2	8	16	0	1	16	0	0	4.0	
i 1	59.24237414965987	0.505	71	1172	6	5	11	8	0	-1	8	0	0	9.948905943535717	
i 1	59.25200680272109	0.2525	72	906	4	1	6	2	0	-2	2	0	0	7.794557119032869	
i 1	59.25521768707483	0.2525	74	203	5	5	6	2	0	-2	2	0	0	9.948905943535717	
i 1	59.264047619047616	1.7675	73	1172	2	24	4	17	0	1	17	0	0	4.758769977592551	
i 1	59.48113605442177	0.2525	74	590	4	4	2	16	0	2	16	0	0	4.0	
i 1	59.488360544217684	1.5150000000000001	72	590	4	1	4	2	0	-2	2	0	0	7.794557119032869	
i 1	59.497190476190475	0.2525	76	1172	2	20	3	17	0	2	17	0	0	0.7587699775925509	
i 1	59.502809523809525	0.7575000000000001	76	1172	2	20	1	16	0	2	16	0	0	0.7587699775925509	
i 1	59.73113605442177	0.2525	75	1172	5	1	9	2	0	-2	2	0	0	7.794557119032869	
i 1	59.73113605442177	0.2525	74	203	5	4	15	17	0	1	17	0	0	4.0	
i 1	59.735952380952384	0.2525	74	906	5	5	12	8	0	-1	8	0	0	9.948905943535717	
i 1	59.75441496598639	0.505	74	203	5	5	2	2	0	-2	2	0	0	9.948905943535717	
i 1	59.756020408163266	0.2525	74	590	4	3	13	17	0	2	17	0	0	4.0	
i 1	59.997190476190475	0.505	75	1172	5	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	60.00923129251701	0.2525	72	203	4	24	9	2	0	-2	2	0	0	8.79455711903287	
i 1	60.01244217687075	1.01	77	906	4	2	5	16	0	1	16	0	0	4.0	
i 1	60.014047619047616	0.505	71	1172	6	5	2	8	0	-2	8	0	0	9.948905943535717	
i 1	60.016455782312924	1.01	63	906	5	17	15	16	0	2	16	0	0	3.506464741742853	
i 1	60.230333333333334	0.2525	73	906	2	20	13	16	0	2	16	0	0	0.7587699775925509	
i 1	60.24076870748299	0.7575000000000001	74	906	5	5	8	8	0	-1	8	0	0	9.948905943535717	
i 1	60.24799319727891	0.7575000000000001	75	906	4	1	13	2	0	1	2	0	0	7.794557119032869	
i 1	60.26485034013606	0.2525	73	906	2	20	2	16	0	1	16	0	0	0.7587699775925509	
i 1	60.48113605442177	0.2525	71	203	5	5	10	2	0	-1	2	0	0	9.948905943535717	
i 1	60.48996598639456	0.505	73	1172	2	20	6	17	0	2	17	0	0	0.7587699775925509	
i 1	60.49799319727891	0.505	73	1172	2	20	2	16	0	1	16	0	0	0.7587699775925509	
i 1	60.51725850340136	0.505	72	906	4	1	5	2	0	-2	2	0	0	7.794557119032869	
i 1	60.519666666666666	0.505	73	203	1	24	10	17	0	252	17	307	0	4.758769977592551	
i 1	60.73274149659864	0.2525	71	590	5	5	15	2	0	-1	2	0	0	9.948905943535717	
i 1	60.74558503401361	0.2525	71	1172	6	5	15	8	0	-1	8	0	0	9.948905943535717	
i 1	60.980333333333334	8.08	63	200	6	25	15	1	0	1	1	0	0	0.39147284124284637	
i 1	60.980333333333334	23.23	63	698	3	27	15	1	0	2	1	0	0	12.738040549334222	
i 1	60.985952380952384	1.7675	72	698	4	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	60.985952380952384	5.05	61	698	5	25	7	16	0	1	16	0	0	0.39147284124284637	
i 1	60.99076870748299	0.2525	72	200	4	24	11	8	0	-2	8	0	0	8.79455711903287	
i 1	60.991571428571426	1.7675	74	698	4	2	7	17	0	2	17	0	0	4.0	
i 1	60.99237414965987	3.535	73	1084	1	24	5	17	0	1	17	0	0	4.758769977592551	
i 1	60.9931768707483	1.01	74	698	5	5	14	2	0	-2	2	0	0	9.948905943535717	
i 1	60.99638775510204	20.2	61	698	3	27	1	16	0	2	16	0	0	12.738040549334222	
i 1	60.997190476190475	0.2525	76	1084	1	20	2	17	0	2	17	0	0	0.7587699775925509	
i 1	60.99879591836735	0.7575000000000001	74	200	4	4	13	16	0	2	16	0	0	4.0	
i 1	61.00200680272109	2.02	63	698	5	25	4	1	0	2	1	0	0	0.39147284124284637	
i 1	61.00521768707483	0.2525	75	200	4	1	5	2	0	1	2	0	0	7.794557119032869	
i 1	61.006020408163266	20.2	61	698	5	17	14	1	0	2	1	0	0	3.506464741742853	
i 1	61.008428571428574	14.14	61	1084	4	26	15	1	0	2	1	0	0	0.39147284124284637	
i 1	61.011639455782316	1.7675	71	200	5	5	6	8	0	-2	8	0	0	9.948905943535717	
i 1	61.01324489795918	17.17	63	1084	4	26	14	16	0	1	16	0	0	0.39147284124284637	
i 1	61.014047619047616	0.2525	76	1084	1	20	4	17	0	2	17	0	0	0.7587699775925509	
i 1	61.01565306122449	11.11	61	200	6	25	12	16	0	2	16	0	0	0.39147284124284637	
i 1	61.01565306122449	0.505	71	1084	5	5	8	2	0	-2	2	0	0	9.948905943535717	
i 1	61.230333333333334	0.2525	76	698	2	20	15	17	0	1	17	0	0	0.7587699775925509	
i 1	61.260836734693875	0.2525	75	698	4	1	12	8	0	-2	8	0	0	7.794557119032869	
i 1	61.264047619047616	0.2525	73	698	2	20	6	16	0	2	16	0	0	0.7587699775925509	
i 1	61.2680612244898	0.2525	72	698	3	24	3	2	0	-2	2	0	0	8.79455711903287	
i 1	61.48434693877551	0.2525	71	698	4	5	16	8	0	-1	8	0	0	9.948905943535717	
i 1	61.488360544217684	0.2525	73	1084	1	20	10	17	0	2	17	0	0	0.7587699775925509	
i 1	61.489163265306125	0.2525	73	1084	1	20	10	17	0	2	17	0	0	0.7587699775925509	
i 1	61.5068231292517	0.7575000000000001	75	1084	4	1	12	2	0	-2	2	0	0	7.794557119032869	
i 1	61.511639455782316	0.2525	77	698	4	2	4	16	0	1	16	0	0	4.0	
i 1	61.73675510204082	0.7575000000000001	74	1084	3	9	11	16	0	1	16	0	0	3.0	
i 1	61.75120408163265	0.505	73	698	2	20	1	17	0	2	17	0	0	0.7587699775925509	
i 1	61.7568231292517	0.2525	72	200	4	24	7	8	0	-2	8	0	0	8.79455711903287	
i 1	61.76003401360544	0.505	74	1084	3	9	5	17	0	2	17	0	0	3.0	
i 1	61.764047619047616	0.505	71	1084	5	5	5	2	0	-2	2	0	0	9.948905943535717	
i 1	61.766455782312924	0.505	76	698	2	20	1	16	0	2	16	0	0	0.7587699775925509	
i 1	61.985952380952384	0.2525	71	200	6	5	15	2	0	-1	2	0	0	9.948905943535717	
i 1	62.00361224489796	1.01	75	200	4	1	3	2	0	1	2	0	0	7.794557119032869	
i 1	62.239163265306125	0.7575000000000001	77	698	4	2	1	16	0	1	16	0	0	4.0	
i 1	62.24638775510204	0.2525	72	698	3	1	16	2	0	1	2	0	0	7.794557119032869	
i 1	62.24879591836735	0.505	76	1084	1	20	9	16	0	2	16	0	0	0.7587699775925509	
i 1	62.24959863945578	0.505	76	1084	1	20	4	16	0	2	16	0	0	0.7587699775925509	
i 1	62.2568231292517	1.7675	74	698	5	5	14	2	0	-1	2	0	0	9.948905943535717	
i 1	62.26485034013606	0.2525	71	698	4	5	16	2	0	-1	2	0	0	9.948905943535717	
i 1	62.49478231292517	2.02	74	698	5	5	6	2	0	-2	2	0	0	9.948905943535717	
i 1	62.510836734693875	0.2525	74	200	4	3	10	17	0	1	17	0	0	4.0	
i 1	62.519666666666666	1.2625	72	200	4	24	2	8	0	-2	8	0	0	8.79455711903287	
i 1	62.74076870748299	0.2525	72	698	3	24	2	2	0	-2	2	0	0	8.79455711903287	
i 1	62.74478231292517	0.505	74	200	4	4	11	16	0	2	16	0	0	4.0	
i 1	62.75120408163265	0.2525	76	698	2	20	2	17	0	1	17	0	0	0.7587699775925509	
i 1	62.752809523809525	0.2525	71	698	4	5	6	2	0	-1	2	0	0	9.948905943535717	
i 1	62.75361224489796	0.2525	76	698	2	20	7	16	0	1	16	0	0	0.7587699775925509	
i 1	62.756020408163266	0.2525	74	1084	3	9	10	17	0	2	17	0	0	3.0	
i 1	62.985952380952384	0.505	72	1084	4	1	1	8	0	-2	8	0	0	7.794557119032869	
i 1	62.98755782312925	0.505	74	200	4	3	3	17	0	1	17	0	0	4.0	
i 1	62.988360544217684	0.2525	71	1084	5	5	7	2	0	-2	2	0	0	9.948905943535717	
i 1	62.9931768707483	12.120000000000001	63	698	5	25	16	1	0	2	1	0	0	0.39147284124284637	
i 1	62.99558503401361	21.21	61	698	5	17	2	1	0	1	1	0	0	3.506464741742853	
i 1	63.00521768707483	0.2525	75	1084	3	1	14	2	0	-2	2	0	0	7.794557119032869	
i 1	63.006020408163266	1.2625	77	698	6	2	6	16	0	1	16	0	0	4.0	
i 1	63.008428571428574	0.2525	73	1084	2	20	12	16	0	1	16	0	0	0.7587699775925509	
i 1	63.008428571428574	0.2525	76	1084	1	20	1	17	0	2	17	0	0	0.7587699775925509	
i 1	63.23514965986394	0.2525	74	698	2	3	3	16	0	1	16	0	0	4.0	
i 1	63.2568231292517	3.7875	75	200	4	1	3	2	0	1	2	0	0	7.794557119032869	
i 1	63.493979591836734	0.2525	74	1084	3	9	16	16	0	1	16	0	0	3.0	
i 1	63.49879591836735	0.2525	73	1084	2	20	1	16	0	2	16	0	0	0.7587699775925509	
i 1	63.50120408163265	0.2525	74	1084	3	9	2	17	0	2	17	0	0	3.0	
i 1	63.51003401360544	0.2525	73	1084	1	20	7	16	0	1	16	0	0	0.7587699775925509	
i 1	63.73675510204082	1.01	74	200	4	3	9	17	0	1	17	0	0	4.0	
i 1	63.738360544217684	0.2525	72	1084	4	1	12	8	0	-2	8	0	0	7.794557119032869	
i 1	63.73996598639456	0.2525	72	698	3	24	14	2	0	-2	2	0	0	8.79455711903287	
i 1	63.74237414965987	0.505	76	698	2	20	7	17	0	1	17	0	0	0.7587699775925509	
i 1	63.74558503401361	2.2725	74	200	4	4	12	16	0	2	16	0	0	4.0	
i 1	63.74799319727891	0.505	76	698	3	20	13	17	0	2	17	0	0	0.7587699775925509	
i 1	63.7568231292517	0.505	76	200	1	24	5	17	0	252	17	307	0	4.758769977592551	
i 1	63.98755782312925	3.2825	71	200	5	5	13	2	0	-1	2	0	0	9.948905943535717	
i 1	64.00842857142857	0.505	72	200	4	24	13	8	0	-2	8	0	0	8.79455711903287	
i 1	64.01645578231293	0.2525	75	1084	3	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	64.25521768707483	0.2525	73	1084	2	20	15	17	0	1	17	0	0	0.7587699775925509	
i 1	64.26725850340137	0.2525	77	698	4	4	14	17	0	1	17	0	0	4.0	
i 1	64.26966666666667	0.505	72	698	3	24	14	2	0	-2	2	0	0	8.79455711903287	
i 1	64.26966666666667	0.7575000000000001	73	1084	1	20	4	16	0	1	16	0	0	0.7587699775925509	
i 1	64.48354421768707	0.2525	72	698	3	1	7	2	0	1	2	0	0	7.794557119032869	
i 1	64.48354421768707	0.2525	74	1084	3	9	14	17	0	2	17	0	0	3.0	
i 1	64.7431768707483	0.7575000000000001	74	1084	3	9	2	16	0	1	16	0	0	3.0	
i 1	64.74879591836735	0.505	71	1084	5	5	4	2	0	-1	2	0	0	9.948905943535717	
i 1	64.74879591836735	1.01	73	1084	1	24	14	17	0	1	17	0	0	4.758769977592551	
i 1	64.75120408163265	0.2525	73	1084	2	20	9	17	0	1	17	0	0	0.7587699775925509	
i 1	64.759231292517	1.2625	72	698	4	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	64.76083673469388	0.505	74	698	2	3	5	16	0	1	16	0	0	4.0	
i 1	64.76645578231293	0.2525	72	1084	4	1	14	8	0	-2	8	0	0	7.794557119032869	
i 1	64.990768707483	0.505	73	698	2	20	5	16	0	1	16	0	0	0.7587699775925509	
i 1	65.00521768707483	0.505	73	698	3	20	8	17	0	1	17	0	0	0.7587699775925509	
i 1	65.24719047619048	0.2525	74	698	4	2	9	17	0	2	17	0	0	4.0	
i 1	65.48274149659863	0.2525	72	698	3	1	16	2	0	1	2	0	0	7.794557119032869	
i 1	65.48354421768707	0.505	71	1084	5	5	15	2	0	-2	2	0	0	9.948905943535717	
i 1	65.48755782312925	3.7875	76	698	1	24	12	16	0	252	16	307	0	4.758769977592551	
i 1	65.4931768707483	2.02	74	200	4	3	6	17	0	1	17	0	0	4.0	
i 1	65.49638775510203	0.2525	73	1084	2	20	7	16	0	2	16	0	0	0.7587699775925509	
i 1	65.51645578231293	0.2525	74	1084	3	9	10	17	0	2	17	0	0	3.0	
i 1	65.51886394557823	0.505	73	1084	1	20	8	16	0	1	16	0	0	0.7587699775925509	
i 1	65.74157142857143	0.7575000000000001	72	698	3	24	8	2	0	-2	2	0	0	8.79455711903287	
i 1	65.98033333333333	12.120000000000001	61	698	5	25	12	16	0	1	16	0	0	0.39147284124284637	
i 1	65.98274149659863	0.505	74	1084	3	9	5	16	0	1	16	0	0	3.0	
i 1	65.98595238095238	0.2525	74	1084	3	9	13	17	0	2	17	0	0	3.0	
i 1	65.98675510204082	0.2525	73	1084	1	24	8	17	0	1	17	0	0	4.758769977592551	
i 1	65.9955850340136	20.2	61	200	5	17	12	16	0	1	16	0	0	3.506464741742853	
i 1	66.00040136054422	0.2525	75	1084	3	1	12	2	0	-2	2	0	0	7.794557119032869	
i 1	66.00120408163265	1.7675	73	1084	2	20	4	16	0	1	16	0	0	0.7587699775925509	
i 1	66.23354421768707	0.7575000000000001	72	698	3	1	13	2	0	1	2	0	0	7.794557119032869	
i 1	66.2544149659864	0.2525	76	1084	1	20	15	17	0	2	17	0	0	0.7587699775925509	
i 1	66.259231292517	0.505	74	200	4	4	16	16	0	2	16	0	0	4.0	
i 1	66.49157142857143	0.2525	74	698	2	3	12	16	0	1	16	0	0	4.0	
i 1	66.49157142857143	0.2525	74	698	5	5	8	2	0	-1	2	0	0	9.948905943535717	
i 1	66.5068231292517	0.2525	71	698	4	5	9	8	0	-1	8	0	0	9.948905943535717	
i 1	66.51324489795918	2.525	72	698	4	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	66.73274149659863	2.02	74	698	5	5	12	2	0	-2	2	0	0	9.948905943535717	
i 1	66.740768707483	0.2525	74	698	6	2	7	17	0	2	17	0	0	4.0	
i 1	66.74478231292517	0.505	71	1084	5	5	2	2	0	-2	2	0	0	9.948905943535717	
i 1	66.759231292517	0.2525	74	1084	3	9	14	17	0	2	17	0	0	3.0	
i 1	66.98033333333333	1.7675	76	1084	1	20	16	17	0	2	17	0	0	0.7587699775925509	
i 1	66.99157142857143	0.7575000000000001	72	200	4	24	7	8	0	-2	8	0	0	8.79455711903287	
i 1	67.00120408163265	0.505	75	1084	3	1	2	2	0	-2	2	0	0	7.794557119032869	
i 1	67.00280952380952	1.5150000000000001	77	698	6	2	1	16	0	1	16	0	0	4.0	
i 1	67.01003401360545	0.2525	74	1084	3	9	4	16	0	1	16	0	0	3.0	
i 1	67.01003401360545	1.5150000000000001	73	1084	2	20	13	16	0	2	16	0	0	0.7587699775925509	
i 1	67.2319387755102	0.7575000000000001	71	698	4	5	10	8	0	-1	8	0	0	9.948905943535717	
i 1	67.240768707483	0.2525	71	1084	4	5	13	2	0	-1	2	0	0	9.948905943535717	
i 1	67.26485034013605	0.505	74	698	6	2	1	17	0	2	17	0	0	4.0	
i 1	67.49959863945578	0.2525	74	200	4	4	14	16	0	2	16	0	0	4.0	
i 1	67.49959863945578	0.2525	71	200	5	5	6	2	0	-1	2	0	0	9.948905943535717	
i 1	67.50762585034013	0.2525	72	698	3	1	14	2	0	1	2	0	0	7.794557119032869	
i 1	67.73113605442177	0.2525	72	1084	3	1	2	8	0	-2	8	0	0	7.794557119032869	
i 1	67.73434693877552	0.2525	74	1084	3	9	10	17	0	2	17	0	0	3.0	
i 1	67.73675510204082	0.2525	74	698	2	3	14	16	0	1	16	0	0	4.0	
i 1	67.74638775510203	0.505	75	1084	3	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	67.76725850340137	0.2525	73	1084	1	24	16	17	0	1	17	0	0	4.758769977592551	
i 1	67.98354421768707	0.7575000000000001	75	200	4	1	13	2	0	1	2	0	0	7.794557119032869	
i 1	68.0044149659864	1.2625	73	1084	2	20	1	16	0	1	16	0	0	0.7587699775925509	
i 1	68.01966666666667	1.01	74	200	4	3	6	17	0	1	17	0	0	4.0	
i 1	68.23514965986395	0.7575000000000001	74	698	5	5	3	2	0	-1	2	0	0	9.948905943535717	
i 1	68.23755782312925	0.2525	71	1084	5	5	7	2	0	-2	2	0	0	9.948905943535717	
i 1	68.23996598639455	0.2525	72	1084	3	1	11	8	0	-2	8	0	0	7.794557119032869	
i 1	68.25842857142857	0.2525	74	698	2	3	10	16	0	1	16	0	0	4.0	
i 1	68.48434693877552	0.2525	77	698	2	4	8	17	0	1	17	0	0	4.0	
i 1	68.49237414965987	2.02	71	200	5	5	3	8	0	-2	8	0	0	9.948905943535717	
i 1	68.49638775510203	0.505	74	200	4	4	5	16	0	2	16	0	0	4.0	
i 1	68.51485034013605	0.2525	75	1084	3	1	14	2	0	-2	2	0	0	7.794557119032869	
i 1	68.73033333333333	1.2625	73	1084	1	24	8	17	0	1	17	0	0	4.758769977592551	
i 1	68.73274149659863	0.505	71	1084	4	5	2	2	0	-1	2	0	0	9.948905943535717	
i 1	68.9819387755102	12.120000000000001	63	200	6	25	12	1	0	1	1	0	0	0.39147284124284637	
i 1	68.98996598639455	0.2525	73	1084	2	20	2	16	0	2	16	0	0	0.7587699775925509	
i 1	68.99237414965987	0.2525	72	698	2	1	10	2	0	1	2	0	0	7.794557119032869	
i 1	68.99799319727892	2.02	75	200	4	1	4	2	0	1	2	0	0	7.794557119032869	
i 1	69.00120408163265	17.17	63	200	5	17	11	16	0	2	16	0	0	3.506464741742853	
i 1	69.0044149659864	1.01	74	200	6	3	4	17	0	1	17	0	0	4.0	
i 1	69.00842857142857	0.505	74	698	5	5	11	2	0	-2	2	0	0	9.948905943535717	
i 1	69.01886394557823	0.505	72	698	6	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	69.24638775510203	0.505	73	698	3	20	3	16	0	1	16	0	0	0.7587699775925509	
i 1	69.25280952380952	0.505	72	200	4	24	15	8	0	-2	8	0	0	8.79455711903287	
i 1	69.25280952380952	0.505	74	698	5	5	9	2	0	-1	2	0	0	9.948905943535717	
i 1	69.25280952380952	0.2525	76	200	2	24	15	17	0	1	17	0	0	4.758769977592551	
i 1	69.48033333333333	1.7675	74	200	4	4	7	16	0	2	16	0	0	4.0	
i 1	69.49157142857143	0.505	72	698	3	24	16	2	0	-2	2	0	0	8.79455711903287	
i 1	69.51324489795918	0.505	71	698	4	5	10	8	0	-1	8	0	0	9.948905943535717	
i 1	69.51565306122448	0.2525	73	698	3	20	11	16	0	2	16	0	0	0.7587699775925509	
i 1	69.73595238095238	0.505	76	1084	2	20	1	16	0	1	16	0	0	0.7587699775925509	
i 1	69.740768707483	2.2725	76	1084	1	20	2	17	0	2	17	0	0	0.7587699775925509	
i 1	69.76003401360545	0.2525	75	1084	3	1	11	2	0	-2	2	0	0	7.794557119032869	
i 1	69.76003401360545	0.7575000000000001	73	1084	2	20	3	17	0	2	17	0	0	0.7587699775925509	
i 1	69.76645578231293	0.2525	71	200	5	5	4	2	0	-1	2	0	0	9.948905943535717	
i 1	69.98675510204082	0.2525	71	1084	4	5	6	2	0	-2	2	0	0	9.948905943535717	
i 1	70.00361224489797	1.01	74	698	5	5	1	2	0	-1	2	0	0	9.948905943535717	
i 1	70.009231292517	0.2525	72	200	4	24	12	8	0	-2	8	0	0	8.79455711903287	
i 1	70.01163945578232	0.2525	75	698	4	1	14	8	0	-2	8	0	0	7.794557119032869	
i 1	70.23514965986395	0.2525	72	698	2	1	13	2	0	1	2	0	0	7.794557119032869	
i 1	70.23836054421768	0.2525	72	698	6	1	7	2	0	-2	2	0	0	7.794557119032869	
i 1	70.23836054421768	0.505	74	200	6	3	5	17	0	1	17	0	0	4.0	
i 1	70.23916326530612	1.7675	74	698	5	5	5	2	0	-2	2	0	0	9.948905943535717	
i 1	70.25361224489797	0.7575000000000001	73	1084	1	24	11	17	0	1	17	0	0	4.758769977592551	
i 1	70.48755782312925	1.2625	72	200	4	24	3	8	0	-2	8	0	0	8.79455711903287	
i 1	70.49397959183673	0.2525	76	698	3	20	9	16	0	1	16	0	0	0.7587699775925509	
i 1	70.50280952380952	0.2525	74	698	2	3	14	16	0	1	16	0	0	4.0	
i 1	70.51886394557823	0.2525	71	1084	4	5	1	2	0	-1	2	0	0	9.948905943535717	
i 1	70.73354421768707	1.5150000000000001	74	698	6	2	13	17	0	2	17	0	0	4.0	
i 1	70.73996598639455	0.505	77	698	2	4	7	17	0	1	17	0	0	4.0	
i 1	70.75280952380952	0.505	76	1084	2	20	3	16	0	1	16	0	0	0.7587699775925509	
i 1	70.76966666666667	0.2525	71	1084	4	5	8	2	0	-2	2	0	0	9.948905943535717	
i 1	70.9819387755102	3.7875	71	200	5	5	12	2	0	-1	2	0	0	9.948905943535717	
i 1	70.99478231292517	0.2525	75	698	4	1	6	8	0	-2	8	0	0	7.794557119032869	
i 1	71.00521768707483	0.2525	72	698	2	1	9	2	0	1	2	0	0	7.794557119032869	
i 1	71.23595238095238	0.2525	71	1084	4	5	10	2	0	-2	2	0	0	9.948905943535717	
i 1	71.23916326530612	1.2625	75	200	4	1	1	2	0	1	2	0	0	7.794557119032869	
i 1	71.24157142857143	0.2525	74	698	2	3	13	16	0	1	16	0	0	4.0	
i 1	71.24799319727892	0.2525	72	698	6	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	71.25120408163265	0.2525	76	698	3	20	12	16	0	1	16	0	0	0.7587699775925509	
i 1	71.25200680272108	0.2525	74	200	6	3	11	17	0	1	17	0	0	4.0	
i 1	71.26163945578232	0.7575000000000001	76	698	3	20	7	17	0	1	17	0	0	0.7587699775925509	
i 1	71.4819387755102	0.2525	74	200	4	4	10	16	0	2	16	0	0	4.0	
i 1	71.49719047619048	1.7675	77	698	6	2	10	16	0	1	16	0	0	4.0	
i 1	71.51886394557823	0.2525	71	200	5	5	7	8	0	-2	8	0	0	9.948905943535717	
i 1	71.73916326530612	0.2525	73	1084	1	24	10	17	0	1	17	0	0	4.758769977592551	
i 1	71.75040136054422	0.2525	71	698	4	5	15	8	0	-1	8	0	0	9.948905943535717	
i 1	71.76324489795918	0.2525	77	698	2	4	12	17	0	1	17	0	0	4.0	
i 1	71.98033333333333	0.2525	76	698	3	20	8	17	0	1	17	0	0	3.336144960550463	
i 1	71.9819387755102	0.2525	72	698	2	24	14	2	0	-2	2	0	0	8.79455711903287	
i 1	71.98434693877552	0.7575000000000001	74	1084	3	9	8	17	0	2	17	0	0	3.0	
i 1	71.98836054421768	14.14	63	1084	4	18	5	1	0	2	1	0	0	3.506464741742853	
i 1	71.99157142857143	1.01	76	1084	1	20	14	17	0	2	17	0	0	3.336144960550463	
i 1	71.99799319727892	12.120000000000001	61	200	6	25	16	16	0	2	16	0	0	0.39147284124284637	
i 1	72.00120408163265	0.2525	76	200	3	20	1	17	0	1	17	0	0	3.336144960550463	
i 1	72.00762585034013	0.2525	72	200	4	24	5	8	0	-2	8	0	0	8.79455711903287	
i 1	72.01404761904762	0.505	71	1084	4	5	15	2	0	-2	2	0	0	9.948905943535717	
i 1	72.23113605442177	0.7575000000000001	76	1084	2	20	10	17	0	1	17	0	0	3.336144960550463	
i 1	72.24719047619048	3.0300000000000002	72	698	6	1	3	2	0	-2	2	0	0	7.794557119032869	
i 1	72.24719047619048	0.2525	71	698	4	5	15	8	0	-1	8	0	0	9.948905943535717	
i 1	72.24719047619048	0.7575000000000001	73	1084	2	20	7	16	0	1	16	0	0	3.336144960550463	
i 1	72.26404761904762	0.2525	74	698	2	3	8	16	0	1	16	0	0	4.0	
i 1	72.49397959183673	0.505	74	200	5	4	1	16	0	2	16	0	0	4.0	
i 1	72.49478231292517	0.2525	71	1084	4	5	11	2	0	-1	2	0	0	9.948905943535717	
i 1	72.4955850340136	1.01	72	200	4	24	16	8	0	-2	8	0	0	8.79455711903287	
i 1	72.50040136054422	0.2525	75	698	6	1	16	8	0	-2	8	0	0	7.794557119032869	
i 1	72.51645578231293	0.2525	71	200	5	5	14	8	0	-2	8	0	0	9.948905943535717	
i 1	72.73033333333333	0.505	72	698	2	1	7	2	0	1	2	0	0	7.794557119032869	
i 1	72.73354421768707	2.02	74	200	6	3	6	17	0	1	17	0	0	4.0	
i 1	72.98354421768707	0.2525	76	200	3	20	12	17	0	1	17	0	0	3.336144960550463	
i 1	72.98514965986395	0.505	76	698	3	20	14	17	0	1	17	0	0	3.336144960550463	
i 1	72.99638775510203	1.2625	71	1084	4	5	13	2	0	-1	2	0	0	9.948905943535717	
i 1	73.00040136054422	0.505	73	1084	1	24	10	17	0	1	17	0	0	7.336144960550463	
i 1	73.01324489795918	0.2525	74	698	6	2	13	17	0	2	17	0	0	4.0	
i 1	73.2319387755102	0.2525	75	1084	3	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	73.25842857142857	0.7575000000000001	74	1084	3	9	7	17	0	2	17	0	0	3.0	
i 1	73.26485034013605	0.2525	76	698	3	20	6	16	0	1	16	0	0	3.336144960550463	
i 1	73.2680612244898	0.505	77	698	2	4	8	17	0	1	17	0	0	4.0	
i 1	73.48755782312925	0.2525	72	1084	3	1	12	8	0	-2	8	0	0	7.794557119032869	
i 1	73.50280952380952	0.2525	75	698	6	1	7	8	0	-2	8	0	0	7.794557119032869	
i 1	73.5068231292517	0.2525	74	698	6	5	4	2	0	-1	2	0	0	9.948905943535717	
i 1	73.73434693877552	0.7575000000000001	75	200	4	1	2	2	0	1	2	0	0	7.794557119032869	
i 1	73.75120408163265	0.505	76	1084	1	20	9	17	0	2	17	0	0	3.336144960550463	
i 1	73.75361224489797	0.2525	74	200	5	4	12	16	0	2	16	0	0	4.0	
i 1	73.76163945578232	0.2525	73	698	3	20	12	17	0	2	17	0	0	3.336144960550463	
i 1	73.76565306122448	0.2525	73	698	3	20	14	16	0	2	16	0	0	3.336144960550463	
i 1	73.76886394557823	1.01	73	1084	1	24	1	17	0	1	17	0	0	7.336144960550463	
i 1	73.99478231292517	0.505	77	698	6	2	6	16	0	1	16	0	0	4.0	
i 1	74.00361224489797	0.2525	77	698	2	4	14	17	0	1	17	0	0	4.0	
i 1	74.009231292517	0.7575000000000001	76	698	1	24	11	16	0	1	16	0	0	7.336144960550463	
i 1	74.01645578231293	0.2525	74	698	5	5	4	2	0	-2	2	0	0	9.948905943535717	
i 1	74.23514965986395	1.2625	74	200	5	4	12	16	0	2	16	0	0	4.0	
i 1	74.23916326530612	0.2525	71	698	4	5	3	8	0	-1	8	0	0	9.948905943535717	
i 1	74.24237414965987	0.2525	71	1084	4	5	7	2	0	-2	2	0	0	9.948905943535717	
i 1	74.24799319727892	0.2525	75	1084	3	1	9	2	0	-2	2	0	0	7.794557119032869	
i 1	74.4955850340136	0.2525	72	1084	3	1	8	8	0	-2	8	0	0	7.794557119032869	
i 1	74.49799319727892	0.2525	74	698	2	3	1	16	0	1	16	0	0	4.0	
i 1	74.50842857142857	0.7575000000000001	73	1084	2	20	15	17	0	2	17	0	0	3.336144960550463	
i 1	74.51083673469388	0.7575000000000001	76	1084	1	20	4	17	0	2	17	0	0	3.336144960550463	
i 1	74.51565306122448	0.505	74	698	5	5	7	2	0	-2	2	0	0	9.948905943535717	
i 1	74.51886394557823	0.505	72	698	2	1	6	2	0	1	2	0	0	7.794557119032869	
i 1	74.73033333333333	0.2525	77	698	6	2	11	16	0	1	16	0	0	4.0	
i 1	74.73755782312925	0.2525	77	698	2	4	13	17	0	1	17	0	0	4.0	
i 1	74.98836054421768	0.2525	74	698	2	3	6	16	0	1	16	0	0	4.0	
i 1	74.99719047619048	11.11	61	1084	4	26	4	1	0	2	1	0	0	0.39147284124284637	
i 1	74.99719047619048	1.01	73	698	1	20	5	17	0	1	17	0	0	3.336144960550463	
i 1	74.99879591836735	11.11	61	1084	4	18	3	1	0	1	1	0	0	3.506464741742853	
i 1	75.00361224489797	1.7675	74	698	6	5	9	2	0	-2	2	0	0	9.948905943535717	
i 1	75.01244217687075	1.5150000000000001	75	200	6	1	14	2	0	1	2	0	0	7.794557119032869	
i 1	75.23755782312925	0.2525	73	1084	2	24	16	17	0	1	17	0	0	7.336144960550463	
i 1	75.26244217687075	2.2725	74	200	6	3	5	17	0	1	17	0	0	4.0	
i 1	75.49478231292517	0.505	72	200	4	24	10	8	0	-2	8	0	0	8.79455711903287	
i 1	75.51163945578232	0.2525	73	1084	2	20	16	17	0	2	17	0	0	3.336144960550463	
i 1	75.74397959183673	0.2525	74	200	5	4	6	16	0	2	16	0	0	4.0	
i 1	75.74638775510203	0.2525	74	1084	3	9	9	17	0	2	17	0	0	3.0	
i 1	75.75602040816327	0.2525	71	698	3	5	3	2	0	-1	2	0	0	9.948905943535717	
i 1	75.76886394557823	1.01	73	1084	2	24	4	17	0	1	17	0	0	7.336144960550463	
i 1	75.98514965986395	1.01	74	698	6	5	3	2	0	-1	2	0	0	9.948905943535717	
i 1	75.98836054421768	0.2525	77	698	4	2	4	16	0	1	16	0	0	4.0	
i 1	76.0180612244898	0.2525	77	698	2	4	12	17	0	1	17	0	0	4.0	
i 1	76.24157142857143	0.505	74	200	5	4	1	16	0	2	16	0	0	4.0	
i 1	76.24157142857143	1.01	76	698	1	20	8	16	0	2	16	0	0	3.336144960550463	
i 1	76.24478231292517	0.2525	73	1084	2	20	7	17	0	2	17	0	0	3.336144960550463	
i 1	76.2455850340136	1.7675	71	200	5	5	8	8	0	-2	8	0	0	9.948905943535717	
i 1	76.26163945578232	1.2625	72	698	6	1	8	2	0	-2	2	0	0	7.794557119032869	
i 1	76.49719047619048	0.505	74	1084	3	9	9	17	0	2	17	0	0	3.0	
i 1	76.7319387755102	0.2525	71	698	3	5	6	2	0	-1	2	0	0	9.948905943535717	
i 1	76.74719047619048	1.7675	77	698	4	2	1	16	0	1	16	0	0	4.0	
i 1	76.99478231292517	0.2525	71	1084	4	5	4	2	0	-2	2	0	0	9.948905943535717	
i 1	76.9955850340136	0.2525	74	200	5	4	10	16	0	2	16	0	0	4.0	
i 1	76.99879591836735	0.2525	75	698	6	1	9	8	0	-2	8	0	0	7.794557119032869	
i 1	77.00200680272108	1.5150000000000001	75	200	6	1	2	2	0	1	2	0	0	7.794557119032869	
i 1	77.00602040816327	0.2525	74	698	6	5	14	2	0	-2	2	0	0	9.948905943535717	
i 1	77.25361224489797	0.2525	71	698	3	5	2	8	0	-1	8	0	0	9.948905943535717	
i 1	77.2544149659864	0.2525	76	200	3	20	10	17	0	1	17	0	0	3.336144960550463	
i 1	77.25842857142857	0.2525	74	698	2	3	7	16	0	1	16	0	0	4.0	
i 1	77.26886394557823	2.02	74	698	6	5	1	2	0	-1	2	0	0	9.948905943535717	
i 1	77.50602040816327	0.2525	72	200	4	24	11	8	0	-2	8	0	0	8.79455711903287	
i 1	77.51404761904762	0.2525	73	698	1	20	10	16	0	2	16	0	0	3.336144960550463	
i 1	77.73113605442177	0.2525	72	698	2	1	11	2	0	1	2	0	0	7.794557119032869	
i 1	77.73755782312925	0.2525	72	698	2	24	6	2	0	-2	2	0	0	8.79455711903287	
i 1	77.7455850340136	0.2525	71	698	3	5	16	2	0	-1	2	0	0	9.948905943535717	
i 1	77.75762585034013	0.2525	74	698	6	2	11	17	0	2	17	0	0	4.0	
i 1	77.76725850340137	0.2525	74	698	2	3	8	16	0	1	16	0	0	4.0	
i 1	77.98514965986395	1.01	73	1084	2	24	4	17	0	1	17	0	0	7.336144960550463	
i 1	77.98595238095238	0.7575000000000001	76	1084	2	20	14	17	0	2	17	0	0	3.336144960550463	
i 1	77.98675510204082	1.01	74	200	6	3	9	17	0	1	17	0	0	4.0	
i 1	77.9931768707483	0.2525	72	698	5	1	1	2	0	-2	2	0	0	7.794557119032869	
i 1	77.9931768707483	8.08	61	698	3	19	12	16	0	1	16	0	0	3.506464741742853	
i 1	78.00521768707483	8.08	63	1084	4	26	12	16	0	1	16	0	0	0.39147284124284637	
i 1	78.0068231292517	0.2525	74	698	6	5	5	2	0	-2	2	0	0	9.948905943535717	
i 1	78.01163945578232	0.2525	73	698	3	20	3	17	0	2	17	0	0	3.336144960550463	
i 1	78.01886394557823	0.2525	71	200	5	5	7	2	0	-1	2	0	0	9.948905943535717	
i 1	78.24157142857143	1.7675	72	200	5	24	6	8	0	-2	8	0	0	8.79455711903287	
i 1	78.2455850340136	0.2525	73	1084	2	20	10	16	0	2	16	0	0	3.336144960550463	
i 1	78.25602040816327	0.2525	71	200	7	5	10	8	0	-2	8	0	0	9.948905943535717	
i 1	78.48354421768707	0.2525	74	1084	5	9	2	16	0	1	16	0	0	3.0	
i 1	78.48755782312925	0.2525	73	698	3	20	12	16	0	1	16	0	0	3.336144960550463	
i 1	78.50602040816327	0.2525	75	1084	3	1	4	2	0	-2	2	0	0	7.794557119032869	
i 1	78.51565306122448	0.505	72	698	5	1	1	2	0	-2	2	0	0	7.794557119032869	
i 1	78.51725850340137	2.2725	74	698	6	5	11	2	0	-2	2	0	0	9.948905943535717	
i 1	78.7455850340136	0.505	74	698	4	2	12	17	0	2	17	0	0	4.0	
i 1	78.74879591836735	1.5150000000000001	74	200	5	4	3	16	0	2	16	0	0	4.0	
i 1	78.74959863945578	0.2525	71	200	7	5	6	8	0	-2	8	0	0	9.948905943535717	
i 1	78.75120408163265	1.7675	76	1084	2	20	1	16	0	1	16	0	0	3.336144960550463	
i 1	78.76163945578232	0.2525	72	1084	3	1	16	8	0	-2	8	0	0	7.794557119032869	
i 1	78.99397959183673	0.505	71	200	5	5	5	2	0	-1	2	0	0	9.948905943535717	
i 1	79.01083673469388	0.2525	73	698	1	24	2	17	0	1	17	0	0	7.336144960550463	
i 1	79.01244217687075	0.2525	74	698	2	3	11	16	0	1	16	0	0	4.0	
i 1	79.2431768707483	0.7575000000000001	76	1084	2	20	9	17	0	2	17	0	0	3.336144960550463	
i 1	79.2431768707483	0.505	76	1084	2	20	6	17	0	2	17	0	0	3.336144960550463	
i 1	79.24879591836735	1.01	75	200	6	1	10	2	0	1	2	0	0	7.794557119032869	
i 1	79.25842857142857	0.2525	75	1084	3	1	2	2	0	-2	2	0	0	7.794557119032869	
i 1	79.26966666666667	0.505	74	1084	5	9	3	17	0	2	17	0	0	3.0	
i 1	79.48514965986395	0.2525	71	698	3	5	15	2	0	-1	2	0	0	9.948905943535717	
i 1	79.48836054421768	0.505	71	200	7	5	3	8	0	-2	8	0	0	9.948905943535717	
i 1	79.740768707483	0.2525	77	698	2	4	3	17	0	1	17	0	0	4.0	
i 1	79.74879591836735	0.2525	71	1084	4	5	16	2	0	-1	2	0	0	9.948905943535717	
i 1	79.75762585034013	1.01	72	698	5	1	15	2	0	-2	2	0	0	7.794557119032869	
i 1	79.7680612244898	0.2525	74	200	6	3	1	17	0	1	17	0	0	4.0	
i 1	79.98755782312925	0.2525	72	1084	3	1	5	8	0	-2	8	0	0	7.794557119032869	
i 1	79.990768707483	2.02	74	698	4	2	9	17	0	2	17	0	0	4.0	
i 1	79.99397959183673	0.2525	74	1084	5	9	12	16	0	1	16	0	0	3.0	
i 1	80.24237414965987	0.2525	74	698	6	5	1	2	0	-1	2	0	0	9.948905943535717	
i 1	80.25280952380952	0.2525	75	1084	3	1	1	2	0	-2	2	0	0	7.794557119032869	
i 1	80.48274149659863	0.7575000000000001	76	698	1	20	16	17	0	1	17	0	0	3.336144960550463	
i 1	80.49157142857143	1.7675	75	200	6	1	13	2	0	1	2	0	0	7.794557119032869	
i 1	80.4931768707483	0.505	71	200	5	5	14	2	0	-1	2	0	0	9.948905943535717	
i 1	80.5044149659864	0.505	72	698	2	24	7	2	0	-2	2	0	0	8.79455711903287	
i 1	80.50762585034013	0.2525	76	1084	2	20	14	17	0	2	17	0	0	3.336144960550463	
i 1	80.73916326530612	0.2525	74	200	6	3	8	17	0	1	17	0	0	4.0	
i 1	80.74157142857143	0.2525	74	698	6	5	16	2	0	-1	2	0	0	9.948905943535717	
i 1	80.7431768707483	0.2525	74	200	5	4	4	16	0	2	16	0	0	4.0	
i 1	80.74959863945578	0.2525	72	698	2	1	4	2	0	1	2	0	0	7.794557119032869	
i 1	80.98514965986395	0.505	77	698	2	4	7	17	0	1	17	0	0	4.0	
i 1	80.98595238095238	5.05	61	698	5	14	12	1	0	1	1	0	0	2.551638712202796	
i 1	80.98595238095238	5.05	63	698	3	19	13	1	0	1	1	0	0	3.506464741742853	
i 1	80.98836054421768	0.2525	72	698	5	1	12	2	0	-2	2	0	0	7.794557119032869	
i 1	80.98836054421768	1.7675	71	200	7	5	13	2	0	-1	2	0	0	9.948905943535717	
i 1	80.9955850340136	1.01	76	1084	2	20	2	17	0	2	17	0	0	3.336144960550463	
i 1	80.99799319727892	0.2525	72	1084	3	1	9	8	0	-2	8	0	0	7.794557119032869	
i 1	81.00521768707483	0.7575000000000001	76	1084	2	20	13	17	0	2	17	0	0	3.336144960550463	
i 1	81.009231292517	0.2525	71	698	3	5	11	8	0	-1	8	0	0	9.948905943535717	
i 1	81.01003401360545	5.05	61	698	6	17	1	1	0	2	1	0	0	3.506464741742853	
i 1	81.01485034013605	5.05	61	698	3	27	13	16	0	2	16	0	0	12.738040549334222	
i 1	81.2455850340136	0.2525	74	1084	5	9	13	16	0	1	16	0	0	3.0	
i 1	81.48033333333333	0.505	71	1084	4	5	1	2	0	-2	2	0	0	9.948905943535717	
i 1	81.49719047619048	0.2525	74	698	4	5	12	2	0	-1	2	0	0	9.948905943535717	
i 1	81.5044149659864	1.5150000000000001	77	698	4	2	12	16	0	1	16	0	0	4.0	
i 1	81.50521768707483	0.2525	74	200	4	3	9	17	0	1	17	0	0	4.0	
i 1	81.73675510204082	0.505	76	698	3	20	2	17	0	1	17	0	0	3.336144960550463	
i 1	81.74157142857143	0.505	73	1084	2	24	12	17	0	1	17	0	0	7.336144960550463	
i 1	81.76244217687075	0.505	75	698	5	1	13	8	0	-2	8	0	0	7.794557119032869	
i 1	81.98675510204082	0.2525	71	1084	4	5	3	2	0	-1	2	0	0	9.948905943535717	
i 1	81.98755782312925	0.2525	76	698	3	20	3	16	0	1	16	0	0	3.336144960550463	
i 1	81.98836054421768	1.2625	76	698	1	24	6	17	0	2	17	0	0	7.336144960550463	
i 1	82.00200680272108	0.2525	74	200	5	4	8	16	0	2	16	0	0	4.0	
i 1	82.23595238095238	0.7575000000000001	72	698	5	1	8	2	0	-2	2	0	0	7.794557119032869	
i 1	82.23595238095238	0.505	77	698	2	4	6	17	0	1	17	0	0	4.0	
i 1	82.24237414965987	2.525	73	1084	1	24	6	17	0	252	17	307	0	7.336144960550463	
i 1	82.2431768707483	0.505	74	1084	5	9	3	17	0	2	17	0	0	3.0	
i 1	82.24478231292517	0.2525	75	1084	5	1	8	2	0	-2	2	0	0	7.794557119032869	
i 1	82.24719047619048	0.2525	74	698	4	5	9	2	0	-1	2	0	0	9.948905943535717	
i 1	82.25200680272108	0.7575000000000001	76	1084	2	20	12	17	0	1	17	0	0	3.336144960550463	
i 1	82.26244217687075	1.5150000000000001	74	698	6	5	12	2	0	-2	2	0	0	9.948905943535717	
i 1	82.73514965986395	0.505	71	1084	4	5	5	2	0	-1	2	0	0	9.948905943535717	
i 1	82.74879591836735	0.2525	75	1084	5	1	14	2	0	-2	2	0	0	7.794557119032869	
i 1	82.75200680272108	0.2525	71	1084	4	5	3	2	0	-2	2	0	0	9.948905943535717	
i 1	82.75842857142857	1.2625	76	1084	2	20	9	17	0	2	17	0	0	3.336144960550463	
i 1	82.76404761904762	0.2525	72	698	2	1	16	2	0	1	2	0	0	7.794557119032869	
i 1	82.76404761904762	0.505	74	1084	5	9	8	16	0	1	16	0	0	3.0	
i 1	82.76645578231293	2.02	74	200	4	3	8	17	0	1	17	0	0	4.0	
i 1	82.98595238095238	0.2525	74	1084	5	9	11	17	0	2	17	0	0	3.0	
i 1	82.98836054421768	0.505	72	698	2	24	11	2	0	-2	2	0	0	8.79455711903287	
i 1	82.9931768707483	0.2525	73	698	3	20	12	16	0	2	16	0	0	3.336144960550463	
i 1	82.9955850340136	0.2525	73	698	3	20	13	16	0	2	16	0	0	3.336144960550463	
i 1	83.00200680272108	0.2525	71	698	3	5	15	2	0	-1	2	0	0	9.948905943535717	
i 1	83.00842857142857	1.01	75	200	6	1	2	2	0	1	2	0	0	7.794557119032869	
i 1	83.23595238095238	0.2525	74	200	5	4	13	16	0	2	16	0	0	4.0	
i 1	83.23595238095238	0.2525	74	698	5	3	16	16	0	1	16	0	0	4.0	
i 1	83.23996598639455	2.02	74	698	4	5	3	2	0	-1	2	0	0	9.948905943535717	
i 1	83.24397959183673	0.2525	73	1084	2	20	12	17	0	2	17	0	0	3.336144960550463	
i 1	83.24478231292517	0.7575000000000001	73	1084	2	20	6	16	0	2	16	0	0	3.336144960550463	
i 1	83.2568231292517	1.5150000000000001	73	698	1	24	5	17	0	252	17	307	0	7.336144960550463	
i 1	83.26565306122448	0.2525	72	698	5	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	83.48033333333333	0.2525	71	200	7	5	3	8	0	-2	8	0	0	9.948905943535717	
i 1	83.48836054421768	0.2525	72	200	5	24	9	8	0	-2	8	0	0	8.79455711903287	
i 1	83.490768707483	0.2525	75	1084	5	1	9	2	0	-2	2	0	0	7.794557119032869	
i 1	83.7319387755102	2.02	72	698	5	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	83.73514965986395	1.01	76	698	1	20	14	16	0	2	16	0	0	3.336144960550463	
i 1	83.73996598639455	0.2525	74	1084	5	9	9	17	0	2	17	0	0	3.0	
i 1	83.75521768707483	0.505	71	1084	4	5	12	2	0	-2	2	0	0	9.948905943535717	
i 1	83.76645578231293	0.2525	74	698	5	3	16	16	0	1	16	0	0	4.0	
i 1	83.99959863945578	2.02	61	698	5	13	15	1	0	1	1	0	0	0.16369957879808614	
i 1	84.0068231292517	0.7575000000000001	73	698	1	20	11	17	0	2	17	0	0	3.336144960550463	
i 1	84.01565306122448	2.02	61	698	6	17	1	1	0	1	1	0	0	3.506464741742853	
i 1	84.01725850340137	2.02	63	698	3	27	10	1	0	2	1	0	0	12.738040549334222	
i 1	84.01966666666667	0.505	74	698	4	2	3	17	0	2	17	0	0	4.0	
i 1	84.23354421768707	0.2525	71	200	7	5	15	8	0	-2	8	0	0	9.948905943535717	
i 1	84.23755782312925	1.5150000000000001	74	200	4	4	13	16	0	2	16	0	0	4.0	
i 1	84.24397959183673	0.2525	71	200	7	5	4	2	0	-1	2	0	0	9.948905943535717	
i 1	84.259231292517	0.2525	75	1084	5	1	11	2	0	-2	2	0	0	7.794557119032869	
i 1	84.26565306122448	0.7575000000000001	72	1084	5	1	2	8	0	-2	8	0	0	7.794557119032869	
i 1	84.48996598639455	0.2525	71	1084	6	5	8	2	0	-1	2	0	0	9.948905943535717	
i 1	84.5044149659864	0.2525	71	698	3	5	3	8	0	-1	8	0	0	9.948905943535717	
i 1	84.73354421768707	0.2525	74	1084	5	9	7	17	0	2	17	0	0	3.0	
i 1	84.73675510204082	0.2525	76	200	3	20	11	16	0	2	16	0	0	3.336144960550463	
i 1	84.73916326530612	0.2525	74	698	4	5	6	2	0	-2	2	0	0	9.948905943535717	
i 1	84.76725850340137	0.505	76	698	1	24	2	17	0	2	17	0	0	7.336144960550463	
i 1	84.7680612244898	0.2525	73	1084	2	24	13	17	0	1	17	0	0	7.336144960550463	
i 1	84.98916326530612	0.2525	74	698	4	2	12	17	0	2	17	0	0	4.0	
i 1	84.98916326530612	1.01	76	1084	2	20	10	17	0	2	17	0	0	3.336144960550463	
i 1	84.99959863945578	1.01	71	200	7	5	11	8	0	-2	8	0	0	9.948905943535717	
i 1	85.00200680272108	0.2525	72	698	2	1	13	2	0	1	2	0	0	7.794557119032869	
i 1	85.00602040816327	1.01	73	1084	2	20	8	16	0	1	16	0	0	3.336144960550463	
i 1	85.0068231292517	0.2525	73	698	1	20	8	16	0	1	16	0	0	3.336144960550463	
i 1	85.01083673469388	0.505	74	698	5	3	14	16	0	1	16	0	0	4.0	
i 1	85.01404761904762	0.2525	75	1084	5	1	15	2	0	-2	2	0	0	7.794557119032869	
i 1	85.23113605442177	0.2525	74	698	4	5	3	2	0	-2	2	0	0	9.948905943535717	
i 1	85.25602040816327	0.7575000000000001	72	200	5	24	6	8	0	-2	8	0	0	8.79455711903287	
i 1	85.2680612244898	0.505	73	698	1	20	2	17	0	2	17	0	0	3.336144960550463	
i 1	85.48755782312925	0.505	74	200	4	3	1	17	0	1	17	0	0	4.0	
i 1	85.49157142857143	0.2525	75	200	5	1	14	2	0	1	2	0	0	7.794557119032869	
i 1	85.50762585034013	0.2525	74	1084	5	9	3	17	0	2	17	0	0	3.0	
i 1	85.51324489795918	0.2525	71	698	3	5	10	8	0	-1	8	0	0	9.948905943535717	
i 1	85.51404761904762	0.505	71	698	3	5	8	2	0	-1	2	0	0	9.948905943535717	
i 1	85.73836054421768	0.2525	72	698	2	1	6	2	0	1	2	0	0	7.794557119032869	
i 1	85.75842857142857	0.2525	74	698	5	3	9	16	0	1	16	0	0	4.0	
i 1	85.98675510204082	4.04	63	202	5	26	3	1	0	2	1	0	0	0.39147284124284637	
i 1	85.98755782312925	0.2525	74	904	4	2	2	17	0	2	17	0	0	4.0	
i 1	85.98916326530612	3.0300000000000002	74	588	6	5	4	8	0	-2	8	0	0	9.948905943535717	
i 1	85.98996598639455	4.04	61	904	6	17	13	16	0	2	16	0	0	3.506464741742853	
i 1	85.99237414965987	1.01	75	904	5	1	9	2	0	1	2	0	0	7.794557119032869	
i 1	85.99237414965987	4.04	61	202	4	27	9	1	0	1	1	0	0	12.738040549334222	
i 1	85.99638775510203	2.02	74	588	4	3	8	16	0	1	16	0	0	4.0	
i 1	85.99879591836735	4.04	63	588	5	17	6	1	0	1	1	0	0	3.506464741742853	
i 1	85.99959863945578	4.04	63	904	5	14	5	16	0	1	16	0	0	2.551638712202796	
i 1	85.99959863945578	4.04	61	202	4	19	7	1	0	1	1	0	0	3.506464741742853	
i 1	86.00040136054422	0.2525	74	202	5	4	2	16	0	1	16	0	0	4.0	
i 1	86.00280952380952	4.04	61	202	5	18	5	16	0	1	16	0	0	3.506464741742853	
i 1	86.00280952380952	0.7575000000000001	73	202	3	20	8	16	0	2	16	0	0	3.336144960550463	
i 1	86.0044149659864	0.505	74	904	4	5	4	2	0	-1	2	0	0	9.948905943535717	
i 1	86.00521768707483	1.01	61	202	5	26	14	16	0	2	16	0	0	0.39147284124284637	
i 1	86.00602040816327	0.2525	74	588	6	5	15	8	0	-2	8	0	0	9.948905943535717	
i 1	86.00762585034013	0.7575000000000001	76	202	3	20	10	17	0	1	17	0	0	3.336144960550463	
i 1	86.009231292517	1.01	63	588	5	17	9	16	0	2	16	0	0	3.506464741742853	
i 1	86.01083673469388	4.04	61	904	5	13	14	16	0	1	16	0	0	0.16369957879808614	
i 1	86.01083673469388	4.04	63	202	5	18	1	1	0	1	1	0	0	3.506464741742853	
i 1	86.01083673469388	4.04	61	202	4	19	4	16	0	1	16	0	0	3.506464741742853	
i 1	86.01645578231293	4.04	61	202	4	27	14	16	0	1	16	0	0	12.738040549334222	
i 1	86.01966666666667	4.04	63	904	6	17	6	16	0	1	16	0	0	3.506464741742853	
i 1	86.24638775510203	0.2525	76	202	2	24	1	17	0	1	17	0	0	7.336144960550463	
i 1	86.49237414965987	0.2525	74	588	6	5	2	8	0	-2	8	0	0	9.948905943535717	
i 1	86.49397959183673	0.505	75	202	6	1	13	2	0	-2	2	0	0	7.794557119032869	
i 1	86.50842857142857	0.2525	75	904	5	1	8	2	0	1	2	0	0	7.794557119032869	
i 1	86.51003401360545	5.3025	76	202	1	24	9	17	0	252	17	307	0	7.336144960550463	
i 1	86.51404761904762	0.505	77	202	6	9	16	17	0	1	17	0	0	3.0	
i 1	86.73434693877552	0.2525	71	202	7	5	14	2	0	-1	2	0	0	9.948905943535717	
i 1	86.74879591836735	0.2525	73	202	3	20	2	17	0	2	17	0	0	3.336144960550463	
i 1	86.74879591836735	0.2525	76	202	3	24	5	16	0	1	16	0	0	7.336144960550463	
i 1	86.75521768707483	0.2525	74	202	6	3	9	16	0	2	16	0	0	4.0	
i 1	86.98675510204082	0.7575000000000001	75	904	6	1	2	2	0	1	2	0	0	7.794557119032869	
i 1	86.98675510204082	0.505	71	202	4	5	5	8	0	-1	8	0	0	9.948905943535717	
i 1	86.99959863945578	0.2525	77	904	4	2	13	16	0	2	16	0	0	4.0	
i 1	87.00280952380952	0.2525	74	904	4	2	1	17	0	2	17	0	0	4.0	
i 1	87.00521768707483	0.7575000000000001	73	202	3	20	3	16	0	2	16	0	0	3.336144960550463	
i 1	87.009231292517	0.505	76	202	3	20	3	17	0	1	17	0	0	3.336144960550463	
i 1	87.01485034013605	3.0300000000000002	63	588	6	17	15	16	0	2	16	0	0	3.506464741742853	
i 1	87.01565306122448	0.2525	72	588	4	24	7	2	0	-2	2	0	0	8.79455711903287	
i 1	87.0180612244898	3.0300000000000002	63	588	5	15	6	1	0	2	1	0	0	0.9596792899329893	
i 1	87.01966666666667	0.2525	71	202	7	5	15	2	0	-1	2	0	0	9.948905943535717	
i 1	87.2431768707483	0.7575000000000001	73	202	2	20	4	16	0	2	16	0	0	3.336144960550463	
i 1	87.25762585034013	0.2525	76	202	2	20	12	17	0	2	17	0	0	3.336144960550463	
i 1	87.25842857142857	1.2625	72	588	5	1	11	2	0	1	2	0	0	7.794557119032869	
i 1	87.26003401360545	0.2525	74	202	5	4	2	16	0	1	16	0	0	4.0	
i 1	87.48836054421768	0.2525	76	588	3	20	8	16	0	1	16	0	0	3.336144960550463	
i 1	87.49719047619048	1.5150000000000001	74	588	4	4	16	17	0	2	17	0	0	4.0	
i 1	87.50842857142857	0.505	71	904	4	5	15	2	0	-1	2	0	0	9.948905943535717	
i 1	87.73514965986395	0.505	74	904	4	2	14	17	0	2	17	0	0	4.0	
i 1	87.7455850340136	0.2525	74	588	4	5	9	8	0	-2	8	0	0	9.948905943535717	
i 1	87.75280952380952	0.2525	73	202	2	24	8	16	0	2	16	0	0	7.336144960550463	
i 1	87.76485034013605	0.505	75	202	6	1	12	2	0	-2	2	0	0	7.794557119032869	
i 1	87.98274149659863	0.2525	71	202	7	5	16	2	0	-1	2	0	0	9.948905943535717	
i 1	87.99237414965987	0.2525	71	202	7	5	8	2	0	-1	2	0	0	9.948905943535717	
i 1	87.99879591836735	1.7675	73	202	3	20	15	16	0	2	16	0	0	3.336144960550463	
i 1	88.00040136054422	1.7675	73	202	3	20	5	17	0	1	17	0	0	3.336144960550463	
i 1	88.2319387755102	0.2525	74	904	4	5	8	2	0	-1	2	0	0	9.948905943535717	
i 1	88.24638775510203	0.2525	74	202	5	4	10	16	0	1	16	0	0	4.0	
i 1	88.25361224489797	0.2525	72	202	3	24	14	2	0	1	2	0	0	8.79455711903287	
i 1	88.48033333333333	0.2525	74	904	4	2	6	17	0	2	17	0	0	4.0	
i 1	88.51163945578232	1.01	75	904	6	1	14	2	0	1	2	0	0	7.794557119032869	
i 1	88.5180612244898	0.7575000000000001	75	904	5	1	7	2	0	1	2	0	0	7.794557119032869	
i 1	88.76404761904762	0.2525	74	202	4	5	12	2	0	-1	2	0	0	9.948905943535717	
i 1	88.98033333333333	0.2525	72	202	3	24	10	2	0	1	2	0	0	8.79455711903287	
i 1	88.98434693877552	1.01	71	904	4	5	5	2	0	-1	2	0	0	9.948905943535717	
i 1	88.98514965986395	0.2525	71	202	7	5	2	2	0	-1	2	0	0	9.948905943535717	
i 1	89.00602040816327	1.2625	74	904	4	2	9	17	0	2	17	0	0	4.0	
i 1	89.25842857142857	0.2525	72	588	4	24	2	2	0	-2	2	0	0	8.79455711903287	
i 1	89.50361224489797	0.505	75	904	5	1	1	2	0	1	2	0	0	7.794557119032869	
i 1	89.51163945578232	0.505	72	588	5	1	16	2	0	1	2	0	0	7.794557119032869	
i 1	89.51163945578232	0.505	74	202	4	5	10	2	0	-1	2	0	0	9.948905943535717	
i 1	89.74397959183673	0.2525	72	202	6	1	13	2	0	-2	2	0	0	7.794557119032869	
i 1	89.74799319727892	0.505	76	202	3	24	3	16	0	1	16	0	0	7.336144960550463	
i 1	89.76485034013605	0.505	73	202	3	20	16	17	0	1	17	0	0	3.336144960550463	
i 1	89.98354421768707	1.5150000000000001	77	904	4	2	5	16	0	2	16	0	0	4.0	
i 1	89.98354421768707	5.8075	63	588	6	17	4	1	0	1	1	0	0	3.5064647417428527	
i 1	89.98514965986395	5.8075	63	904	6	17	13	16	0	1	16	0	0	3.5064647417428527	
i 1	89.98836054421768	5.8075	63	904	5	14	11	16	0	1	16	0	0	2.386960017480566	
i 1	89.98836054421768	5.8075	61	588	5	15	12	1	0	2	1	0	0	0.7950005952107598	
i 1	89.99237414965987	0.2525	72	202	5	24	7	2	0	1	2	0	0	8.72388007207531	
i 1	90.00040136054422	5.8075	63	588	5	15	10	1	0	2	1	0	0	0.7950005952107598	
i 1	90.00120408163265	0.2525	73	202	3	20	7	16	0	2	16	0	0	3.336144960550463	
i 1	90.00120408163265	0.7575000000000001	73	202	2	20	13	16	0	2	16	0	0	3.336144960550463	
i 1	90.00200680272108	0.2525	73	202	2	20	16	16	0	2	16	0	0	3.336144960550463	
i 1	90.00361224489797	3.0300000000000002	61	202	5	18	1	16	0	1	16	0	0	3.5064647417428527	
i 1	90.00361224489797	0.2525	73	202	3	20	10	17	0	1	17	0	0	3.336144960550463	
i 1	90.0044149659864	5.8075	61	202	4	19	2	16	0	1	16	0	0	3.5064647417428527	
i 1	90.00521768707483	5.8075	61	202	4	27	2	16	0	1	16	0	0	12.802460130804567	
i 1	90.0068231292517	5.8075	61	904	6	17	3	16	0	2	16	0	0	3.5064647417428527	
i 1	90.01003401360545	0.2525	75	904	6	1	9	2	0	1	2	0	0	7.72388007207531	
i 1	90.01083673469388	5.8075	63	202	5	18	3	1	0	1	1	0	0	3.5064647417428527	
i 1	90.01083673469388	3.0300000000000002	61	202	4	27	12	1	0	1	1	0	0	12.802460130804567	
i 1	90.01083673469388	4.04	71	904	4	5	1	2	0	-1	2	0	0	11.606964696238188	
i 1	90.01324489795918	5.8075	61	202	4	19	12	1	0	1	1	0	0	3.5064647417428527	
i 1	90.01485034013605	2.02	72	588	5	1	3	2	0	1	2	0	0	7.72388007207531	
i 1	90.01645578231293	5.8075	63	588	6	17	10	16	0	2	16	0	0	3.5064647417428527	
i 1	90.23916326530612	0.2525	73	588	3	20	7	17	0	2	17	0	0	3.336144960550463	
i 1	90.24719047619048	0.2525	74	588	4	4	9	17	0	2	17	0	0	4.0	
i 1	90.25040136054422	0.505	74	202	6	3	16	16	0	2	16	0	0	4.0	
i 1	90.48916326530612	0.7575000000000001	71	202	7	5	14	8	0	-1	8	0	0	11.606964696238188	
i 1	90.50120408163265	0.2525	76	202	2	24	2	16	0	2	16	0	0	7.336144960550463	
i 1	90.73274149659863	1.2625	73	202	3	20	11	16	0	2	16	0	0	3.336144960550463	
i 1	90.740768707483	0.2525	74	588	4	5	1	8	0	-2	8	0	0	11.606964696238188	
i 1	90.76244217687075	0.2525	74	588	4	3	2	16	0	1	16	0	0	4.0	
i 1	90.76485034013605	0.2525	72	202	6	1	11	2	0	-2	2	0	0	7.72388007207531	
i 1	90.76966666666667	0.7575000000000001	73	202	3	20	1	17	0	1	17	0	0	3.336144960550463	
i 1	91.01886394557823	0.505	75	904	6	1	16	2	0	1	2	0	0	7.72388007207531	
i 1	91.01966666666667	0.2525	77	202	4	9	13	17	0	1	17	0	0	3.0	
i 1	91.2319387755102	0.2525	71	202	7	5	15	2	0	-1	2	0	0	11.606964696238188	
i 1	91.240768707483	3.535	74	588	4	3	14	16	0	1	16	0	0	4.0	
i 1	91.24478231292517	1.2625	75	202	5	1	10	2	0	-2	2	0	0	7.72388007207531	
i 1	91.24719047619048	0.2525	76	202	2	24	7	16	0	2	16	0	0	7.336144960550463	
i 1	91.49719047619048	0.2525	74	588	4	5	8	8	0	-2	8	0	0	11.606964696238188	
i 1	91.49799319727892	0.2525	77	202	4	9	10	17	0	1	17	0	0	3.0	
i 1	91.49879591836735	0.2525	73	904	3	20	8	16	0	1	16	0	0	3.336144960550463	
i 1	91.7319387755102	0.7575000000000001	76	202	2	24	5	17	0	1	17	0	0	7.336144960550463	
i 1	91.73514965986395	1.7675	72	588	4	24	10	2	0	-2	2	0	0	8.72388007207531	
i 1	91.73755782312925	0.2525	76	202	3	24	14	16	0	1	16	0	0	7.336144960550463	
i 1	91.73916326530612	0.7575000000000001	73	202	2	20	11	16	0	1	16	0	0	3.336144960550463	
i 1	91.75280952380952	0.2525	74	904	4	2	11	17	0	2	17	0	0	4.0	
i 1	91.76485034013605	0.2525	76	202	3	20	14	17	0	1	17	0	0	3.336144960550463	
i 1	91.99959863945578	0.505	74	904	4	5	6	2	0	-1	2	0	0	11.606964696238188	
i 1	92.01404761904762	0.2525	74	588	4	5	4	8	0	-2	8	0	0	11.606964696238188	
i 1	92.49478231292517	0.2525	74	588	4	5	1	8	0	-2	8	0	0	11.606964696238188	
i 1	92.49959863945578	0.2525	72	202	6	1	4	2	0	-2	2	0	0	7.72388007207531	
i 1	92.50602040816327	0.2525	73	588	3	24	9	16	0	1	16	0	0	7.336144960550463	
i 1	92.51003401360545	0.2525	76	202	3	24	11	16	0	1	16	0	0	7.336144960550463	
i 1	92.73033333333333	0.505	75	202	5	1	6	2	0	-2	2	0	0	7.72388007207531	
i 1	92.73113605442177	0.2525	76	202	3	20	14	16	0	2	16	0	0	3.336144960550463	
i 1	92.73113605442177	0.2525	73	202	3	20	12	16	0	2	16	0	0	3.336144960550463	
i 1	92.73595238095238	0.2525	71	202	7	5	7	2	0	-1	2	0	0	11.606964696238188	
i 1	92.98113605442177	2.7775	63	202	5	16	5	1	0	1	1	0	0	1.5909803063456631	
i 1	93.0180612244898	2.7775	61	202	5	18	11	16	0	1	16	0	0	3.5064647417428527	
i 1	93.2455850340136	0.2525	73	202	2	20	4	17	0	1	17	0	0	6.439844327211144	
i 1	93.24638775510203	0.2525	76	202	2	24	9	17	0	1	17	0	0	10.439844327211144	
i 1	93.25842857142857	0.2525	72	202	5	1	6	2	0	1	2	0	0	7.72388007207531	
i 1	93.48354421768707	1.01	72	588	6	1	8	2	0	1	2	0	0	7.72388007207531	
i 1	93.49237414965987	0.7575000000000001	76	202	3	20	8	17	0	1	17	0	0	6.439844327211144	
i 1	93.4931768707483	0.2525	75	904	6	1	16	2	0	1	2	0	0	7.72388007207531	
i 1	93.49959863945578	0.7575000000000001	73	202	3	20	12	16	0	2	16	0	0	6.439844327211144	
i 1	93.5044149659864	0.2525	77	904	6	2	5	16	0	2	16	0	0	4.0	
i 1	93.51645578231293	1.7675	76	202	1	24	12	17	0	252	17	307	0	10.439844327211144	
i 1	93.76565306122448	0.505	74	588	4	4	8	17	0	2	17	0	0	4.0	
i 1	93.98916326530612	1.7675	74	588	4	5	6	8	0	-2	8	0	0	11.606964696238188	
i 1	94.00280952380952	0.2525	71	202	7	5	15	2	0	-1	2	0	0	11.606964696238188	
i 1	94.25602040816327	0.2525	77	904	6	2	9	16	0	2	16	0	0	4.0	
i 1	94.2568231292517	1.01	73	202	2	24	11	16	0	2	16	0	0	10.439844327211144	
i 1	94.25762585034013	0.2525	72	588	4	24	15	2	0	-2	2	0	0	8.72388007207531	
i 1	94.26485034013605	1.01	73	202	2	20	9	16	0	2	16	0	0	6.439844327211144	
i 1	94.2680612244898	0.505	74	202	7	5	16	2	0	-1	2	0	0	11.606964696238188	
i 1	94.48033333333333	0.2525	74	202	4	9	9	17	0	1	17	0	0	3.0	
i 1	94.50602040816327	1.01	75	904	6	1	12	2	0	1	2	0	0	7.72388007207531	
i 1	94.73755782312925	0.2525	75	202	5	1	16	2	0	-2	2	0	0	7.72388007207531	
i 1	94.74638775510203	0.2525	71	904	4	5	9	2	0	-1	2	0	0	11.606964696238188	
i 1	94.75842857142857	1.01	77	904	6	2	4	16	0	2	16	0	0	4.0	
i 1	95.01324489795918	0.505	71	202	7	5	3	2	0	-1	2	0	0	11.606964696238188	
i 1	95.01645578231293	0.2525	72	202	5	1	4	2	0	1	2	0	0	7.72388007207531	
i 1	95.01886394557823	0.2525	74	202	3	3	8	16	0	2	16	0	0	4.0	
i 1	95.23675510204082	0.505	76	202	2	24	5	17	0	1	17	0	0	10.439844327211144	
i 1	95.23755782312925	0.505	74	202	4	9	8	17	0	1	17	0	0	3.0	
i 1	95.24799319727892	0.505	76	904	3	20	5	17	0	2	17	0	0	6.439844327211144	
i 1	95.25200680272108	0.505	72	202	5	1	5	2	0	-2	2	0	0	7.72388007207531	
i 1	95.48996598639455	0.2525	74	588	4	5	13	8	0	-2	8	0	0	11.606964696238188	
i 1	95.51565306122448	0.2525	72	588	6	1	14	2	0	1	2	0	0	7.72388007207531	
i 1	95.73514965986395	0.2525	63	904	5	14	11	16	0	1	16	0	0	2.386960017480566	
i 1	95.73675510204082	2.7775	61	202	4	19	2	16	0	1	16	0	0	3.5064647417428527	
i 1	95.73916326530612	2.7775	61	588	5	15	12	1	0	2	1	0	0	0.7950005952107598	
i 1	95.73996598639455	2.7775	63	588	6	17	10	16	0	2	16	0	0	3.5064647417428527	
i 1	95.74157142857143	0.2525	75	904	6	1	14	2	0	1	2	0	0	7.72388007207531	
i 1	95.74157142857143	2.7775	63	904	6	17	13	16	0	1	16	0	0	3.5064647417428527	
i 1	95.74157142857143	1.2625	76	202	3	24	16	16	0	1	16	0	0	10.439844327211144	
i 1	95.7431768707483	0.505	77	904	6	2	4	16	0	2	16	0	0	4.0	
i 1	95.7431768707483	0.2525	74	202	3	3	13	16	0	2	16	0	0	4.0	
i 1	95.74397959183673	0.2525	61	202	4	27	2	16	0	1	16	0	0	12.802460130804567	
i 1	95.74638775510203	2.7775	63	588	5	15	10	1	0	2	1	0	0	0.7950005952107598	
i 1	95.74879591836735	0.2525	63	202	5	18	3	1	0	1	1	0	0	3.5064647417428527	
i 1	95.74959863945578	2.7775	61	202	4	19	12	1	0	1	1	0	0	3.5064647417428527	
i 1	95.74959863945578	1.2625	76	202	3	20	1	17	0	1	17	0	0	6.439844327211144	
i 1	95.75200680272108	2.2725	72	588	6	1	14	2	0	1	2	0	0	7.72388007207531	
i 1	95.75280952380952	2.7775	63	588	6	17	4	1	0	1	1	0	0	3.5064647417428527	
i 1	95.75361224489797	0.2525	74	202	7	5	5	2	0	-1	2	0	0	11.606964696238188	
i 1	95.759231292517	15.4025	61	202	5	18	11	16	0	1	16	0	0	3.5064647417428527	
i 1	95.76083673469388	12.3725	63	202	5	16	5	1	0	1	1	0	0	1.5909803063456631	
i 1	95.76404761904762	2.7775	61	904	6	17	3	16	0	2	16	0	0	3.5064647417428527	
i 1	95.76404761904762	2.2725	74	588	4	5	6	8	0	-2	8	0	0	11.606964696238188	
i 1	95.98514965986395	0.2525	74	904	6	2	15	17	0	2	17	0	0	4.0	
i 1	95.99237414965987	15.15	63	202	5	18	4	1	0	1	1	0	0	3.5064647417428527	
i 1	95.9955850340136	0.2525	72	202	5	1	14	2	0	-2	2	0	0	7.72388007207531	
i 1	95.9955850340136	15.15	63	202	5	16	5	16	0	2	16	0	0	1.5909803063456631	
i 1	96.00842857142857	2.525	63	904	5	14	14	16	0	1	16	0	0	2.386960017480566	
i 1	96.24157142857143	0.2525	71	904	6	5	13	2	0	-1	2	0	0	11.606964696238188	
i 1	96.24397959183673	0.2525	74	202	4	9	3	17	0	1	17	0	0	3.0	
i 1	96.25280952380952	1.01	74	588	4	3	12	16	0	1	16	0	0	4.0	
i 1	96.50762585034013	0.505	74	202	6	5	2	2	0	-1	2	0	0	11.606964696238188	
i 1	96.5180612244898	0.505	74	904	6	2	4	17	0	2	17	0	0	4.0	
i 1	96.98514965986395	0.2525	76	202	2	20	5	16	0	1	16	0	0	6.439844327211144	
i 1	96.99478231292517	0.2525	71	202	6	5	3	8	0	-1	8	0	0	11.606964696238188	
i 1	97.0044149659864	0.2525	77	904	6	2	7	16	0	2	16	0	0	4.0	
i 1	97.00762585034013	0.2525	76	202	2	24	12	17	0	1	17	0	0	10.439844327211144	
i 1	97.23033333333333	0.2525	72	588	4	24	4	2	0	-2	2	0	0	8.72388007207531	
i 1	97.2319387755102	0.2525	76	202	3	24	8	16	0	1	16	0	0	10.439844327211144	
i 1	97.240768707483	0.2525	71	202	4	5	4	2	0	-1	2	0	0	11.606964696238188	
i 1	97.24397959183673	0.2525	76	588	3	24	9	17	0	2	17	0	0	10.439844327211144	
i 1	97.24879591836735	0.2525	74	904	6	2	10	17	0	2	17	0	0	4.0	
i 1	97.25521768707483	1.2625	74	588	4	4	9	17	0	2	17	0	0	4.0	
i 1	97.26966666666667	1.01	76	202	1	24	3	17	0	252	17	307	0	10.439844327211144	
i 1	97.48595238095238	0.2525	74	202	6	5	9	2	0	-1	2	0	0	11.606964696238188	
i 1	97.49638775510203	0.7575000000000001	76	202	3	20	1	16	0	1	16	0	0	6.439844327211144	
i 1	97.49799319727892	0.505	75	202	5	1	14	2	0	-2	2	0	0	7.72388007207531	
i 1	97.51886394557823	0.7575000000000001	73	202	3	20	3	16	0	2	16	0	0	6.439844327211144	
i 1	97.73033333333333	0.7575000000000001	71	904	6	5	10	2	0	-1	2	0	0	11.606964696238188	
i 1	97.98916326530612	0.2525	72	202	4	1	8	2	0	1	2	0	0	7.72388007207531	
i 1	97.99397959183673	0.505	75	904	6	1	1	2	0	1	2	0	0	7.72388007207531	
i 1	98.01725850340137	0.2525	71	202	6	5	12	8	0	-1	8	0	0	11.606964696238188	
i 1	98.23274149659863	0.505	72	202	5	1	1	2	0	-2	2	0	0	7.72388007207531	
i 1	98.23755782312925	0.2525	76	904	3	20	9	17	0	2	17	0	0	6.439844327211144	
i 1	98.23996598639455	0.2525	76	202	2	24	4	17	0	1	17	0	0	10.439844327211144	
i 1	98.25361224489797	0.505	71	202	4	5	6	2	0	-1	2	0	0	11.606964696238188	
i 1	98.259231292517	0.2525	77	904	6	2	12	16	0	2	16	0	0	4.0	
i 1	98.48354421768707	1.2625	75	700	4	24	8	8	5000	1	8	0	0	8.72388007207531	
i 1	98.48434693877552	0.505	74	202	4	9	14	17	0	1	17	0	0	3.0	
i 1	98.48755782312925	3.535	61	1086	5	14	1	16	0	2	16	0	0	2.386960017480566	
i 1	98.48755782312925	0.2525	74	1086	6	5	14	8	0	-2	8	0	0	11.606964696238188	
i 1	98.49397959183673	3.535	63	700	5	15	16	16	5000	2	16	0	0	0.7950005952107598	
i 1	98.49397959183673	6.565	61	1086	6	17	2	16	0	2	16	0	0	3.5064647417428527	
i 1	98.49397959183673	9.595	63	1086	6	17	9	16	0	2	16	0	0	3.5064647417428527	
i 1	98.49397959183673	0.2525	73	700	3	20	2	16	5000	1	16	0	0	6.439844327211144	
i 1	98.4955850340136	0.505	61	700	4	19	8	16	0	1	16	0	0	3.5064647417428527	
i 1	98.49638775510203	3.535	63	700	4	19	16	16	0	2	16	0	0	3.5064647417428527	
i 1	98.49638775510203	0.2525	73	700	2	24	11	17	0	2	17	0	0	10.439844327211144	
i 1	98.5044149659864	6.565	61	700	5	15	12	16	5000	2	16	0	0	0.7950005952107598	
i 1	98.51083673469388	12.625	61	700	6	17	2	1	5000	2	1	0	0	3.5064647417428527	
i 1	98.51565306122448	15.655	63	700	6	17	14	16	5000	1	16	0	0	3.5064647417428527	
i 1	98.51725850340137	1.5150000000000001	77	1086	6	2	2	17	0	2	17	0	0	4.0	
i 1	98.73033333333333	0.2525	71	202	4	5	10	2	0	-1	2	0	0	11.606964696238188	
i 1	98.7319387755102	0.2525	72	700	6	1	3	2	5000	1	2	0	0	7.72388007207531	
i 1	98.74799319727892	0.2525	71	1086	4	5	6	2	0	-1	2	0	0	11.606964696238188	
i 1	98.75361224489797	1.01	73	700	2	24	1	17	5000	1	17	0	0	10.439844327211144	
i 1	98.76886394557823	1.01	76	202	3	24	6	16	0	1	16	0	0	10.439844327211144	
i 1	98.98354421768707	12.120000000000001	61	700	5	12	8	1	0	1	1	0	0	1.5909803063456631	
i 1	98.99959863945578	0.2525	77	700	3	3	16	16	0	1	16	0	0	4.0	
i 1	99.00040136054422	0.7575000000000001	71	1086	6	5	3	2	0	-1	2	0	0	11.606964696238188	
i 1	99.01324489795918	0.2525	75	202	7	1	9	2	0	-2	2	0	0	7.72388007207531	
i 1	99.01966666666667	12.120000000000001	61	700	4	19	5	16	0	1	16	0	0	3.5064647417428527	
i 1	99.23916326530612	0.2525	72	700	4	24	15	2	0	1	2	0	0	8.72388007207531	
i 1	99.25361224489797	0.2525	74	202	4	9	4	17	0	1	17	0	0	3.0	
i 1	99.50762585034013	1.01	77	700	3	3	1	16	0	1	16	0	0	4.0	
i 1	99.509231292517	1.2625	72	700	6	1	15	2	5000	1	2	0	0	7.72388007207531	
i 1	99.7319387755102	1.5150000000000001	73	700	2	24	2	17	0	2	17	0	0	10.439844327211144	
i 1	99.73434693877552	0.2525	74	700	4	5	12	2	5000	-2	2	0	0	11.606964696238188	
i 1	99.74157142857143	3.2825	74	700	4	5	1	8	5000	-1	8	0	0	11.606964696238188	
i 1	99.74799319727892	1.5150000000000001	73	202	3	20	10	16	0	1	16	0	0	6.439844327211144	
i 1	99.74879591836735	0.7575000000000001	72	1086	6	1	9	2	0	1	2	0	0	7.72388007207531	
i 1	99.99638775510203	0.505	71	202	4	5	2	2	0	-1	2	0	0	11.606964696238188	
i 1	100.01163945578232	0.2525	74	700	5	3	4	16	5000	1	16	0	0	4.0	
i 1	100.26645578231293	1.5150000000000001	74	700	4	4	15	16	5000	1	16	0	0	4.0	
i 1	100.48033333333333	0.2525	74	700	3	4	15	17	0	1	17	0	0	4.0	
i 1	100.50200680272108	1.5150000000000001	72	1086	6	1	16	2	0	1	2	0	0	7.72388007207531	
i 1	100.51083673469388	0.2525	74	700	6	5	15	2	0	-1	2	0	0	11.606964696238188	
i 1	100.75521768707483	0.2525	74	202	4	9	16	17	0	1	17	0	0	3.0	
i 1	100.76485034013605	0.7575000000000001	75	700	4	24	14	8	5000	1	8	0	0	8.72388007207531	
i 1	100.76886394557823	0.2525	71	1086	6	5	3	2	0	-1	2	0	0	11.606964696238188	
i 1	100.990768707483	0.2525	71	202	4	5	8	2	0	-1	2	0	0	11.606964696238188	
i 1	101.01485034013605	0.505	74	700	5	3	15	16	5000	1	16	0	0	4.0	
i 1	101.24237414965987	1.5150000000000001	76	202	3	20	8	17	0	1	17	0	0	6.439844327211144	
i 1	101.25762585034013	1.5150000000000001	73	202	3	20	15	16	0	2	16	0	0	6.439844327211144	
i 1	101.26966666666667	0.505	74	700	3	5	6	2	0	-2	2	0	0	11.606964696238188	
i 1	101.4955850340136	0.7575000000000001	72	700	4	24	1	2	0	1	2	0	0	8.72388007207531	
i 1	101.50361224489797	0.2525	77	1086	6	2	5	17	0	2	17	0	0	4.0	
i 1	101.73274149659863	1.7675	74	700	5	3	15	16	5000	1	16	0	0	4.0	
i 1	101.7544149659864	0.2525	74	700	4	5	2	2	5000	-2	2	0	0	11.606964696238188	
i 1	101.76083673469388	0.2525	74	202	4	9	15	17	0	1	17	0	0	3.0	
i 1	101.98354421768707	9.09	63	700	5	12	8	16	0	1	16	0	0	1.5909803063456631	
i 1	101.98514965986395	0.505	72	700	6	1	2	2	5000	1	2	0	0	7.72388007207531	
i 1	101.99879591836735	9.09	61	1086	5	14	15	16	0	2	16	0	0	2.386960017480566	
i 1	102.00521768707483	6.0600000000000005	63	700	5	15	10	16	5000	2	16	0	0	0.7950005952107598	
i 1	102.00762585034013	0.2525	77	1086	6	2	11	17	0	1	17	0	0	4.0	
i 1	102.009231292517	9.09	63	700	4	19	5	16	0	2	16	0	0	3.5064647417428527	
i 1	102.01083673469388	0.2525	71	202	4	5	8	2	0	-1	2	0	0	11.606964696238188	
i 1	102.2455850340136	0.505	74	700	4	4	11	16	5000	1	16	0	0	4.0	
i 1	102.24959863945578	0.7575000000000001	72	1086	6	1	9	2	0	1	2	0	0	7.72388007207531	
i 1	102.51886394557823	0.2525	75	202	7	1	14	2	0	-2	2	0	0	7.72388007207531	
i 1	102.73033333333333	0.2525	75	700	4	1	14	2	0	-2	2	0	0	7.72388007207531	
i 1	102.73836054421768	0.2525	77	1086	6	2	7	17	0	1	17	0	0	4.0	
i 1	102.7568231292517	0.505	73	202	3	20	16	16	0	1	16	0	0	6.439844327211144	
i 1	102.76404761904762	0.505	73	700	2	24	2	17	0	2	17	0	0	10.439844327211144	
i 1	102.98836054421768	1.5150000000000001	72	700	6	1	13	2	5000	1	2	0	0	7.72388007207531	
i 1	102.98996598639455	1.7675	74	1086	6	5	6	8	0	-2	8	0	0	11.606964696238188	
i 1	103.0044149659864	1.01	77	1086	6	2	11	17	0	2	17	0	0	4.0	
i 1	103.01485034013605	0.2525	72	202	7	1	10	2	0	-2	2	0	0	7.72388007207531	
i 1	103.23755782312925	0.505	72	1086	6	1	5	2	0	1	2	0	0	7.72388007207531	
i 1	103.24478231292517	0.2525	73	700	2	20	4	16	0	1	16	0	0	6.439844327211144	
i 1	103.25280952380952	0.2525	73	700	3	24	11	17	5000	1	17	0	0	10.439844327211144	
i 1	103.26244217687075	1.2625	73	700	1	24	2	17	0	252	17	307	0	10.439844327211144	
i 1	103.48595238095238	0.2525	74	700	4	4	3	16	5000	1	16	0	0	4.0	
i 1	103.50602040816327	1.01	76	202	3	24	4	16	0	1	16	0	0	10.439844327211144	
i 1	103.5068231292517	1.01	73	700	2	24	11	17	5000	1	17	0	0	10.439844327211144	
i 1	103.73434693877552	0.2525	72	1086	6	1	10	2	0	1	2	0	0	7.72388007207531	
i 1	103.73675510204082	0.2525	77	700	3	3	16	16	0	1	16	0	0	4.0	
i 1	103.98675510204082	1.5150000000000001	74	700	5	3	2	16	5000	1	16	0	0	4.0	
i 1	104.00521768707483	0.2525	75	202	7	1	6	2	0	-2	2	0	0	7.72388007207531	
i 1	104.48595238095238	1.5150000000000001	73	700	2	24	12	17	0	2	17	0	0	10.439844327211144	
i 1	104.49638775510203	1.5150000000000001	73	202	3	20	2	17	0	2	17	0	0	6.439844327211144	
i 1	104.50120408163265	0.505	72	1086	6	1	7	2	0	1	2	0	0	7.72388007207531	
i 1	104.51003401360545	0.2525	74	700	4	4	8	16	5000	1	16	0	0	4.0	
i 1	104.51083673469388	0.2525	75	202	7	1	7	2	0	-2	2	0	0	7.72388007207531	
i 1	104.76244217687075	0.505	72	700	6	1	8	2	5000	1	2	0	0	7.72388007207531	
i 1	104.76485034013605	1.01	74	700	6	5	1	2	5000	-2	2	0	0	11.606964696238188	
i 1	104.76565306122448	1.01	77	1086	6	2	10	17	0	2	17	0	0	4.0	
i 1	104.98595238095238	6.0600000000000005	61	700	5	15	14	16	5000	2	16	0	0	0.7950005952107598	
i 1	104.9955850340136	0.505	72	1086	6	1	16	2	0	1	2	0	0	7.72388007207531	
i 1	105.23996598639455	0.2525	71	202	4	5	5	2	0	-1	2	0	0	11.606964696238188	
i 1	105.25602040816327	0.2525	75	202	7	1	6	2	0	-2	2	0	0	7.72388007207531	
i 1	105.48514965986395	1.5150000000000001	74	700	4	4	1	16	5000	1	16	0	0	4.0	
i 1	105.49157142857143	1.7675	74	1086	6	5	3	8	0	-2	8	0	0	11.606964696238188	
i 1	105.50521768707483	1.01	72	700	6	1	14	2	5000	1	2	0	0	7.72388007207531	
i 1	105.51324489795918	0.2525	75	700	4	24	4	8	5000	1	8	0	0	8.72388007207531	
i 1	105.74719047619048	0.2525	71	202	4	5	14	2	0	-1	2	0	0	11.606964696238188	
i 1	105.74959863945578	0.2525	74	700	5	3	4	16	5000	1	16	0	0	4.0	
i 1	105.99237414965987	0.2525	77	202	4	9	4	17	0	1	17	0	0	3.0	
i 1	105.99879591836735	0.505	73	202	3	20	12	16	0	2	16	0	0	6.439844327211144	
i 1	106.00280952380952	0.2525	74	700	6	5	11	2	5000	-2	2	0	0	11.606964696238188	
i 1	106.00602040816327	0.505	76	202	3	20	14	17	0	1	17	0	0	6.439844327211144	
i 1	106.01083673469388	1.7675	73	700	1	24	10	17	0	252	17	307	0	10.439844327211144	
i 1	106.4819387755102	0.505	76	202	3	24	6	16	0	1	16	0	0	10.439844327211144	
i 1	106.49879591836735	0.505	76	1086	3	20	8	16	0	2	16	0	0	6.439844327211144	
i 1	106.50842857142857	1.7675	75	700	4	24	9	8	5000	1	8	0	0	8.72388007207531	
i 1	106.759231292517	0.2525	71	202	4	5	2	2	0	-1	2	0	0	11.606964696238188	
i 1	106.9931768707483	0.2525	73	202	3	20	6	16	0	2	16	0	0	6.439844327211144	
i 1	107.00361224489797	0.2525	73	202	3	20	2	16	0	1	16	0	0	6.439844327211144	
i 1	107.00602040816327	0.505	74	700	6	5	15	8	5000	-1	8	0	0	11.606964696238188	
i 1	107.23274149659863	0.2525	73	700	2	20	16	16	5000	1	16	0	0	6.439844327211144	
i 1	107.23434693877552	1.5150000000000001	77	1086	6	2	8	17	0	2	17	0	0	4.0	
i 1	107.24799319727892	1.5150000000000001	71	1086	6	5	9	2	0	-1	2	0	0	11.606964696238188	
i 1	107.25842857142857	0.2525	72	1086	6	1	5	2	0	1	2	0	0	7.72388007207531	
i 1	107.26485034013605	0.2525	73	700	2	20	13	16	0	1	16	0	0	6.439844327211144	
i 1	107.48755782312925	0.2525	71	202	4	5	16	2	0	-1	2	0	0	11.606964696238188	
i 1	107.49719047619048	0.2525	76	1086	3	20	6	17	0	2	17	0	0	6.439844327211144	
i 1	107.50762585034013	0.2525	73	202	3	20	7	16	0	2	16	0	0	6.439844327211144	
i 1	107.5180612244898	0.505	75	700	6	1	13	2	0	-2	2	0	0	7.72388007207531	
i 1	107.74397959183673	0.7575000000000001	76	202	3	20	3	17	0	1	17	0	0	6.439844327211144	
i 1	107.74959863945578	0.7575000000000001	73	700	2	24	16	17	0	2	17	0	0	10.439844327211144	
i 1	107.7568231292517	0.2525	71	202	4	5	6	2	0	-1	2	0	0	11.606964696238188	
i 1	107.98033333333333	3.0300000000000002	63	202	5	16	7	1	0	1	1	0	0	1.5909803063456631	
i 1	107.98113605442177	8.585	63	700	5	15	15	16	5000	2	16	0	0	0.7950005952107598	
i 1	107.99879591836735	0.2525	72	700	6	1	13	2	5000	1	2	0	0	7.72388007207531	
i 1	108.23996598639455	0.2525	74	700	3	4	15	17	0	1	17	0	0	4.0	
i 1	108.25521768707483	0.2525	75	202	7	1	9	2	0	-2	2	0	0	7.72388007207531	
i 1	108.26083673469388	0.7575000000000001	72	1086	6	1	12	2	0	1	2	0	0	7.72388007207531	
i 1	108.48354421768707	0.505	77	202	6	9	8	17	0	1	17	0	0	3.0	
i 1	108.48755782312925	0.2525	75	700	6	1	2	2	0	-2	2	0	0	7.72388007207531	
i 1	108.50602040816327	1.5150000000000001	73	202	3	20	9	16	0	2	16	0	0	6.439844327211144	
i 1	108.51163945578232	1.5150000000000001	76	202	3	20	14	17	0	1	17	0	0	6.439844327211144	
i 1	108.73836054421768	2.02	72	700	6	1	9	2	5000	1	2	0	0	7.72388007207531	
i 1	108.74157142857143	2.02	74	700	6	5	2	8	5000	-1	8	0	0	11.606964696238188	
i 1	108.75280952380952	0.2525	71	202	4	5	10	2	0	-1	2	0	0	11.606964696238188	
i 1	108.76163945578232	1.7675	74	700	5	3	12	16	5000	1	16	0	0	4.0	
i 1	108.98675510204082	0.505	74	700	3	5	1	2	0	-2	2	0	0	11.606964696238188	
i 1	109.00040136054422	0.2525	72	1086	6	1	1	2	0	1	2	0	0	7.72388007207531	
i 1	109.00521768707483	0.505	74	202	6	9	16	17	0	1	17	0	0	3.0	
i 1	109.24397959183673	0.2525	75	202	7	1	3	2	0	-2	2	0	0	7.72388007207531	
i 1	109.4955850340136	0.2525	71	1086	6	5	13	2	0	-1	2	0	0	11.606964696238188	
i 1	109.50521768707483	0.2525	77	202	6	9	10	17	0	1	17	0	0	3.0	
i 1	109.73354421768707	0.2525	74	700	4	4	16	16	5000	1	16	0	0	4.0	
i 1	109.76565306122448	0.505	71	202	7	5	7	2	0	-1	2	0	0	11.606964696238188	
i 1	109.98274149659863	0.2525	77	700	3	3	14	16	0	1	16	0	0	4.0	
i 1	109.99237414965987	1.01	73	700	2	24	5	17	5000	1	17	0	0	10.439844327211144	
i 1	109.99719047619048	1.01	76	202	3	24	11	16	0	1	16	0	0	10.439844327211144	
i 1	110.23996598639455	0.2525	74	1086	6	5	13	8	0	-2	8	0	0	11.606964696238188	
i 1	110.26163945578232	0.2525	75	202	7	1	11	2	0	-2	2	0	0	7.72388007207531	
i 1	110.26324489795918	0.7575000000000001	74	700	4	4	16	16	5000	1	16	0	0	4.0	
i 1	110.48595238095238	0.505	72	1086	6	1	3	2	0	1	2	0	0	7.72388007207531	
i 1	110.5044149659864	0.505	71	202	4	5	7	2	0	-1	2	0	0	11.606964696238188	
i 1	110.73514965986395	0.2525	72	202	7	1	13	2	0	-2	2	0	0	7.72388007207531	
i 1	110.7568231292517	0.2525	74	700	3	4	3	17	0	1	17	0	0	4.0	
i 1	110.75842857142857	0.2525	74	1086	6	5	2	8	0	-2	8	0	0	11.606964696238188	
i 1	110.98113605442177	0.2525	77	6	3	4	13	17	0	1	17	0	0	4.0	
i 1	110.98755782312925	1.01	75	6	7	1	3	2	0	1	2	0	0	7.72388007207531	
i 1	110.98916326530612	3.0300000000000002	63	6	6	12	8	16	0	2	16	0	0	1.5909803063456631	
i 1	110.98916326530612	0.2525	73	6	2	20	12	17	5000	2	17	0	0	6.439844327211144	
i 1	110.98996598639455	0.2525	75	700	4	24	2	8	5000	1	8	0	0	8.72388007207531	
i 1	110.99478231292517	5.555	61	700	5	15	1	16	5000	2	16	0	0	0.7950005952107598	
i 1	110.99478231292517	6.0600000000000005	63	392	4	18	3	1	0	1	1	0	0	3.5064647417428527	
i 1	110.99799319727892	6.0600000000000005	61	6	6	14	10	1	0	2	1	0	0	2.386960017480566	
i 1	111.00280952380952	11.11	61	6	5	19	3	16	0	2	16	0	0	3.5064647417428527	
i 1	111.00521768707483	11.11	61	6	1	27	3	1	0	252	1	307	0	12.802460130804567	
i 1	111.00521768707483	1.5150000000000001	74	700	6	5	2	2	5000	-2	2	0	0	11.606964696238188	
i 1	111.009231292517	9.09	61	392	4	18	13	16	0	2	16	0	0	3.5064647417428527	
i 1	111.01163945578232	6.0600000000000005	61	6	6	12	13	16	0	2	16	0	0	1.5909803063456631	
i 1	111.01485034013605	6.0600000000000005	61	392	4	16	14	1	0	1	1	0	0	1.5909803063456631	
i 1	111.01565306122448	11.11	61	6	5	19	13	1	0	1	1	0	0	3.5064647417428527	
i 1	111.01725850340137	1.5150000000000001	77	6	7	2	5	16	0	2	16	0	0	4.0	
i 1	111.01725850340137	0.2525	71	6	7	5	9	2	0	-1	2	0	0	11.606964696238188	
i 1	111.0180612244898	3.0300000000000002	63	392	4	16	14	16	0	2	16	0	0	1.5909803063456631	
i 1	111.01966666666667	0.505	73	6	2	24	16	17	0	2	17	0	0	10.439844327211144	
i 1	111.23274149659863	0.2525	76	6	4	20	4	16	0	1	16	0	0	6.439844327211144	
i 1	111.24959863945578	0.2525	71	392	6	5	7	8	0	-2	8	0	0	11.606964696238188	
i 1	111.51163945578232	0.505	71	6	7	5	8	8	0	-2	8	0	0	11.606964696238188	
i 1	111.51163945578232	0.7575000000000001	73	392	3	20	4	17	0	1	17	0	0	6.439844327211144	
i 1	111.51404761904762	0.7575000000000001	73	392	3	20	8	16	0	1	16	0	0	6.439844327211144	
i 1	111.98274149659863	0.2525	71	6	7	5	5	2	0	-1	2	0	0	11.606964696238188	
i 1	111.98354421768707	0.2525	72	392	6	1	16	2	0	1	2	0	0	7.72388007207531	
i 1	111.98916326530612	2.7775	72	700	6	1	16	2	5000	1	2	0	0	7.72388007207531	
i 1	112.00040136054422	0.2525	74	6	6	3	16	17	0	1	17	0	0	4.0	
i 1	112.23113605442177	0.2525	71	392	6	5	4	8	0	-2	8	0	0	11.606964696238188	
i 1	112.2431768707483	0.7575000000000001	73	392	3	24	6	17	0	2	17	0	0	10.439844327211144	
i 1	112.26404761904762	1.7675	74	700	5	3	14	16	5000	1	16	0	0	4.0	
i 1	112.26485034013605	0.505	75	392	6	1	4	2	0	-2	2	0	0	7.72388007207531	
i 1	112.2680612244898	0.7575000000000001	76	392	3	20	8	16	0	2	16	0	0	6.439844327211144	
i 1	112.48033333333333	1.5150000000000001	71	6	7	5	5	8	0	-2	8	0	0	11.606964696238188	
i 1	112.51645578231293	0.2525	74	700	4	4	15	16	5000	1	16	0	0	4.0	
i 1	112.74478231292517	0.2525	77	6	3	4	4	17	0	1	17	0	0	4.0	
i 1	112.76404761904762	0.2525	72	392	6	1	12	2	0	1	2	0	0	7.72388007207531	
i 1	113.01244217687075	0.2525	75	6	7	1	16	2	0	1	2	0	0	7.72388007207531	
i 1	113.01324489795918	0.7575000000000001	73	6	2	24	10	17	5000	2	17	0	0	10.439844327211144	
i 1	113.01404761904762	0.7575000000000001	73	6	2	20	15	16	0	1	16	0	0	6.439844327211144	
i 1	113.25361224489797	0.7575000000000001	75	700	4	24	6	8	5000	1	8	0	0	8.72388007207531	
i 1	113.48595238095238	0.2525	74	6	6	3	7	17	0	1	17	0	0	4.0	
i 1	113.74638775510203	0.2525	73	392	3	24	9	17	0	2	17	0	0	10.439844327211144	
i 1	113.75280952380952	0.2525	76	392	3	20	1	16	0	2	16	0	0	6.439844327211144	
i 1	113.7680612244898	0.505	74	700	4	4	9	16	5000	1	16	0	0	4.0	
i 1	113.98434693877552	8.08	63	392	4	16	12	16	0	2	16	0	0	1.5909803063456631	
i 1	113.98675510204082	6.0600000000000005	61	6	6	25	6	16	0	1	16	0	0	0.4558924227131882	
i 1	113.99397959183673	1.2625	73	392	1	24	14	17	0	248	17	308	0	10.439844327211144	
i 1	113.99879591836735	2.525	74	700	6	5	2	8	5000	-1	8	0	0	11.606964696238188	
i 1	113.99959863945578	0.505	70	6	4	20	2	8	0	-1	8	0	0	6.439844327211144	
i 1	114.00120408163265	0.505	73	6	2	24	2	17	0	2	17	0	0	10.439844327211144	
i 1	114.00280952380952	0.2525	72	392	6	1	1	2	0	1	2	0	0	7.72388007207531	
i 1	114.0068231292517	0.2525	77	6	7	2	6	16	0	2	16	0	0	4.0	
i 1	114.01244217687075	6.0600000000000005	63	6	4	12	6	16	0	2	16	0	0	1.5909803063456631	
i 1	114.24157142857143	1.7675	72	6	7	1	16	2	0	1	2	0	0	7.72388007207531	
i 1	114.24478231292517	0.2525	74	392	5	9	3	16	0	2	16	0	0	3.0	
i 1	114.25200680272108	1.5150000000000001	77	6	7	2	3	16	0	1	16	0	0	4.0	
i 1	114.509231292517	0.7575000000000001	73	392	3	20	11	16	0	1	16	0	0	6.439844327211144	
i 1	114.51886394557823	0.7575000000000001	73	392	3	20	7	8	0	-1	8	0	0	6.439844327211144	
i 1	114.75361224489797	0.2525	71	6	7	5	14	8	0	-2	8	0	0	11.606964696238188	
i 1	114.76725850340137	0.2525	72	6	6	1	7	2	0	-2	2	0	0	7.72388007207531	
i 1	115.00762585034013	0.2525	75	700	4	24	14	8	5000	1	8	0	0	8.72388007207531	
i 1	115.01003401360545	0.505	71	6	6	5	2	2	0	-2	2	0	0	11.606964696238188	
i 1	115.23354421768707	0.2525	72	392	6	1	6	2	0	1	2	0	0	7.72388007207531	
i 1	115.24799319727892	0.2525	73	392	3	24	12	17	0	2	17	0	0	10.439844327211144	
i 1	115.26725850340137	0.2525	70	392	3	20	8	2	0	-2	2	0	0	6.439844327211144	
i 1	115.48514965986395	0.2525	74	700	6	5	16	2	5000	-2	2	0	0	11.606964696238188	
i 1	115.5068231292517	0.2525	70	6	4	20	10	2	0	-1	2	0	0	6.439844327211144	
i 1	115.51404761904762	1.5150000000000001	73	392	3	20	16	16	0	1	16	0	0	6.439844327211144	
i 1	115.51565306122448	0.505	72	6	6	1	2	2	0	-2	2	0	0	7.72388007207531	
i 1	115.73113605442177	1.2625	70	392	3	20	9	8	0	-2	8	0	0	6.439844327211144	
i 1	115.73595238095238	0.2525	71	392	6	5	7	8	0	-2	8	0	0	11.606964696238188	
i 1	115.74157142857143	0.7575000000000001	77	6	7	2	6	16	0	2	16	0	0	4.0	
i 1	115.99397959183673	0.505	72	392	6	1	4	2	0	1	2	0	0	7.72388007207531	
i 1	116.01003401360545	0.505	72	700	6	1	16	2	5000	1	2	0	0	7.72388007207531	
i 1	116.48434693877552	6.565	66	890	5	15	7	6	0	1	6	0	0	0.7950005952107598	
i 1	116.48434693877552	1.5150000000000001	71	6	7	5	12	8	0	-2	8	0	0	11.606964696238188	
i 1	116.49478231292517	0.7575000000000001	75	890	4	4	2	8	0	-2	8	0	0	4.0	
i 1	116.4955850340136	9.595	61	890	5	15	6	9	0	1	9	0	0	0.7950005952107598	
i 1	116.49799319727892	1.01	72	890	6	1	13	1	0	-1	1	0	0	7.72388007207531	
i 1	116.50762585034013	0.505	73	6	1	24	10	8	0	248	8	308	0	10.439844327211144	
i 1	116.509231292517	0.2525	75	6	5	1	10	2	0	1	2	0	0	7.72388007207531	
i 1	116.740768707483	0.2525	72	392	6	1	7	2	0	1	2	0	0	7.72388007207531	
i 1	116.75280952380952	0.2525	74	392	5	9	10	16	0	2	16	0	0	3.0	
i 1	116.7544149659864	0.2525	71	6	7	5	9	2	0	-1	2	0	0	11.606964696238188	
i 1	116.98836054421768	0.2525	70	392	3	20	3	8	0	-2	8	0	0	8.763456879477745	
i 1	116.99157142857143	5.05	61	392	4	16	4	1	0	1	1	0	0	1.5909803063456631	
i 1	116.99157142857143	5.05	63	6	6	25	1	16	0	2	16	0	0	0.4558924227131882	
i 1	117.00842857142857	0.2525	73	392	3	20	10	16	0	1	16	0	0	8.763456879477745	
i 1	117.01244217687075	1.7675	72	890	5	3	14	2	0	1	2	0	0	4.0	
i 1	117.01485034013605	5.05	61	6	4	12	8	16	0	2	16	0	0	1.5909803063456631	
i 1	117.01645578231293	0.505	77	890	6	5	1	17	0	1	17	0	0	11.606964696238188	
i 1	117.25040136054422	0.505	73	392	3	20	2	8	0	-2	8	0	0	8.763456879477745	
i 1	117.26003401360545	0.505	73	392	3	24	11	17	0	2	17	0	0	12.763456879477745	
i 1	117.48675510204082	1.5150000000000001	75	6	7	1	3	2	0	1	2	0	0	7.72388007207531	
i 1	117.50762585034013	0.2525	71	392	6	5	3	8	0	-2	8	0	0	11.606964696238188	
i 1	117.51485034013605	0.2525	75	890	4	4	11	8	0	-2	8	0	0	4.0	
i 1	117.75200680272108	0.505	73	392	3	20	3	16	0	1	16	0	0	8.763456879477745	
i 1	117.75280952380952	1.7675	74	890	6	5	5	17	0	2	17	0	0	11.606964696238188	
i 1	117.7544149659864	0.505	70	6	4	20	1	2	0	-2	2	0	0	8.763456879477745	
i 1	117.759231292517	0.2525	74	392	5	9	1	16	0	2	16	0	0	3.0	
i 1	117.98354421768707	0.2525	74	6	6	5	11	8	0	-1	8	0	0	11.606964696238188	
i 1	118.240768707483	0.2525	73	392	3	24	7	17	0	2	17	0	0	12.763456879477745	
i 1	118.24478231292517	0.2525	71	6	7	5	7	8	0	-2	8	0	0	11.606964696238188	
i 1	118.2568231292517	0.2525	70	392	3	20	12	2	0	-1	2	0	0	8.763456879477745	
i 1	118.48996598639455	0.505	73	6	2	20	11	16	0	1	16	0	0	8.763456879477745	
i 1	118.509231292517	0.505	73	6	2	24	16	8	0	-1	8	0	0	12.763456879477745	
i 1	118.74799319727892	1.5150000000000001	77	6	7	2	13	16	0	2	16	0	0	4.0	
i 1	118.9931768707483	0.2525	72	890	6	1	16	1	0	-1	1	0	0	7.72388007207531	
i 1	118.9955850340136	0.505	73	392	3	20	4	16	0	1	16	0	0	8.763456879477745	
i 1	118.99719047619048	0.2525	73	6	4	20	5	2	0	-2	2	0	0	8.763456879477745	
i 1	119.00762585034013	0.2525	75	392	6	1	16	2	0	-2	2	0	0	7.72388007207531	
i 1	119.24638775510203	0.505	72	392	6	1	4	2	0	1	2	0	0	7.72388007207531	
i 1	119.24959863945578	0.2525	70	392	3	20	12	8	0	-1	8	0	0	8.763456879477745	
i 1	119.26645578231293	0.7575000000000001	69	890	4	24	1	0	0	0	0	0	0	8.72388007207531	
i 1	119.49397959183673	0.505	71	6	7	5	16	8	0	-2	8	0	0	11.606964696238188	
i 1	119.50361224489797	0.2525	77	890	6	5	11	17	0	1	17	0	0	11.606964696238188	
i 1	119.50762585034013	1.7675	73	6	2	24	16	8	0	-1	8	0	0	12.763456879477745	
i 1	119.51886394557823	1.7675	73	6	2	20	1	16	0	1	16	0	0	8.763456879477745	
i 1	119.7568231292517	1.5150000000000001	71	6	7	5	13	2	0	-1	2	0	0	11.606964696238188	
i 1	119.7680612244898	0.2525	74	392	5	9	3	16	0	2	16	0	0	3.0	
i 1	119.76966666666667	0.2525	72	6	5	24	16	2	0	1	2	0	0	8.72388007207531	
i 1	119.98595238095238	0.2525	75	6	7	1	9	2	0	1	2	0	0	7.72388007207531	
i 1	119.98836054421768	0.2525	77	890	6	5	10	17	0	1	17	0	0	11.606964696238188	
i 1	119.990768707483	1.5150000000000001	72	890	4	1	2	1	0	-1	1	0	0	7.72388007207531	
i 1	120.00280952380952	0.505	77	6	7	2	6	16	0	1	16	0	0	4.0	
i 1	120.00762585034013	2.02	61	6	6	25	6	16	0	1	16	0	0	0.4558924227131882	
i 1	120.00842857142857	2.02	63	6	6	12	10	16	0	2	16	0	0	1.5909803063456631	
i 1	120.01163945578232	6.0600000000000005	61	890	5	25	15	6	0	1	6	0	0	0.4558924227131882	
i 1	120.25521768707483	0.7575000000000001	74	890	6	5	11	17	0	2	17	0	0	11.606964696238188	
i 1	120.25762585034013	0.7575000000000001	72	890	5	3	16	2	0	1	2	0	0	4.0	
i 1	120.26886394557823	0.2525	75	392	6	1	16	2	0	-2	2	0	0	7.72388007207531	
i 1	120.48514965986395	0.505	72	6	5	24	6	2	0	1	2	0	0	8.72388007207531	
i 1	120.49799319727892	0.2525	77	6	7	2	1	16	0	2	16	0	0	4.0	
i 1	120.75361224489797	0.2525	74	6	6	3	14	17	0	1	17	0	0	4.0	
i 1	120.9819387755102	0.505	72	392	6	1	2	2	0	1	2	0	0	7.72388007207531	
i 1	120.99397959183673	0.2525	71	6	7	5	1	8	0	-2	8	0	0	11.606964696238188	
i 1	121.01725850340137	1.2625	75	890	4	4	4	8	0	-2	8	0	0	4.0	
i 1	121.23113605442177	0.2525	77	890	6	5	2	17	0	1	17	0	0	11.606964696238188	
i 1	121.23514965986395	0.2525	73	890	3	24	16	2	0	-2	2	0	0	12.763456879477745	
i 1	121.25842857142857	0.7575000000000001	73	392	3	24	11	17	0	2	17	0	0	12.763456879477745	
i 1	121.2680612244898	0.2525	71	6	6	5	3	2	0	-2	2	0	0	11.606964696238188	
i 1	121.48113605442177	0.2525	75	392	6	1	3	2	0	-2	2	0	0	7.72388007207531	
i 1	121.49719047619048	0.505	73	392	3	20	7	8	0	-1	8	0	0	8.763456879477745	
i 1	121.51163945578232	0.505	72	6	7	1	8	2	0	1	2	0	0	7.72388007207531	
i 1	121.51565306122448	0.505	74	890	6	5	5	17	0	2	17	0	0	11.606964696238188	
i 1	121.76003401360545	0.2525	72	392	6	1	10	2	0	1	2	0	0	7.72388007207531	
i 1	121.76966666666667	0.2525	72	890	5	3	3	2	0	1	2	0	0	4.0	
i 1	121.9819387755102	3.0300000000000002	77	1072	6	5	4	16	0	2	16	0	0	11.606964696238188	
i 1	121.98274149659863	4.04	61	188	5	19	8	6	0	1	6	0	0	3.5064647417428527	
i 1	121.98274149659863	1.5150000000000001	70	188	3	20	10	8	0	-1	8	0	0	8.763456879477745	
i 1	121.98434693877552	1.5150000000000001	73	188	1	24	11	2	0	252	2	307	0	12.763456879477745	
i 1	121.98595238095238	1.01	66	1072	5	25	9	6	0	2	6	0	0	0.4558924227131882	
i 1	121.98996598639455	0.2525	69	188	6	1	12	1	0	-1	1	0	0	7.72388007207531	
i 1	121.99478231292517	12.625	61	188	6	12	1	9	0	2	9	0	0	1.5909803063456631	
i 1	121.9955850340136	7.07	66	188	5	16	9	9	0	1	9	0	0	1.5909803063456631	
i 1	122.00120408163265	1.01	72	1072	6	2	6	2	0	-2	2	0	0	4.0	
i 1	122.00361224489797	10.1	61	188	1	27	12	6	0	252	6	307	0	12.802460130804567	
i 1	122.00521768707483	1.01	61	188	5	19	14	9	0	1	9	0	0	3.5064647417428527	
i 1	122.00842857142857	1.01	66	1072	5	25	8	9	0	1	9	0	0	0.4558924227131882	
i 1	122.01485034013605	10.1	66	188	5	16	5	9	0	1	9	0	0	1.5909803063456631	
i 1	122.01565306122448	1.01	61	188	4	12	13	6	0	1	6	0	0	1.5909803063456631	
i 1	122.01966666666667	1.01	69	1072	6	1	2	1	0	-1	1	0	0	7.72388007207531	
i 1	122.01966666666667	1.5150000000000001	73	188	2	24	12	8	0	-1	8	0	0	12.763456879477745	
i 1	122.25602040816327	0.2525	72	1072	6	2	2	2	0	-2	2	0	0	4.0	
i 1	122.26565306122448	0.505	72	188	6	1	14	1	0	0	1	0	0	7.72388007207531	
i 1	122.48675510204082	0.2525	75	188	6	9	1	2	0	1	2	0	0	3.0	
i 1	122.50842857142857	0.2525	77	1072	6	5	3	16	0	1	16	0	0	11.606964696238188	
i 1	122.74719047619048	0.505	77	188	6	5	5	17	0	2	17	0	0	11.606964696238188	
i 1	122.75120408163265	0.2525	72	188	6	1	1	1	0	0	1	0	0	7.72388007207531	
i 1	122.98033333333333	0.2525	75	890	4	4	7	8	0	-2	8	0	0	4.0	
i 1	122.98514965986395	0.2525	69	1072	5	1	10	1	0	-1	1	0	0	7.72388007207531	
i 1	122.99157142857143	11.615	66	1072	5	25	16	9	0	1	9	0	0	0.4558924227131882	
i 1	122.99237414965987	6.0600000000000005	66	890	5	25	2	9	0	1	9	0	0	0.4558924227131882	
i 1	122.99638775510203	11.615	61	188	6	12	11	6	0	1	6	0	0	1.5909803063456631	
i 1	123.00040136054422	1.5150000000000001	72	890	6	1	6	1	0	-1	1	0	0	7.72388007207531	
i 1	123.01485034013605	3.0300000000000002	66	1072	5	25	14	6	0	2	6	0	0	0.4558924227131882	
i 1	123.01645578231293	0.505	72	1072	6	2	7	2	0	-2	2	0	0	4.0	
i 1	123.23836054421768	0.505	75	188	6	9	8	2	0	-2	2	0	0	3.0	
i 1	123.25842857142857	0.505	77	188	7	5	7	16	0	1	16	0	0	11.606964696238188	
i 1	123.26003401360545	0.2525	69	188	6	1	2	1	0	-1	1	0	0	7.72388007207531	
i 1	123.48514965986395	1.2625	70	188	2	24	11	2	0	-2	2	0	0	12.763456879477745	
i 1	123.49237414965987	0.7575000000000001	72	1072	6	2	7	2	0	-2	2	0	0	4.0	
i 1	123.50040136054422	0.505	72	1072	6	1	11	1	0	0	1	0	0	7.72388007207531	
i 1	123.51725850340137	1.2625	73	188	3	24	9	2	0	-1	2	0	0	12.763456879477745	
i 1	123.73514965986395	0.2525	75	890	4	4	13	8	0	-2	8	0	0	4.0	
i 1	123.75842857142857	0.2525	74	188	6	5	1	17	0	2	17	0	0	11.606964696238188	
i 1	123.99638775510203	0.2525	69	890	4	24	10	0	0	0	0	0	0	8.72388007207531	
i 1	124.0068231292517	0.2525	74	890	6	5	12	17	0	2	17	0	0	11.606964696238188	
i 1	124.01966666666667	0.2525	72	1072	6	2	5	2	0	-2	2	0	0	4.0	
i 1	124.23675510204082	0.2525	72	188	6	1	6	1	0	0	1	0	0	7.72388007207531	
i 1	124.24959863945578	0.505	77	1072	6	5	7	16	0	1	16	0	0	11.606964696238188	
i 1	124.26324489795918	1.5150000000000001	75	890	4	4	14	8	0	-2	8	0	0	4.0	
i 1	124.48755782312925	0.2525	72	890	5	3	4	2	0	1	2	0	0	4.0	
i 1	124.49397959183673	0.2525	69	1072	5	1	16	1	0	-1	1	0	0	7.72388007207531	
i 1	124.51645578231293	0.505	72	188	5	1	16	1	0	0	1	0	0	7.72388007207531	
i 1	124.73274149659863	0.7575000000000001	70	188	3	20	13	8	0	-1	8	0	0	8.763456879477745	
i 1	124.7431768707483	0.505	75	188	6	9	12	2	0	1	2	0	0	3.0	
i 1	124.75361224489797	0.2525	77	188	6	5	4	17	0	2	17	0	0	11.606964696238188	
i 1	124.75762585034013	0.7575000000000001	73	188	2	24	4	8	0	-1	8	0	0	12.763456879477745	
i 1	124.76244217687075	0.7575000000000001	72	890	6	1	15	1	0	-1	1	0	0	7.72388007207531	
i 1	124.9819387755102	0.2525	69	890	4	24	2	0	0	0	0	0	0	8.72388007207531	
i 1	125.0068231292517	0.2525	74	188	6	5	6	17	0	2	17	0	0	11.606964696238188	
i 1	125.00842857142857	0.2525	74	890	6	5	11	17	0	2	17	0	0	11.606964696238188	
i 1	125.23354421768707	0.2525	69	188	6	1	5	1	0	-1	1	0	0	7.72388007207531	
i 1	125.24799319727892	0.2525	75	188	6	3	11	2	0	1	2	0	0	4.0	
i 1	125.26003401360545	1.5150000000000001	77	1072	6	5	6	16	0	2	16	0	0	11.606964696238188	
i 1	125.2680612244898	0.505	74	188	7	5	7	16	0	1	16	0	0	11.606964696238188	
i 1	125.48434693877552	0.2525	73	188	3	24	15	2	0	-1	2	0	0	12.763456879477745	
i 1	125.50361224489797	0.505	69	890	4	24	15	0	0	0	0	0	0	8.72388007207531	
i 1	125.50361224489797	0.2525	70	188	2	24	12	2	0	-2	2	0	0	12.763456879477745	
i 1	125.51886394557823	1.7675	72	890	5	3	14	2	0	1	2	0	0	4.0	
i 1	125.74799319727892	0.505	74	890	6	5	1	17	0	2	17	0	0	11.606964696238188	
i 1	125.75521768707483	0.2525	75	188	6	3	4	2	0	1	2	0	0	4.0	
i 1	125.75521768707483	0.7575000000000001	70	188	3	20	7	8	0	-1	8	0	0	8.763456879477745	
i 1	125.759231292517	0.7575000000000001	73	188	2	24	7	8	0	-1	8	0	0	12.763456879477745	
i 1	125.98274149659863	0.505	75	188	6	9	10	2	0	1	2	0	0	3.0	
i 1	125.98434693877552	1.01	69	890	4	24	2	0	0	0	0	0	0	8.72388007207531	
i 1	125.98514965986395	3.0300000000000002	61	890	5	25	15	6	0	1	6	0	0	0.4558924227131882	
i 1	125.98996598639455	6.0600000000000005	66	188	5	26	5	9	0	2	9	0	0	0.4558924227131882	
i 1	126.01565306122448	8.585	66	1072	5	25	6	6	0	2	6	0	0	0.4558924227131882	
i 1	126.23836054421768	0.2525	74	188	7	5	2	17	0	2	17	0	0	11.606964696238188	
i 1	126.48595238095238	0.2525	75	188	6	3	15	2	0	1	2	0	0	4.0	
i 1	126.490768707483	1.7675	73	188	3	20	6	8	0	-2	8	0	0	8.763456879477745	
i 1	126.50120408163265	0.2525	77	188	6	5	15	17	0	2	17	0	0	11.606964696238188	
i 1	126.509231292517	1.7675	73	188	3	20	4	2	0	-1	2	0	0	8.763456879477745	
i 1	126.73675510204082	0.2525	72	188	5	4	5	2	0	-2	2	0	0	4.0	
i 1	127.01485034013605	0.2525	74	188	6	5	8	16	0	1	16	0	0	11.606964696238188	
i 1	127.01645578231293	1.01	72	890	6	1	15	1	0	-1	1	0	0	7.72388007207531	
i 1	127.0180612244898	1.01	77	890	6	5	14	17	0	1	17	0	0	11.606964696238188	
i 1	127.23113605442177	0.7575000000000001	72	1072	6	2	2	2	0	-2	2	0	0	4.0	
i 1	127.23996598639455	0.505	77	1072	6	5	3	16	0	2	16	0	0	11.606964696238188	
i 1	127.7544149659864	1.2625	74	890	6	5	2	17	0	2	17	0	0	11.606964696238188	
i 1	128.0020068027211	0.2525	74	188	6	5	2	16	0	1	16	0	0	11.606964696238188	
i 1	128.00762585034013	1.01	72	1072	5	1	3	1	0	0	1	0	0	7.72388007207531	
i 1	128.0132448979592	1.01	72	890	5	3	7	2	0	1	2	0	0	4.0	
i 1	128.24397959183673	0.505	70	188	3	20	3	8	0	-1	8	0	0	8.763456879477745	
i 1	128.24879591836734	0.2525	77	1072	6	5	16	16	0	1	16	0	0	11.606964696238188	
i 1	128.2544149659864	0.2525	72	890	6	1	6	1	0	-1	1	0	0	7.72388007207531	
i 1	128.26244217687074	0.505	73	188	2	24	3	8	0	-1	8	0	0	12.763456879477745	
i 1	128.49237414965987	1.01	72	188	5	1	7	1	0	0	1	0	0	7.72388007207531	
i 1	128.73514965986394	0.2525	70	890	3	24	15	2	0	-2	2	0	0	12.763456879477745	
i 1	128.7383605442177	0.505	73	188	1	24	5	8	0	252	8	307	0	12.763456879477745	
i 1	128.76725850340137	0.505	73	188	2	20	3	8	0	-1	8	0	0	8.763456879477745	
i 1	128.98033333333333	1.5150000000000001	75	686	5	3	3	2	0	1	2	0	0	4.0	
i 1	128.9867551020408	6.0600000000000005	66	188	5	26	14	6	0	2	6	0	0	0.4558924227131882	
i 1	128.98916326530613	3.0300000000000002	66	686	5	25	4	9	0	1	9	0	0	0.4558924227131882	
i 1	128.99157142857143	1.5150000000000001	69	1072	5	1	8	1	0	-1	1	0	0	7.72388007207531	
i 1	128.99397959183673	1.7675	73	188	1	24	14	2	0	248	2	308	0	12.763456879477745	
i 1	129.00842857142857	6.0600000000000005	66	686	5	25	3	6	0	1	6	0	0	0.4558924227131882	
i 1	129.0132448979592	0.2525	70	188	2	20	12	8	0	-1	8	0	0	8.763456879477745	
i 1	129.0156530612245	1.7675	77	1072	6	5	12	16	0	2	16	0	0	11.606964696238188	
i 1	129.23996598639457	0.7575000000000001	73	188	2	24	8	8	0	-1	8	0	0	12.763456879477745	
i 1	129.2544149659864	0.2525	77	1072	6	5	11	16	0	1	16	0	0	11.606964696238188	
i 1	129.2656530612245	0.7575000000000001	73	188	3	20	6	2	0	-1	2	0	0	8.763456879477745	
i 1	129.49719047619047	0.2525	69	188	4	1	10	1	0	-1	1	0	0	7.72388007207531	
i 1	129.5068231292517	0.2525	75	188	6	9	9	2	0	1	2	0	0	3.0	
i 1	129.51003401360543	0.505	77	188	7	5	4	17	0	2	17	0	0	11.606964696238188	
i 1	129.75521768707483	0.505	72	1072	6	2	9	2	0	-2	2	0	0	4.0	
i 1	129.75842857142857	0.505	72	188	5	1	13	1	0	0	1	0	0	7.72388007207531	
i 1	129.98354421768707	1.01	73	188	3	20	14	8	0	-2	8	0	0	8.763456879477745	
i 1	129.99879591836734	0.7575000000000001	70	188	3	20	8	2	0	-2	2	0	0	8.763456879477745	
i 1	130.009231292517	0.505	74	188	6	5	5	16	0	1	16	0	0	11.606964696238188	
i 1	130.23916326530613	0.2525	72	188	5	4	10	2	0	-2	2	0	0	4.0	
i 1	130.2431768707483	0.505	72	188	7	1	1	1	0	0	1	0	0	7.72388007207531	
i 1	130.4819387755102	0.7575000000000001	72	1072	6	2	6	2	0	-2	2	0	0	4.0	
i 1	130.4819387755102	0.2525	77	188	7	5	13	17	0	2	17	0	0	11.606964696238188	
i 1	130.4843469387755	0.2525	72	1072	6	2	10	2	0	-2	2	0	0	4.0	
i 1	130.50842857142857	0.2525	69	686	5	1	12	1	0	0	1	0	0	7.72388007207531	
i 1	130.74959863945577	0.2525	77	1072	6	5	7	16	0	1	16	0	0	11.606964696238188	
i 1	130.75280952380953	0.7575000000000001	69	1072	5	1	1	1	0	-1	1	0	0	7.72388007207531	
i 1	130.7568231292517	0.2525	70	1072	3	20	11	8	0	-2	8	0	0	8.763456879477745	
i 1	130.76404761904763	1.7675	77	686	6	5	16	16	0	2	16	0	0	11.606964696238188	
i 1	130.76645578231293	0.2525	72	686	4	24	5	0	0	0	0	0	0	8.72388007207531	
i 1	131.00842857142857	0.505	77	188	6	5	4	16	0	1	16	0	0	11.606964696238188	
i 1	131.01645578231293	1.01	73	188	3	24	8	2	0	-1	2	0	0	12.763456879477745	
i 1	131.01725850340137	1.01	70	188	2	24	11	2	0	-2	2	0	0	12.763456879477745	
i 1	131.2520068027211	1.5150000000000001	72	1072	6	2	2	2	0	-2	2	0	0	4.0	
i 1	131.5132448979592	0.2525	74	188	6	5	2	16	0	1	16	0	0	11.606964696238188	
i 1	131.51645578231293	1.5150000000000001	69	686	5	1	16	1	0	0	1	0	0	7.72388007207531	
i 1	131.76244217687074	0.2525	77	188	6	5	14	16	0	1	16	0	0	11.606964696238188	
i 1	131.9955850340136	0.2525	73	686	3	20	1	2	0	-1	2	0	0	8.763456879477745	
i 1	131.99879591836734	3.0300000000000002	66	188	5	26	16	9	0	2	9	0	0	0.4558924227131882	
i 1	132.00521768707483	2.525	61	188	4	27	4	6	0	1	6	0	0	12.802460130804567	
i 1	132.00842857142857	0.2525	73	188	2	24	15	8	0	-1	8	0	0	12.763456879477745	
i 1	132.0116394557823	3.0300000000000002	66	686	5	25	4	9	0	1	9	0	0	0.4558924227131882	
i 1	132.2343469387755	0.2525	73	188	2	24	16	8	0	-1	8	0	0	12.763456879477745	
i 1	132.2383605442177	0.2525	75	188	6	9	8	2	0	-2	2	0	0	3.0	
i 1	132.2479931972789	0.2525	73	188	3	24	3	2	0	-1	2	0	0	12.763456879477745	
i 1	132.259231292517	0.2525	74	686	6	5	12	17	0	2	17	0	0	11.606964696238188	
i 1	132.4843469387755	0.2525	73	188	3	20	7	8	0	-2	8	0	0	8.763456879477745	
i 1	132.49397959183673	0.2525	73	1072	3	20	2	8	0	-2	8	0	0	8.763456879477745	
i 1	132.4979931972789	1.7675	72	686	4	4	14	8	0	1	8	0	0	4.0	
i 1	132.5068231292517	1.01	77	1072	6	5	10	16	0	1	16	0	0	11.606964696238188	
i 1	132.51003401360543	0.505	74	188	6	5	2	16	0	1	16	0	0	11.606964696238188	
i 1	132.75521768707483	0.2525	75	188	6	9	13	2	0	1	2	0	0	3.0	
i 1	132.7616394557823	1.5150000000000001	73	188	2	24	16	8	0	-1	8	0	0	12.763456879477745	
i 1	132.76244217687074	1.5150000000000001	73	188	3	24	14	2	0	-1	2	0	0	12.763456879477745	
i 1	132.9819387755102	0.2525	72	1072	6	2	6	2	0	-2	2	0	0	4.0	
i 1	133.01083673469387	0.2525	77	188	7	5	5	17	0	2	17	0	0	11.606964696238188	
i 1	133.01404761904763	1.2625	72	686	4	24	15	0	0	0	0	0	0	8.72388007207531	
i 1	133.26485034013606	0.2525	74	188	6	5	4	16	0	1	16	0	0	11.606964696238188	
i 1	133.50040136054423	1.5150000000000001	74	686	6	5	10	17	0	2	17	0	0	11.606964696238188	
i 1	133.76244217687074	0.2525	75	188	6	9	4	2	0	1	2	0	0	3.0	
i 1	133.7632448979592	0.2525	69	188	5	24	10	0	0	-1	0	0	0	8.72388007207531	
i 1	133.7680612244898	0.2525	77	188	6	5	4	16	0	1	16	0	0	11.606964696238188	
i 1	134.00040136054423	0.2525	77	188	7	5	1	17	0	2	17	0	0	11.606964696238188	
i 1	134.0044149659864	0.505	75	188	5	3	12	2	0	1	2	0	0	4.0	
i 1	134.00842857142857	1.01	69	686	5	1	3	1	0	0	1	0	0	7.72388007207531	
i 1	134.23755782312926	0.2525	69	1072	5	1	13	1	0	-1	1	0	0	7.72388007207531	
i 1	134.26003401360543	0.2525	73	686	3	20	7	8	0	-2	8	0	0	8.763456879477745	
i 1	134.2680612244898	1.7675	75	686	5	3	15	2	0	1	2	0	0	4.0	
i 1	134.2680612244898	0.2525	73	188	2	24	12	8	0	-1	8	0	0	12.763456879477745	
i 1	134.48595238095237	0.505	61	188	4	27	13	6	0	1	6	0	0	12.802460130804567	
i 1	134.4883605442177	0.505	61	188	6	12	16	6	0	1	6	0	0	1.5909803063456631	
i 1	134.490768707483	0.505	61	188	6	12	12	9	0	2	9	0	0	1.5909803063456631	
i 1	134.49157142857143	0.505	72	188	4	4	1	2	0	-2	2	0	0	4.0	
i 1	134.50521768707483	0.505	66	890	5	25	1	6	0	1	6	0	0	0.4558924227131882	
i 1	134.50521768707483	1.7675	70	188	1	24	12	2	0	-1	2	0	0	12.763456879477745	
i 1	134.509231292517	0.505	66	890	5	25	14	9	0	1	9	0	0	0.4558924227131882	
i 1	134.51485034013606	1.7675	73	188	3	24	15	2	0	-1	2	0	0	12.763456879477745	
i 1	134.51725850340137	0.505	69	188	7	1	8	1	0	-1	1	0	0	7.72388007207531	
i 1	134.98033333333333	6.0600000000000005	66	188	4	27	16	6	0	2	6	0	0	12.64563780125233	
i 1	134.98996598639457	3.0300000000000002	61	188	4	27	13	6	0	1	6	0	0	12.64563780125233	
i 1	134.99397959183673	12.120000000000001	66	890	4	14	12	9	0	1	9	0	0	2.605531084707703	
i 1	134.99397959183673	6.565	61	686	4	7	3	6	0	1	6	0	0	1.3027655423538518	
i 1	134.99879591836734	0.2525	72	890	6	2	5	8	0	-2	8	0	0	4.0	
i 1	135.00120408163266	1.5150000000000001	69	686	5	1	7	1	0	0	1	0	0	8.90740117112652	
i 1	135.00521768707483	0.505	72	686	4	24	8	0	0	0	0	0	0	9.90740117112652	
i 1	135.0068231292517	3.0300000000000002	61	188	6	12	1	6	0	1	6	0	0	0.8475879430508959	
i 1	135.00762585034013	3.0300000000000002	66	188	5	26	12	6	0	2	6	0	0	0.29907009316095334	
i 1	135.00842857142857	6.0600000000000005	66	686	5	25	6	6	0	1	6	0	0	0.29907009316095334	
i 1	135.0116394557823	6.565	66	686	5	25	7	9	0	1	9	0	0	0.29907009316095334	
i 1	135.01244217687074	3.0300000000000002	66	890	5	25	4	6	0	1	6	0	0	0.29907009316095334	
i 1	135.01244217687074	9.3425	66	188	5	26	15	9	0	2	9	0	0	0.29907009316095334	
i 1	135.01404761904763	1.01	74	686	6	5	16	17	0	2	17	0	0	11.502682012294928	
i 1	135.01485034013606	12.120000000000001	61	890	4	14	8	6	0	1	6	0	0	2.605531084707703	
i 1	135.26244217687074	0.505	72	890	6	2	2	2	0	1	2	0	0	4.0	
i 1	135.50521768707483	0.2525	72	890	5	1	9	0	0	0	0	0	0	8.90740117112652	
i 1	135.76485034013606	0.7575000000000001	72	686	4	24	8	0	0	0	0	0	0	9.90740117112652	
i 1	135.7656530612245	0.2525	75	188	6	9	13	2	0	1	2	0	0	3.0	
i 1	135.99959863945577	2.02	77	890	6	5	5	16	0	1	16	0	0	11.502682012294928	
i 1	136.01003401360543	1.5150000000000001	72	686	4	4	15	8	0	1	8	0	0	4.0	
i 1	136.01485034013606	0.2525	72	890	6	2	13	8	0	-2	8	0	0	4.0	
i 1	136.2367551020408	0.7575000000000001	73	188	1	24	9	8	0	-1	8	0	0	12.763456879477745	
i 1	136.240768707483	0.7575000000000001	70	188	3	20	5	2	0	-1	2	0	0	8.763456879477745	
i 1	136.5020068027211	1.5150000000000001	69	890	5	1	9	0	0	-1	0	0	0	8.90740117112652	
i 1	136.50842857142857	0.2525	72	188	5	1	2	1	0	0	1	0	0	8.90740117112652	
i 1	136.73274149659863	0.2525	69	188	7	1	7	1	0	-1	1	0	0	8.90740117112652	
i 1	136.98274149659863	0.2525	70	686	3	24	13	8	0	-1	8	0	0	12.763456879477745	
i 1	137.009231292517	1.7675	73	188	1	20	2	8	0	-1	8	0	0	8.763456879477745	
i 1	137.0156530612245	1.7675	73	188	1	24	4	8	0	252	8	307	0	12.763456879477745	
i 1	137.2455850340136	0.2525	74	188	6	5	10	16	0	1	16	0	0	11.502682012294928	
i 1	137.24879591836734	0.2525	69	188	7	1	6	1	0	-1	1	0	0	8.90740117112652	
i 1	137.2616394557823	1.2625	73	188	1	20	7	8	0	-2	8	0	0	8.763456879477745	
i 1	137.50602040816327	0.505	77	686	6	5	16	16	0	2	16	0	0	11.502682012294928	
i 1	137.5068231292517	1.01	75	686	5	3	3	2	0	1	2	0	0	4.0	
i 1	137.5116394557823	0.7575000000000001	72	890	5	1	16	0	0	0	0	0	0	8.90740117112652	
i 1	137.9867551020408	6.3125	66	188	5	26	2	6	0	2	6	0	0	0.29907009316095334	
i 1	137.98916326530613	1.01	74	686	6	5	14	17	0	2	17	0	0	11.502682012294928	
i 1	137.99879591836734	1.01	69	686	5	1	16	1	0	0	1	0	0	8.90740117112652	
i 1	138.00762585034013	0.2525	72	890	6	2	16	8	0	-2	8	0	0	4.0	
i 1	138.01404761904763	3.0300000000000002	61	188	3	27	6	6	0	1	6	0	0	12.64563780125233	
i 1	138.01886394557823	0.2525	77	188	4	5	7	17	0	2	17	0	0	11.502682012294928	
i 1	138.2383605442177	0.505	74	188	6	5	5	16	0	1	16	0	0	11.502682012294928	
i 1	138.2455850340136	1.5150000000000001	72	890	6	2	12	2	0	1	2	0	0	4.0	
i 1	138.26083673469387	0.2525	72	188	5	1	7	1	0	0	1	0	0	8.90740117112652	
i 1	138.4867551020408	0.2525	75	188	6	9	2	2	0	-2	2	0	0	3.0	
i 1	138.4883605442177	0.2525	70	686	3	24	9	2	0	-2	2	0	0	12.763456879477745	
i 1	138.50040136054423	0.2525	72	890	5	1	4	0	0	0	0	0	0	8.90740117112652	
i 1	138.73274149659863	0.2525	72	890	6	2	15	8	0	-2	8	0	0	4.0	
i 1	138.73514965986394	0.7575000000000001	73	188	1	24	4	2	0	252	2	307	0	12.763456879477745	
i 1	138.7367551020408	0.7575000000000001	73	188	1	24	8	8	0	-1	8	0	0	12.763456879477745	
i 1	138.74397959183673	0.2525	69	188	5	24	8	0	0	-1	0	0	0	9.90740117112652	
i 1	138.7544149659864	0.2525	77	188	4	5	8	17	0	2	17	0	0	11.502682012294928	
i 1	138.7656530612245	0.7575000000000001	73	188	3	20	9	2	0	-1	2	0	0	8.763456879477745	
i 1	138.9955850340136	1.01	72	686	4	24	1	0	0	0	0	0	0	9.90740117112652	
i 1	139.00361224489797	1.5150000000000001	77	890	6	5	14	16	0	1	16	0	0	11.502682012294928	
i 1	139.0180612244898	0.2525	77	188	6	5	12	16	0	1	16	0	0	11.502682012294928	
i 1	139.25842857142857	0.2525	69	890	5	1	9	0	0	-1	0	0	0	8.90740117112652	
i 1	139.48996598639457	0.7575000000000001	73	188	1	24	1	8	0	252	8	307	0	12.763456879477745	
i 1	139.49959863945577	0.7575000000000001	73	188	1	24	15	2	0	-2	2	0	0	12.763456879477745	
i 1	139.5132448979592	0.505	72	890	5	1	9	0	0	0	0	0	0	8.90740117112652	
i 1	139.51645578231293	0.2525	72	188	5	4	11	2	0	-2	2	0	0	4.0	
i 1	139.51725850340137	0.7575000000000001	73	188	3	24	10	2	0	-1	2	0	0	12.763456879477745	
i 1	139.74959863945577	0.7575000000000001	72	686	4	4	2	8	0	1	8	0	0	4.0	
i 1	139.7656530612245	1.7675	72	890	6	2	6	8	0	-2	8	0	0	4.0	
i 1	140.00762585034013	0.505	72	188	5	1	15	1	0	0	1	0	0	8.90740117112652	
i 1	140.01404761904763	1.5150000000000001	69	686	5	1	15	1	0	0	1	0	0	8.90740117112652	
i 1	140.23996598639457	0.2525	73	188	1	24	7	8	0	-1	8	0	0	12.763456879477745	
i 1	140.24237414965987	0.2525	73	686	3	20	8	2	0	-1	2	0	0	8.763456879477745	
i 1	140.48033333333333	0.2525	73	188	3	20	6	8	0	-2	8	0	0	8.763456879477745	
i 1	140.48354421768707	0.2525	72	686	4	24	7	0	0	0	0	0	0	9.90740117112652	
i 1	140.49638775510203	0.2525	70	890	3	20	2	2	0	-2	2	0	0	8.763456879477745	
i 1	140.51083673469387	0.2525	75	188	5	3	4	2	0	1	2	0	0	4.0	
i 1	140.5180612244898	1.01	74	686	6	5	9	17	0	2	17	0	0	11.502682012294928	
i 1	140.7383605442177	0.2525	73	188	1	24	4	8	0	-1	8	0	0	12.763456879477745	
i 1	140.74157142857143	0.2525	73	188	3	24	7	2	0	-1	2	0	0	12.763456879477745	
i 1	140.74879591836734	0.2525	69	188	5	24	15	0	0	-1	0	0	0	9.90740117112652	
i 1	140.74879591836734	0.2525	72	890	6	2	6	2	0	1	2	0	0	4.0	
i 1	140.9931768707483	0.2525	69	188	5	1	11	1	0	-1	1	0	0	8.90740117112652	
i 1	140.9955850340136	3.0300000000000002	66	188	3	27	13	6	0	2	6	0	0	12.64563780125233	
i 1	141.00120408163266	0.7575000000000001	73	188	3	24	16	2	0	-1	2	0	0	13.186790662119648	
i 1	141.00521768707483	0.2525	74	188	4	5	8	17	0	2	17	0	0	11.502682012294928	
i 1	141.01244217687074	0.7575000000000001	73	188	1	24	13	8	0	-1	8	0	0	13.186790662119648	
i 1	141.0156530612245	3.2825	61	188	4	27	13	6	0	1	6	0	0	12.64563780125233	
i 1	141.2479931972789	0.2525	72	686	4	4	3	8	0	1	8	0	0	4.0	
i 1	141.259231292517	0.7575000000000001	69	188	5	24	12	0	0	-1	0	0	0	9.90740117112652	
i 1	141.2616394557823	0.505	74	188	6	5	10	16	0	1	16	0	0	11.502682012294928	
i 1	141.4819387755102	0.2525	77	574	6	5	15	17	0	2	17	0	0	11.502682012294928	
i 1	141.4883605442177	2.525	61	574	5	25	5	6	0	1	6	0	0	0.29907009316095334	
i 1	141.4931768707483	1.5150000000000001	72	890	6	2	9	2	0	1	2	0	0	4.0	
i 1	141.4931768707483	5.555	66	574	4	7	1	6	0	2	6	0	0	1.3027655423538518	
i 1	141.50040136054423	0.505	72	188	5	4	12	2	0	-2	2	0	0	4.0	
i 1	141.50762585034013	0.2525	72	574	5	1	12	1	0	-1	1	0	0	8.90740117112652	
i 1	141.73595238095237	0.2525	77	188	4	5	2	17	0	2	17	0	0	11.502682012294928	
i 1	141.740768707483	0.2525	72	574	4	24	11	0	0	0	0	0	0	9.90740117112652	
i 1	141.75040136054423	0.2525	73	188	1	20	8	8	0	-1	8	0	0	9.186790662119648	
i 1	141.75280952380953	0.2525	73	574	3	24	12	8	0	-2	8	0	0	13.186790662119648	
i 1	141.76003401360543	1.7675	77	890	6	5	7	16	0	1	16	0	0	11.502682012294928	
i 1	141.98354421768707	1.5150000000000001	72	574	5	1	16	1	0	-1	1	0	0	8.90740117112652	
i 1	141.9843469387755	0.505	72	890	6	2	12	8	0	-2	8	0	0	4.0	
i 1	141.99237414965987	0.2525	73	188	3	20	1	8	0	-1	8	0	0	9.186790662119648	
i 1	141.99478231292517	0.2525	73	188	1	24	12	8	0	-1	8	0	0	13.186790662119648	
i 1	142.00280952380953	0.7575000000000001	74	188	4	5	1	17	0	2	17	0	0	11.502682012294928	
i 1	142.24237414965987	1.01	70	188	1	20	9	2	0	-2	2	0	0	9.186790662119648	
i 1	142.2680612244898	1.01	73	188	1	20	2	8	0	-1	8	0	0	9.186790662119648	
i 1	142.4819387755102	0.2525	72	574	5	3	3	2	0	1	2	0	0	4.0	
i 1	142.73916326530613	0.2525	75	188	6	9	4	2	0	1	2	0	0	3.0	
i 1	142.7656530612245	0.2525	77	188	4	5	7	17	0	2	17	0	0	11.502682012294928	
i 1	142.99397959183673	1.5150000000000001	72	574	5	3	12	2	0	1	2	0	0	4.0	
i 1	143.0180612244898	0.2525	74	188	6	5	5	16	0	1	16	0	0	11.502682012294928	
i 1	143.24638775510203	0.505	73	188	3	20	6	8	0	-1	8	0	0	9.186790662119648	
i 1	143.25842857142857	0.2525	74	188	4	5	6	17	0	2	17	0	0	11.502682012294928	
i 1	143.2616394557823	0.505	73	188	1	24	13	8	0	-1	8	0	0	13.186790662119648	
i 1	143.49638775510203	0.2525	72	890	6	2	8	2	0	1	2	0	0	4.0	
i 1	143.50521768707483	1.2625	69	890	6	1	16	0	0	-1	0	0	0	8.90740117112652	
i 1	143.50762585034013	0.505	74	574	6	5	13	17	0	2	17	0	0	11.502682012294928	
i 1	143.5132448979592	0.505	77	890	4	5	16	16	0	1	16	0	0	11.502682012294928	
i 1	143.74879591836734	0.2525	70	890	3	20	2	2	0	-1	2	0	0	9.186790662119648	
i 1	143.75842857142857	0.505	73	188	3	24	15	2	0	-1	2	0	0	13.186790662119648	
i 1	143.9955850340136	1.5150000000000001	72	574	4	4	2	2	0	1	2	0	0	4.0	
i 1	144.00040136054423	0.2525	77	574	6	5	15	17	0	2	17	0	0	11.502682012294928	
i 1	144.00602040816327	0.2525	73	188	1	24	9	2	0	-2	2	0	0	13.186790662119648	
i 1	144.009231292517	0.7575000000000001	74	574	4	5	13	17	0	2	17	0	0	11.502682012294928	
i 1	144.01966666666667	0.2525	66	188	4	27	13	6	0	2	6	0	0	12.64563780125233	
i 1	144.23354421768707	2.7775	73	1156	1	24	10	8	0	252	8	307	0	13.186790662119648	
i 1	144.23755782312926	0.2525	72	187	3	1	12	0	0	0	0	0	0	8.90740117112652	
i 1	144.24638775510203	2.7775	61	1156	4	26	11	9	0	1	9	0	0	0.29907009316095334	
i 1	144.24879591836734	1.01	73	1156	3	20	11	8	0	-1	8	0	0	9.186790662119648	
i 1	144.25280952380953	2.7775	61	187	4	27	9	9	0	1	9	0	0	12.64563780125233	
i 1	144.25602040816327	0.2525	74	187	4	5	5	17	0	2	17	0	0	11.502682012294928	
i 1	144.25602040816327	1.01	73	1156	3	20	5	8	0	-1	8	0	0	9.186790662119648	
i 1	144.2632448979592	2.7775	66	187	4	27	6	6	0	1	6	0	0	12.64563780125233	
i 1	144.26966666666667	2.7775	61	1156	4	26	11	9	0	2	9	0	0	0.29907009316095334	
i 1	144.50521768707483	0.7575000000000001	75	1156	5	9	12	2	0	-2	2	0	0	3.0	
i 1	144.5132448979592	1.5150000000000001	77	574	6	5	5	17	0	2	17	0	0	11.502682012294928	
i 1	144.5180612244898	1.5150000000000001	72	574	5	1	14	1	0	-1	1	0	0	8.90740117112652	
i 1	144.73354421768707	0.505	74	187	4	5	10	17	0	2	17	0	0	11.502682012294928	
i 1	144.7680612244898	0.2525	72	890	6	1	14	0	0	0	0	0	0	8.90740117112652	
i 1	144.98916326530613	0.2525	69	890	6	1	13	0	0	-1	0	0	0	8.90740117112652	
i 1	145.23033333333333	0.2525	77	187	4	5	12	17	0	2	17	0	0	11.502682012294928	
i 1	145.23514965986394	0.2525	70	187	1	20	8	8	0	-1	8	0	0	9.186790662119648	
i 1	145.24237414965987	0.2525	72	187	3	1	8	0	0	0	0	0	0	8.90740117112652	
i 1	145.259231292517	1.5150000000000001	72	574	5	3	3	2	0	1	2	0	0	4.0	
i 1	145.26645578231293	0.2525	70	187	1	24	12	2	0	-1	2	0	0	13.186790662119648	
i 1	145.49638775510203	1.01	73	1156	3	20	15	8	0	-1	8	0	0	9.186790662119648	
i 1	145.4979931972789	0.2525	77	890	6	5	12	16	0	1	16	0	0	11.502682012294928	
i 1	145.4979931972789	1.01	73	1156	3	20	3	8	0	-1	8	0	0	9.186790662119648	
i 1	145.5020068027211	0.2525	75	1156	5	9	1	2	0	-2	2	0	0	3.0	
i 1	145.5044149659864	1.5150000000000001	72	574	4	24	7	0	0	0	0	0	0	9.90740117112652	
i 1	145.73916326530613	0.2525	72	890	6	2	1	2	0	1	2	0	0	4.0	
i 1	145.990768707483	0.7575000000000001	69	187	3	24	10	0	0	-1	0	0	0	9.90740117112652	
i 1	145.9931768707483	1.01	77	890	6	5	10	16	0	1	16	0	0	11.502682012294928	
i 1	146.48274149659863	0.505	70	187	1	24	11	8	0	-2	8	0	0	13.186790662119648	
i 1	146.51725850340137	0.505	70	187	1	20	3	8	0	-1	8	0	0	9.186790662119648	
i 1	146.7383605442177	0.2525	72	1156	5	1	14	0	0	0	0	0	0	8.90740117112652	
i 1	146.98595238095237	0.505	72	697	6	1	14	1	0	0	1	0	0	8.90740117112652	
i 1	146.98755782312926	12.120000000000001	66	697	4	14	3	9	0	1	9	0	0	2.605531084707703	
i 1	146.9931768707483	0.2525	70	697	1	24	7	2	0	-2	2	0	0	13.186790662119648	
i 1	146.99478231292517	18.18	61	199	4	7	8	9	0	1	9	0	0	1.3027655423538518	
i 1	146.9955850340136	3.0300000000000002	66	1083	4	26	4	6	0	2	6	0	0	0.29907009316095334	
i 1	146.99719047619047	0.7575000000000001	75	199	5	4	2	2	0	1	2	0	0	4.0	
i 1	146.9979931972789	6.0600000000000005	66	697	3	27	6	9	0	1	9	0	0	12.64563780125233	
i 1	147.00521768707483	0.2525	69	697	6	1	2	1	0	-1	1	0	0	8.90740117112652	
i 1	147.00602040816327	0.2525	70	1083	2	20	15	8	0	-2	8	0	0	9.186790662119648	
i 1	147.0132448979592	9.09	61	697	4	14	5	9	0	1	9	0	0	2.605531084707703	
i 1	147.01485034013606	9.09	61	697	3	27	1	6	0	2	6	0	0	12.64563780125233	
i 1	147.01645578231293	18.18	61	697	5	25	9	9	0	2	9	0	0	0.29907009316095334	
i 1	147.240768707483	0.2525	73	1083	2	24	6	8	0	-2	8	0	0	13.186790662119648	
i 1	147.24719047619047	1.7675	74	199	4	5	12	17	0	2	17	0	0	11.502682012294928	
i 1	147.24959863945577	0.2525	69	199	6	1	14	0	0	0	0	0	0	8.90740117112652	
i 1	147.26966666666667	0.2525	74	697	6	5	2	17	0	2	17	0	0	11.502682012294928	
i 1	147.26966666666667	0.2525	73	697	3	20	16	2	0	-2	2	0	0	9.186790662119648	
i 1	147.48113605442177	0.505	72	697	3	24	3	1	0	-1	1	0	0	9.90740117112652	
i 1	147.49237414965987	0.505	74	199	7	5	9	17	0	1	17	0	0	11.502682012294928	
i 1	147.49879591836734	1.5150000000000001	72	199	5	24	11	1	0	-1	1	0	0	9.90740117112652	
i 1	147.5068231292517	1.01	73	697	1	20	11	8	0	-2	8	0	0	9.186790662119648	
i 1	147.51886394557823	1.01	73	697	1	20	5	8	0	-1	8	0	0	9.186790662119648	
i 1	147.7520068027211	1.5150000000000001	72	199	6	3	16	2	0	-2	2	0	0	4.0	
i 1	148.01003401360543	0.2525	74	1083	5	5	2	16	0	1	16	0	0	11.502682012294928	
i 1	148.01404761904763	0.2525	69	199	6	1	3	0	0	0	0	0	0	8.90740117112652	
i 1	148.2568231292517	0.2525	74	697	6	5	9	17	0	2	17	0	0	11.502682012294928	
i 1	148.26966666666667	0.2525	72	697	3	24	11	1	0	-1	1	0	0	9.90740117112652	
i 1	148.4819387755102	1.5150000000000001	74	697	4	5	2	17	0	2	17	0	0	11.502682012294928	
i 1	148.50040136054423	0.2525	70	697	1	24	2	2	0	-2	2	0	0	13.186790662119648	
i 1	148.50602040816327	0.2525	70	1083	2	20	10	2	0	-2	2	0	0	9.186790662119648	
i 1	148.51485034013606	0.2525	69	1083	4	1	15	0	0	0	0	0	0	8.90740117112652	
i 1	148.74478231292517	0.2525	75	1083	5	9	4	8	0	-2	8	0	0	3.0	
i 1	148.7520068027211	1.5150000000000001	70	697	1	24	4	8	0	-1	8	0	0	13.186790662119648	
i 1	148.75602040816327	1.2625	69	199	6	1	13	0	0	0	0	0	0	8.90740117112652	
i 1	148.75842857142857	1.5150000000000001	73	1083	2	24	1	8	0	-2	8	0	0	13.186790662119648	
i 1	148.99397959183673	0.2525	74	697	4	5	13	16	0	1	16	0	0	11.502682012294928	
i 1	148.99638775510203	0.2525	72	697	6	1	6	1	0	0	1	0	0	8.90740117112652	
i 1	149.0156530612245	1.7675	75	697	5	2	1	2	0	-2	2	0	0	4.0	
i 1	149.2319387755102	0.7575000000000001	72	697	4	4	6	2	0	1	2	0	0	4.0	
i 1	149.2568231292517	0.2525	72	199	5	24	2	1	0	-1	1	0	0	9.90740117112652	
i 1	149.2656530612245	0.2525	74	1083	5	5	13	16	0	1	16	0	0	11.502682012294928	
i 1	149.5020068027211	0.2525	72	697	3	24	5	1	0	-1	1	0	0	9.90740117112652	
i 1	149.74397959183673	1.2625	69	697	6	1	8	1	0	-1	1	0	0	8.90740117112652	
i 1	149.76886394557823	0.2525	74	697	4	5	10	16	0	1	16	0	0	11.502682012294928	
i 1	149.98996598639457	1.01	74	199	7	5	9	17	0	1	17	0	0	11.502682012294928	
i 1	149.990768707483	12.120000000000001	61	697	5	14	14	6	0	1	6	0	0	1.643567654185799	
i 1	149.99397959183673	18.18	61	697	5	25	3	6	0	2	6	0	0	0.29907009316095334	
i 1	149.99959863945577	0.2525	75	1083	5	9	1	8	0	-2	8	0	0	3.0	
i 1	150.01404761904763	0.7575000000000001	74	199	7	5	7	17	0	2	17	0	0	11.502682012294928	
i 1	150.01645578231293	0.2525	72	1083	4	1	5	1	0	-1	1	0	0	8.90740117112652	
i 1	150.240768707483	0.2525	69	697	3	1	5	1	0	0	1	0	0	8.90740117112652	
i 1	150.240768707483	0.7575000000000001	70	1083	2	20	9	2	0	-2	2	0	0	9.186790662119648	
i 1	150.26083673469387	0.7575000000000001	70	697	1	24	12	2	0	-2	2	0	0	13.186790662119648	
i 1	150.26725850340137	0.2525	72	199	6	3	4	2	0	-2	2	0	0	4.0	
i 1	150.73033333333333	1.01	74	697	4	5	6	16	0	1	16	0	0	11.502682012294928	
i 1	150.76645578231293	0.7575000000000001	72	199	6	3	11	2	0	-2	2	0	0	4.0	
i 1	150.98755782312926	1.5150000000000001	69	199	6	1	7	0	0	0	0	0	0	8.90740117112652	
i 1	151.00521768707483	0.2525	73	697	4	20	15	2	0	-2	2	0	0	9.186790662119648	
i 1	151.01404761904763	0.2525	73	1083	2	24	1	8	0	-2	8	0	0	13.186790662119648	
i 1	151.0156530612245	1.5150000000000001	74	199	7	5	13	17	0	2	17	0	0	11.502682012294928	
i 1	151.25040136054423	1.01	73	697	1	20	15	8	0	-1	8	0	0	9.186790662119648	
i 1	151.2568231292517	1.01	73	697	1	20	6	2	0	-2	2	0	0	9.186790662119648	
i 1	151.5180612244898	1.5150000000000001	75	199	5	4	4	2	0	1	2	0	0	4.0	
i 1	151.75280952380953	0.2525	74	1083	3	5	5	17	0	2	17	0	0	11.502682012294928	
i 1	151.75361224489797	0.2525	72	199	6	3	1	2	0	-2	2	0	0	4.0	
i 1	151.98996598639457	0.2525	74	199	7	5	15	17	0	1	17	0	0	11.502682012294928	
i 1	152.0116394557823	0.505	72	697	4	4	5	2	0	1	2	0	0	4.0	
i 1	152.2383605442177	0.2525	73	1083	2	20	8	8	0	-1	8	0	0	9.186790662119648	
i 1	152.25762585034013	0.2525	70	697	1	24	13	2	0	-2	2	0	0	13.186790662119648	
i 1	152.49478231292517	1.01	73	1083	2	24	7	8	0	-2	8	0	0	13.186790662119648	
i 1	152.4979931972789	1.01	73	697	1	24	15	2	0	-1	2	0	0	13.186790662119648	
i 1	152.49879591836734	0.2525	75	1083	5	9	2	8	0	-2	8	0	0	3.0	
i 1	152.50120408163266	1.2625	70	697	1	24	13	2	0	252	2	307	0	13.186790662119648	
i 1	152.74959863945577	1.5150000000000001	74	199	7	5	5	17	0	2	17	0	0	11.502682012294928	
i 1	152.75120408163266	0.505	69	697	3	1	10	1	0	0	1	0	0	8.90740117112652	
i 1	152.7520068027211	0.2525	72	697	5	3	3	2	0	-2	2	0	0	4.0	
i 1	152.76404761904763	0.2525	69	199	6	1	10	0	0	0	0	0	0	8.90740117112652	
i 1	152.99719047619047	1.7675	72	199	5	3	11	2	0	-2	2	0	0	4.0	
i 1	153.01083673469387	18.18	61	199	5	25	11	9	0	2	9	0	0	0.29907009316095334	
i 1	153.01244217687074	1.5150000000000001	69	697	6	1	10	1	0	-1	1	0	0	8.90740117112652	
i 1	153.24638775510203	0.2525	72	697	3	24	10	1	0	-1	1	0	0	9.90740117112652	
i 1	153.25762585034013	0.2525	72	697	4	3	2	2	0	-2	2	0	0	4.0	
i 1	153.5132448979592	0.2525	70	199	3	24	5	8	0	-1	8	0	0	13.186790662119648	
i 1	153.51645578231293	0.505	75	1083	5	9	4	8	0	-2	8	0	0	3.0	
i 1	153.5180612244898	0.2525	73	697	1	20	4	8	0	-1	8	0	0	9.186790662119648	
i 1	153.51966666666667	0.2525	72	697	6	1	16	1	0	0	1	0	0	8.90740117112652	
i 1	153.75361224489797	1.01	73	1083	3	20	1	2	0	-2	2	0	0	9.186790662119648	
i 1	153.76244217687074	1.01	70	697	1	24	15	2	0	-2	2	0	0	13.186790662119648	
i 1	153.99157142857143	0.2525	72	697	4	3	3	2	0	-2	2	0	0	4.0	
i 1	154.00361224489797	0.2525	72	199	5	24	10	1	0	-1	1	0	0	9.90740117112652	
i 1	154.2343469387755	1.7675	75	697	5	2	7	2	0	-2	2	0	0	4.0	
i 1	154.2616394557823	0.505	72	697	6	1	8	1	0	0	1	0	0	8.90740117112652	
i 1	154.509231292517	1.01	69	199	6	1	15	0	0	0	0	0	0	8.90740117112652	
i 1	154.51244217687074	1.2625	74	199	7	5	2	17	0	2	17	0	0	11.502682012294928	
i 1	154.73113605442177	0.2525	72	697	4	3	1	2	0	-2	2	0	0	4.0	
i 1	154.73916326530613	0.2525	72	1083	5	1	14	1	0	-1	1	0	0	8.90740117112652	
i 1	154.740768707483	0.505	73	697	1	20	7	8	0	-1	8	0	0	9.186790662119648	
i 1	154.75521768707483	0.505	70	697	1	20	8	8	0	-1	8	0	0	9.186790662119648	
i 1	154.98274149659863	0.2525	75	1083	5	9	5	8	0	-2	8	0	0	3.0	
i 1	154.98514965986394	0.2525	72	697	6	1	6	1	0	0	1	0	0	8.90740117112652	
i 1	155.24879591836734	0.2525	73	199	3	20	1	8	0	-1	8	0	0	9.186790662119648	
i 1	155.2632448979592	0.2525	70	697	1	24	1	2	0	-2	2	0	0	13.186790662119648	
i 1	155.26404761904763	0.2525	74	697	4	5	16	17	0	1	17	0	0	11.502682012294928	
i 1	155.49397959183673	0.2525	73	697	1	20	9	8	0	-1	8	0	0	9.186790662119648	
i 1	155.50521768707483	0.2525	73	199	3	24	16	8	0	-2	8	0	0	13.186790662119648	
i 1	155.5180612244898	1.01	72	199	5	24	11	1	0	-1	1	0	0	9.90740117112652	
i 1	155.51966666666667	2.525	74	697	4	5	14	17	0	2	17	0	0	11.502682012294928	
i 1	155.73113605442177	0.2525	75	1083	5	9	12	8	0	-2	8	0	0	3.0	
i 1	155.74959863945577	0.2525	74	1083	3	5	12	16	0	1	16	0	0	11.502682012294928	
i 1	155.98274149659863	12.120000000000001	61	199	6	15	11	6	0	1	6	0	0	0.05160823191599277	
i 1	155.99237414965987	9.09	61	697	5	14	1	9	0	1	9	0	0	2.605531084707703	
i 1	155.99638775510203	0.2525	73	697	4	20	7	2	0	-2	2	0	0	9.186790662119648	
i 1	155.99638775510203	0.2525	70	1083	2	20	2	8	0	-2	8	0	0	9.186790662119648	
i 1	156.0020068027211	0.7575000000000001	75	697	6	2	15	2	0	-2	2	0	0	4.0	
i 1	156.01244217687074	0.2525	74	1083	6	5	4	17	0	2	17	0	0	11.502682012294928	
i 1	156.01485034013606	2.2725	75	199	5	4	1	2	0	1	2	0	0	4.0	
i 1	156.01485034013606	16.16	61	199	5	25	12	9	0	2	9	0	0	0.29907009316095334	
i 1	156.23113605442177	1.01	73	1083	3	20	10	8	0	-1	8	0	0	9.186790662119648	
i 1	156.26485034013606	1.01	70	697	1	24	11	2	0	-2	2	0	0	13.186790662119648	
i 1	156.49478231292517	1.5150000000000001	69	199	6	1	2	0	0	0	0	0	0	8.90740117112652	
i 1	156.75120408163266	0.2525	69	1083	5	1	11	0	0	0	0	0	0	8.90740117112652	
i 1	156.76725850340137	0.2525	75	1083	5	9	8	8	0	-2	8	0	0	3.0	
i 1	156.990768707483	0.2525	74	697	4	5	10	17	0	2	17	0	0	11.502682012294928	
i 1	156.9979931972789	0.2525	75	697	6	2	10	2	0	-2	2	0	0	4.0	
i 1	157.24157142857143	0.2525	73	697	2	20	12	8	0	-1	8	0	0	9.186790662119648	
i 1	157.25120408163266	0.2525	69	1083	5	1	8	0	0	0	0	0	0	8.90740117112652	
i 1	157.25762585034013	0.7575000000000001	74	1083	6	5	15	16	0	1	16	0	0	11.502682012294928	
i 1	157.2632448979592	0.7575000000000001	73	697	1	20	13	8	0	-1	8	0	0	9.186790662119648	
i 1	157.490768707483	0.2525	72	1083	5	1	14	1	0	-1	1	0	0	8.90740117112652	
i 1	157.50040136054423	0.505	73	199	3	24	2	2	0	-1	2	0	0	13.186790662119648	
i 1	157.73595238095237	0.505	72	697	3	24	8	1	0	-1	1	0	0	9.90740117112652	
i 1	157.76886394557823	0.2525	72	1083	5	9	14	2	0	-2	2	0	0	3.0	
i 1	157.990768707483	0.2525	73	1083	3	20	11	8	0	-1	8	0	0	9.186790662119648	
i 1	158.00120408163266	0.505	72	697	4	3	1	2	0	-2	2	0	0	4.0	
i 1	158.0044149659864	1.7675	74	199	4	5	15	17	0	2	17	0	0	11.502682012294928	
i 1	158.0068231292517	0.2525	70	1083	2	20	6	8	0	-2	8	0	0	9.186790662119648	
i 1	158.0156530612245	0.2525	69	697	6	1	16	1	0	-1	1	0	0	8.90740117112652	
i 1	158.0180612244898	0.2525	74	199	4	5	15	17	0	1	17	0	0	11.502682012294928	
i 1	158.2383605442177	0.2525	69	199	6	1	13	0	0	0	0	0	0	8.90740117112652	
i 1	158.24959863945577	0.2525	70	199	4	20	3	8	0	-2	8	0	0	9.186790662119648	
i 1	158.2544149659864	0.2525	70	697	1	24	13	2	0	-2	2	0	0	13.186790662119648	
i 1	158.25602040816327	0.505	69	697	3	1	11	1	0	0	1	0	0	8.90740117112652	
i 1	158.2616394557823	0.505	74	697	4	5	13	17	0	2	17	0	0	11.502682012294928	
i 1	158.26244217687074	0.7575000000000001	72	199	5	3	1	2	0	-2	2	0	0	4.0	
i 1	158.4883605442177	1.2625	73	697	1	20	15	8	0	-1	8	0	0	9.186790662119648	
i 1	158.49397959183673	0.2525	75	697	6	2	15	2	0	-2	2	0	0	4.0	
i 1	158.50040136054423	1.5150000000000001	72	199	5	24	11	1	0	-1	1	0	0	9.90740117112652	
i 1	158.5044149659864	1.01	73	697	2	20	12	2	0	-1	2	0	0	9.186790662119648	
i 1	158.73033333333333	0.2525	75	199	5	4	6	2	0	1	2	0	0	4.0	
i 1	158.7343469387755	0.2525	74	697	2	5	2	16	0	1	16	0	0	11.502682012294928	
i 1	158.7479931972789	0.2525	69	1083	5	1	7	0	0	0	0	0	0	8.90740117112652	
i 1	158.98113605442177	0.2525	74	697	3	5	16	17	0	1	17	0	0	11.502682012294928	
i 1	158.98916326530613	1.5150000000000001	75	697	6	2	16	2	0	-2	2	0	0	4.0	
i 1	158.99719047619047	0.2525	69	697	6	1	1	1	0	-1	1	0	0	8.90740117112652	
i 1	159.0044149659864	13.13	61	1083	4	26	10	9	0	1	9	0	0	0.29907009316095334	
i 1	159.00521768707483	9.09	66	697	5	14	7	9	0	1	9	0	0	2.605531084707703	
i 1	159.0156530612245	12.120000000000001	66	199	6	15	16	9	0	1	9	0	0	0.05160823191599277	
i 1	159.26404761904763	0.2525	74	1083	6	5	11	16	0	1	16	0	0	11.502682012294928	
i 1	159.26645578231293	0.2525	69	199	6	1	2	0	0	0	0	0	0	8.90740117112652	
i 1	159.49397959183673	0.2525	73	199	4	24	7	2	0	-2	2	0	0	13.186790662119648	
i 1	159.49638775510203	0.2525	75	1083	4	9	6	8	0	-2	8	0	0	3.0	
i 1	159.49879591836734	0.505	74	1083	3	5	9	17	0	2	17	0	0	11.502682012294928	
i 1	159.5180612244898	0.505	69	697	6	1	4	1	0	-1	1	0	0	8.90740117112652	
i 1	159.73113605442177	1.5150000000000001	70	1083	2	20	10	8	0	-2	8	0	0	9.186790662119648	
i 1	159.7319387755102	0.505	72	697	4	3	12	2	0	-2	2	0	0	4.0	
i 1	159.7343469387755	1.5150000000000001	70	1083	3	20	14	8	0	-1	8	0	0	9.186790662119648	
i 1	159.75280952380953	0.2525	74	697	4	5	7	17	0	2	17	0	0	11.502682012294928	
i 1	159.98033333333333	1.01	74	199	4	5	14	17	0	2	17	0	0	11.502682012294928	
i 1	160.00040136054423	1.01	69	199	6	1	5	0	0	0	0	0	0	8.90740117112652	
i 1	160.00521768707483	0.2525	74	697	4	5	10	17	0	2	17	0	0	11.502682012294928	
i 1	160.00762585034013	0.2525	72	697	3	24	13	1	0	-1	1	0	0	9.90740117112652	
i 1	160.24959863945577	0.2525	72	1083	5	1	16	1	0	-1	1	0	0	8.90740117112652	
i 1	160.2656530612245	0.2525	72	697	4	4	13	2	0	1	2	0	0	4.0	
i 1	160.4931768707483	0.505	69	1083	5	1	2	0	0	0	0	0	0	8.90740117112652	
i 1	160.50521768707483	0.2525	75	1083	4	9	15	8	0	-2	8	0	0	3.0	
i 1	160.50762585034013	1.5150000000000001	72	199	5	3	14	2	0	-2	2	0	0	4.0	
i 1	160.7632448979592	0.505	75	697	6	2	1	2	0	-2	2	0	0	4.0	
i 1	161.01485034013606	0.2525	72	199	5	24	2	1	0	-1	1	0	0	9.90740117112652	
i 1	161.0156530612245	1.01	74	199	4	5	2	17	0	1	17	0	0	11.502682012294928	
i 1	161.01725850340137	1.01	69	697	6	1	4	1	0	-1	1	0	0	8.90740117112652	
i 1	161.23033333333333	0.7575000000000001	70	697	1	24	6	2	0	-2	2	0	0	13.186790662119648	
i 1	161.2455850340136	0.2525	72	697	3	24	5	1	0	-1	1	0	0	9.90740117112652	
i 1	161.2455850340136	0.2525	72	697	4	4	14	2	0	1	2	0	0	4.0	
i 1	161.25602040816327	0.7575000000000001	70	1083	3	20	15	2	0	-2	2	0	0	9.186790662119648	
i 1	161.50361224489797	0.2525	72	697	4	3	11	2	0	-2	2	0	0	4.0	
i 1	161.74719047619047	0.2525	75	1083	4	9	9	8	0	-2	8	0	0	3.0	
i 1	161.98033333333333	0.7575000000000001	75	199	5	4	6	2	0	1	2	0	0	4.0	
i 1	162.00361224489797	10.1	66	1083	4	16	13	6	0	2	6	0	0	0.8475879430508959	
i 1	162.00762585034013	2.2725	69	199	6	1	9	0	0	0	0	0	0	8.90740117112652	
i 1	162.01244217687074	0.7575000000000001	73	697	2	20	4	2	0	-2	2	0	0	9.186790662119648	
i 1	162.01485034013606	10.1	66	1083	4	26	8	6	0	2	6	0	0	0.29907009316095334	
i 1	162.01645578231293	1.7675	74	199	4	5	12	17	0	2	17	0	0	11.502682012294928	
i 1	162.0180612244898	0.505	72	199	6	3	5	2	0	-2	2	0	0	4.0	
i 1	162.01966666666667	0.7575000000000001	73	697	1	20	9	8	0	-1	8	0	0	9.186790662119648	
i 1	162.49397959183673	0.2525	72	1083	4	9	9	2	0	-2	2	0	0	3.0	
i 1	162.7343469387755	0.7575000000000001	70	697	1	24	7	2	0	-2	2	0	0	13.186790662119648	
i 1	162.73514965986394	0.7575000000000001	70	1083	3	20	5	2	0	-2	2	0	0	9.186790662119648	
i 1	162.7367551020408	0.2525	69	697	4	1	9	1	0	0	1	0	0	8.90740117112652	
i 1	162.75280952380953	0.2525	72	697	4	4	12	2	0	1	2	0	0	4.0	
i 1	162.76725850340137	1.5150000000000001	72	199	6	3	12	2	0	-2	2	0	0	4.0	
i 1	162.98113605442177	0.2525	74	199	4	5	7	17	0	1	17	0	0	11.502682012294928	
i 1	162.98755782312926	0.505	69	1083	5	1	5	0	0	0	0	0	0	8.90740117112652	
i 1	163.0156530612245	0.505	72	697	4	3	15	2	0	-2	2	0	0	4.0	
i 1	163.2520068027211	2.525	74	697	4	5	6	17	0	2	17	0	0	11.502682012294928	
i 1	163.25280952380953	0.505	72	697	6	1	3	1	0	0	1	0	0	8.90740117112652	
i 1	163.2616394557823	0.2525	75	199	5	4	5	2	0	1	2	0	0	4.0	
i 1	163.48113605442177	1.01	72	697	4	4	8	2	0	1	2	0	0	4.0	
i 1	163.49879591836734	0.2525	72	199	5	24	16	1	0	-1	1	0	0	9.90740117112652	
i 1	163.51244217687074	0.2525	73	697	2	20	1	2	0	-2	2	0	0	9.186790662119648	
i 1	163.51645578231293	0.7575000000000001	73	697	1	20	5	8	0	-1	8	0	0	9.186790662119648	
i 1	163.51966666666667	0.2525	74	697	5	5	6	17	0	1	17	0	0	11.502682012294928	
i 1	163.7479931972789	0.2525	72	1083	5	1	4	1	0	-1	1	0	0	8.90740117112652	
i 1	163.75602040816327	0.2525	74	1083	3	5	15	16	0	1	16	0	0	11.502682012294928	
i 1	163.7616394557823	0.2525	75	697	6	2	9	8	0	-2	8	0	0	4.0	
i 1	163.76404761904763	0.2525	73	199	4	24	12	2	0	-1	2	0	0	13.186790662119648	
i 1	163.76485034013606	0.2525	74	199	4	5	5	17	0	1	17	0	0	11.502682012294928	
i 1	163.98916326530613	1.5150000000000001	73	1083	3	20	1	8	0	-1	8	0	0	9.186790662119648	
i 1	164.00521768707483	1.01	70	1083	2	20	1	8	0	-2	8	0	0	9.186790662119648	
i 1	164.01003401360543	0.2525	75	1083	4	9	5	8	0	-2	8	0	0	3.0	
i 1	164.0132448979592	1.5150000000000001	69	697	6	1	16	1	0	-1	1	0	0	8.90740117112652	
i 1	164.240768707483	0.2525	73	1083	3	24	1	8	0	-2	8	0	0	13.186790662119648	
i 1	164.24478231292517	0.2525	72	1083	5	1	9	1	0	-1	1	0	0	8.90740117112652	
i 1	164.25280952380953	2.2725	75	697	6	2	6	2	0	-2	2	0	0	4.0	
i 1	164.26244217687074	0.2525	74	199	4	5	5	17	0	1	17	0	0	11.502682012294928	
i 1	164.26404761904763	0.505	74	1083	3	5	1	16	0	1	16	0	0	11.502682012294928	
i 1	164.50120408163266	0.505	74	697	5	5	15	16	0	1	16	0	0	11.502682012294928	
i 1	164.5044149659864	0.505	69	697	4	1	2	1	0	0	1	0	0	8.90740117112652	
i 1	164.5132448979592	0.2525	75	697	6	2	16	8	0	-2	8	0	0	4.0	
i 1	164.73274149659863	0.2525	69	1083	5	1	14	0	0	0	0	0	0	8.90740117112652	
i 1	164.73514965986394	0.2525	75	1083	4	9	5	8	0	-2	8	0	0	3.0	
i 1	164.7632448979592	0.2525	72	697	4	3	11	2	0	-2	2	0	0	4.0	
i 1	164.9843469387755	7.07	61	697	3	14	12	9	0	1	9	0	0	2.605531084707703	
i 1	164.98595238095237	0.2525	74	199	4	5	1	17	0	2	17	0	0	11.502682012294928	
i 1	164.98755782312926	0.2525	72	697	4	24	16	1	0	-1	1	0	0	9.90740117112652	
i 1	164.990768707483	15.15	66	697	3	27	8	9	0	1	9	0	0	12.64563780125233	
i 1	164.9979931972789	7.07	61	697	5	25	9	9	0	2	9	0	0	0.29907009316095334	
i 1	165.00120408163266	7.07	61	199	6	7	7	9	0	1	9	0	0	1.3027655423538518	
i 1	165.00280952380953	7.07	66	1083	4	16	3	6	0	2	6	0	0	0.8475879430508959	
i 1	165.00280952380953	0.505	72	697	4	4	1	2	0	1	2	0	0	4.0	
i 1	165.01244217687074	0.2525	72	199	5	24	5	1	0	-1	1	0	0	9.90740117112652	
i 1	165.01485034013606	0.505	70	1083	3	20	14	8	0	-2	8	0	0	9.186790662119648	
i 1	165.01725850340137	0.505	74	199	4	5	3	17	0	1	17	0	0	11.502682012294928	
i 1	165.240768707483	0.505	74	697	4	5	4	17	0	2	17	0	0	11.502682012294928	
i 1	165.2455850340136	1.2625	69	199	6	1	4	0	0	0	0	0	0	8.90740117112652	
i 1	165.48274149659863	2.02	70	697	1	24	15	2	0	-2	2	0	0	13.186790662119648	
i 1	165.50602040816327	2.2725	73	1083	3	20	2	8	0	-2	8	0	0	9.186790662119648	
i 1	165.5068231292517	0.505	72	697	3	3	15	2	0	-2	2	0	0	4.0	
i 1	165.51966666666667	1.2625	74	199	4	5	15	17	0	2	17	0	0	11.502682012294928	
i 1	165.73595238095237	0.505	74	1083	3	5	16	16	0	1	16	0	0	11.502682012294928	
i 1	165.73916326530613	0.2525	70	697	2	20	1	8	0	-1	8	0	0	9.186790662119648	
i 1	165.98113605442177	2.2725	72	199	5	24	1	1	0	-1	1	0	0	9.90740117112652	
i 1	165.99638775510203	0.2525	70	697	2	24	11	8	0	-1	8	0	0	13.186790662119648	
i 1	166.0020068027211	0.2525	75	697	6	2	8	8	0	-2	8	0	0	4.0	
i 1	166.01003401360543	0.2525	69	697	4	1	5	1	0	0	1	0	0	8.90740117112652	
i 1	166.23113605442177	0.505	70	697	2	20	7	8	0	-1	8	0	0	9.186790662119648	
i 1	166.240768707483	0.7575000000000001	72	697	4	4	14	2	0	1	2	0	0	4.0	
i 1	166.25602040816327	0.505	73	697	1	20	8	8	0	-1	8	0	0	9.186790662119648	
i 1	166.25762585034013	0.2525	74	697	5	5	8	17	0	1	17	0	0	11.502682012294928	
i 1	166.26003401360543	0.2525	74	199	4	5	4	17	0	1	17	0	0	11.502682012294928	
i 1	166.48033333333333	0.2525	69	1083	5	1	16	0	0	0	0	0	0	8.90740117112652	
i 1	166.48755782312926	1.7675	75	199	5	4	4	2	0	1	2	0	0	4.0	
i 1	166.490768707483	0.2525	69	697	6	1	14	1	0	-1	1	0	0	8.90740117112652	
i 1	166.49397959183673	0.2525	75	697	6	2	15	8	0	-2	8	0	0	4.0	
i 1	166.5116394557823	0.2525	74	1083	3	5	11	16	0	1	16	0	0	11.502682012294928	
i 1	166.51485034013606	1.01	74	697	4	5	13	17	0	2	17	0	0	11.502682012294928	
i 1	166.73354421768707	0.505	74	199	4	5	13	17	0	1	17	0	0	11.502682012294928	
i 1	166.7343469387755	0.505	72	697	6	1	9	1	0	0	1	0	0	8.90740117112652	
i 1	166.7431768707483	0.2525	72	199	6	3	12	2	0	-2	2	0	0	4.0	
i 1	166.9883605442177	0.2525	69	697	4	1	11	1	0	0	1	0	0	8.90740117112652	
i 1	166.99879591836734	1.01	70	697	2	20	1	8	0	-1	8	0	0	9.186790662119648	
i 1	167.0020068027211	1.01	73	697	1	20	2	8	0	-1	8	0	0	9.186790662119648	
i 1	167.01404761904763	1.01	72	697	3	3	9	2	0	-2	2	0	0	4.0	
i 1	167.2383605442177	0.2525	72	1083	5	1	9	1	0	-1	1	0	0	8.90740117112652	
i 1	167.25280952380953	2.525	69	199	6	1	13	0	0	0	0	0	0	8.90740117112652	
i 1	167.26886394557823	1.7675	74	199	4	5	9	17	0	2	17	0	0	11.502682012294928	
i 1	167.48916326530613	0.2525	75	1083	4	9	10	8	0	-2	8	0	0	3.0	
i 1	167.49719047619047	0.505	74	1083	3	5	1	17	0	2	17	0	0	11.502682012294928	
i 1	167.51244217687074	0.2525	69	1083	5	1	11	0	0	0	0	0	0	8.90740117112652	
i 1	167.7319387755102	4.2925	72	199	6	3	6	2	0	-2	2	0	0	4.0	
i 1	167.76003401360543	0.2525	73	1083	3	20	8	8	0	-1	8	0	0	9.186790662119648	
i 1	167.98354421768707	0.2525	74	199	4	5	12	17	0	1	17	0	0	11.502682012294928	
i 1	167.9883605442177	0.505	72	697	4	24	2	1	0	-1	1	0	0	9.90740117112652	
i 1	167.98996598639457	4.04	66	697	3	14	5	9	0	1	9	0	0	2.605531084707703	
i 1	167.9955850340136	12.120000000000001	61	697	3	27	14	6	0	2	6	0	0	12.64563780125233	
i 1	167.99638775510203	0.7575000000000001	70	697	2	20	1	8	0	-1	8	0	0	7.892101242005808	
i 1	167.9979931972789	0.2525	73	1083	3	24	10	8	0	-2	8	0	0	11.892101242005808	
i 1	168.00602040816327	12.120000000000001	66	697	4	12	14	9	0	2	9	0	0	0.8475879430508959	
i 1	168.01244217687074	1.5150000000000001	73	697	1	20	6	8	0	-1	8	0	0	7.892101242005808	
i 1	168.01886394557823	0.2525	75	697	6	2	10	2	0	-2	2	0	0	4.0	
i 1	168.01886394557823	0.505	74	697	2	5	7	16	0	1	16	0	0	11.502682012294928	
i 1	168.01966666666667	4.04	61	697	5	25	16	6	0	2	6	0	0	0.29907009316095334	
i 1	168.23354421768707	0.505	70	697	2	24	10	8	0	-1	8	0	0	11.892101242005808	
i 1	168.240768707483	0.505	74	1083	3	5	4	16	0	1	16	0	0	11.502682012294928	
i 1	168.2656530612245	0.505	72	1083	4	9	14	2	0	-2	2	0	0	3.0	
i 1	168.4819387755102	0.2525	72	1083	5	1	9	1	0	-1	1	0	0	8.90740117112652	
i 1	168.48514965986394	0.2525	72	199	5	24	10	1	0	-1	1	0	0	9.90740117112652	
i 1	168.5180612244898	0.2525	74	697	3	5	6	17	0	1	17	0	0	11.502682012294928	
i 1	168.73113605442177	0.505	69	697	4	1	7	1	0	0	1	0	0	8.90740117112652	
i 1	168.74638775510203	0.2525	73	697	4	20	9	8	0	-2	8	0	0	7.892101242005808	
i 1	168.74719047619047	1.5150000000000001	70	1083	3	20	7	8	0	-2	8	0	0	7.892101242005808	
i 1	168.74959863945577	0.2525	73	199	4	20	16	2	0	-2	2	0	0	7.892101242005808	
i 1	168.75602040816327	0.7575000000000001	69	697	6	1	1	1	0	-1	1	0	0	8.90740117112652	
i 1	168.7568231292517	0.2525	74	697	6	5	4	17	0	2	17	0	0	11.502682012294928	
i 1	168.75842857142857	0.7575000000000001	74	199	4	5	7	17	0	1	17	0	0	11.502682012294928	
i 1	168.76003401360543	0.2525	70	199	4	24	12	8	0	-1	8	0	0	11.892101242005808	
i 1	168.76244217687074	0.2525	72	697	3	3	14	2	0	-2	2	0	0	4.0	
i 1	168.76886394557823	0.2525	75	697	6	2	12	2	0	-2	2	0	0	4.0	
i 1	168.99638775510203	1.01	70	1083	3	20	13	2	0	-1	2	0	0	7.892101242005808	
i 1	168.99879591836734	0.2525	73	697	2	24	13	8	0	-1	8	0	0	11.892101242005808	
i 1	169.0068231292517	0.2525	72	1083	4	9	11	2	0	-2	2	0	0	3.0	
i 1	169.00842857142857	0.2525	75	697	6	2	15	8	0	-2	8	0	0	4.0	
i 1	169.01083673469387	0.2525	74	697	4	5	1	17	0	2	17	0	0	11.502682012294928	
i 1	169.0156530612245	0.505	74	697	3	5	4	17	0	1	17	0	0	11.502682012294928	
i 1	169.2383605442177	2.2725	72	199	5	24	4	1	0	-1	1	0	0	9.90740117112652	
i 1	169.24397959183673	1.2625	75	697	6	2	11	2	0	-2	2	0	0	4.0	
i 1	169.2568231292517	1.7675	74	199	4	5	15	17	0	2	17	0	0	11.502682012294928	
i 1	169.48514965986394	0.505	70	697	2	20	16	8	0	-2	8	0	0	7.892101242005808	
i 1	169.4883605442177	0.2525	74	1083	3	5	13	17	0	2	17	0	0	11.502682012294928	
i 1	169.4979931972789	0.7575000000000001	72	1083	5	1	7	1	0	-1	1	0	0	8.90740117112652	
i 1	169.50602040816327	0.2525	74	697	2	5	16	16	0	1	16	0	0	11.502682012294928	
i 1	169.51003401360543	0.2525	69	697	4	1	3	1	0	0	1	0	0	8.90740117112652	
i 1	169.51886394557823	0.2525	72	697	3	3	10	2	0	-2	2	0	0	4.0	
i 1	169.74157142857143	0.2525	69	1083	5	1	13	0	0	0	0	0	0	8.90740117112652	
i 1	169.74157142857143	0.7575000000000001	70	697	2	24	14	2	0	-2	2	0	0	11.892101242005808	
i 1	169.75040136054423	0.7575000000000001	74	697	4	5	11	17	0	2	17	0	0	11.502682012294928	
i 1	169.7616394557823	0.2525	74	697	3	5	6	17	0	1	17	0	0	11.502682012294928	
i 1	169.76485034013606	0.2525	75	199	5	4	6	2	0	1	2	0	0	4.0	
i 1	169.7656530612245	0.2525	72	697	3	4	5	2	0	1	2	0	0	4.0	
i 1	169.98274149659863	0.2525	73	199	4	20	6	8	0	-1	8	0	0	7.892101242005808	
i 1	169.9979931972789	0.2525	74	1083	3	5	7	17	0	2	17	0	0	11.502682012294928	
i 1	169.99959863945577	1.01	73	697	1	20	16	8	0	-1	8	0	0	7.892101242005808	
i 1	170.00280952380953	0.2525	70	697	4	20	8	2	0	-2	2	0	0	7.892101242005808	
i 1	170.01966666666667	0.2525	74	199	4	5	5	17	0	1	17	0	0	11.502682012294928	
i 1	170.2343469387755	0.2525	72	697	6	1	9	1	0	0	1	0	0	8.90740117112652	
i 1	170.23755782312926	0.2525	73	697	2	20	11	8	0	-1	8	0	0	7.892101242005808	
i 1	170.24638775510203	0.2525	73	697	2	24	7	8	0	-1	8	0	0	11.892101242005808	
i 1	170.25040136054423	1.7675	74	697	6	5	14	17	0	2	17	0	0	11.502682012294928	
i 1	170.25120408163266	0.2525	69	697	4	1	5	1	0	0	1	0	0	8.90740117112652	
i 1	170.4819387755102	1.5150000000000001	69	199	6	1	8	0	0	0	0	0	0	8.90740117112652	
i 1	170.48274149659863	0.505	72	1083	4	9	4	2	0	-2	2	0	0	3.0	
i 1	170.49157142857143	0.2525	74	697	2	5	16	16	0	1	16	0	0	11.502682012294928	
i 1	170.51244217687074	1.5150000000000001	70	1083	3	20	9	8	0	-2	8	0	0	7.892101242005808	
i 1	170.51404761904763	0.2525	75	697	6	2	4	8	0	-2	8	0	0	4.0	
i 1	170.51886394557823	0.505	69	1083	5	1	12	0	0	0	0	0	0	8.90740117112652	
i 1	170.73996598639457	0.505	75	697	6	2	12	2	0	-2	2	0	0	4.0	
i 1	170.73996598639457	0.505	74	199	4	5	12	17	0	1	17	0	0	11.502682012294928	
i 1	170.75280952380953	0.2525	72	697	6	1	13	1	0	0	1	0	0	8.90740117112652	
i 1	170.75521768707483	1.2625	70	1083	3	20	5	2	0	-1	2	0	0	7.892101242005808	
i 1	170.98274149659863	0.505	74	1083	3	5	11	16	0	1	16	0	0	11.502682012294928	
i 1	170.98595238095237	1.01	61	199	6	25	16	9	0	2	9	0	0	0.29907009316095334	
i 1	170.98755782312926	0.2525	72	697	3	4	2	2	0	1	2	0	0	4.0	
i 1	170.9955850340136	0.2525	69	697	6	1	16	1	0	-1	1	0	0	8.90740117112652	
i 1	170.99638775510203	9.09	66	697	4	12	14	6	0	2	6	0	0	0.8475879430508959	
i 1	170.99719047619047	1.01	75	199	5	4	10	2	0	1	2	0	0	4.0	
i 1	171.23514965986394	0.2525	74	199	4	5	10	17	0	2	17	0	0	11.502682012294928	
i 1	171.25280952380953	0.2525	70	697	2	20	3	8	0	-1	8	0	0	7.892101242005808	
i 1	171.26645578231293	0.505	72	1083	5	1	2	1	0	-1	1	0	0	8.90740117112652	
i 1	171.26966666666667	0.2525	75	697	6	2	14	8	0	-2	8	0	0	4.0	
i 1	171.48274149659863	0.505	73	1083	3	20	6	2	0	-1	2	0	0	7.892101242005808	
i 1	171.4867551020408	0.505	69	1083	5	1	8	0	0	0	0	0	0	8.90740117112652	
i 1	171.49397959183673	0.2525	74	199	4	5	4	17	0	1	17	0	0	11.502682012294928	
i 1	171.50361224489797	0.2525	72	697	6	1	8	1	0	0	1	0	0	8.90740117112652	
i 1	171.51404761904763	0.2525	74	697	2	5	5	16	0	1	16	0	0	11.502682012294928	
i 1	171.7319387755102	0.2525	69	697	6	1	7	1	0	-1	1	0	0	8.90740117112652	
i 1	171.98033333333333	1.7675	73	697	2	20	16	8	0	-1	8	0	0	7.892101242005808	
i 1	171.98113605442177	0.2525	69	199	6	1	7	1	0	-1	1	0	0	8.90740117112652	
i 1	171.98274149659863	0.505	73	199	4	20	13	8	0	-2	8	0	0	7.892101242005808	
i 1	171.98354421768707	1.5150000000000001	77	697	4	5	14	16	5001	2	16	0	0	11.502682012294928	
i 1	171.9843469387755	0.2525	72	697	4	24	2	1	0	-1	1	0	0	9.90740117112652	
i 1	171.9843469387755	0.2525	70	199	4	20	9	8	0	-2	8	0	0	7.892101242005808	
i 1	171.98595238095237	8.08	61	199	5	26	9	6	0	1	6	0	0	0.29907009316095334	
i 1	171.99237414965987	0.2525	69	697	4	1	7	1	0	0	1	0	0	8.90740117112652	
i 1	171.99237414965987	8.08	61	1083	3	14	3	9	0	1	9	0	0	2.605531084707703	
i 1	171.99397959183673	0.2525	70	697	2	20	9	8	5001	-1	8	0	0	7.892101242005808	
i 1	171.99478231292517	5.05	61	199	5	16	13	6	0	1	6	0	0	0.8475879430508959	
i 1	171.9955850340136	5.05	61	1083	5	25	15	9	0	1	9	0	0	0.29907009316095334	
i 1	171.99719047619047	2.525	75	1083	6	2	16	2	0	1	2	0	0	4.0	
i 1	171.99719047619047	2.02	66	697	5	25	1	6	5001	2	6	0	0	0.29907009316095334	
i 1	172.00040136054423	5.05	66	199	5	26	7	9	0	1	9	0	0	0.29907009316095334	
i 1	172.00361224489797	8.08	66	697	5	25	9	9	5001	2	9	0	0	0.29907009316095334	
i 1	172.00602040816327	8.08	66	1083	5	25	5	9	0	2	9	0	0	0.29907009316095334	
i 1	172.00842857142857	0.2525	70	199	4	20	1	8	0	-1	8	0	0	7.892101242005808	
i 1	172.01404761904763	2.02	61	697	6	7	11	6	5001	2	6	0	0	1.3027655423538518	
i 1	172.0156530612245	1.5150000000000001	72	697	6	1	14	1	5001	-1	1	0	0	8.90740117112652	
i 1	172.0156530612245	8.08	66	1083	3	14	10	9	0	2	9	0	0	2.605531084707703	
i 1	172.01966666666667	2.02	61	199	5	16	12	9	0	2	9	0	0	0.8475879430508959	
i 1	172.24719047619047	1.2625	70	697	2	24	9	2	0	-2	2	0	0	11.892101242005808	
i 1	172.25280952380953	2.7775	69	697	4	24	6	0	5001	-1	0	0	0	9.90740117112652	
i 1	172.25361224489797	0.2525	70	697	4	20	10	8	5001	-1	8	0	0	7.892101242005808	
i 1	172.26645578231293	0.7575000000000001	77	199	4	5	2	16	0	1	16	0	0	11.502682012294928	
i 1	172.26886394557823	0.2525	70	1083	4	20	14	2	0	-2	2	0	0	7.892101242005808	
i 1	172.49157142857143	0.7575000000000001	77	1083	6	5	15	16	0	1	16	0	0	11.502682012294928	
i 1	172.4931768707483	0.2525	74	697	3	5	16	17	0	1	17	0	0	11.502682012294928	
i 1	172.49397959183673	0.2525	72	697	4	24	1	1	0	-1	1	0	0	9.90740117112652	
i 1	172.50120408163266	1.01	70	697	2	20	12	8	5001	-1	8	0	0	7.892101242005808	
i 1	172.51083673469387	0.2525	70	199	4	20	1	8	0	-2	8	0	0	7.892101242005808	
i 1	172.5180612244898	0.505	69	199	6	1	11	1	0	-1	1	0	0	8.90740117112652	
i 1	172.7343469387755	4.04	74	1083	6	5	7	16	0	1	16	0	0	11.502682012294928	
i 1	172.7568231292517	1.01	73	697	2	24	10	8	5001	-2	8	0	0	11.892101242005808	
i 1	173.00040136054423	0.2525	69	199	6	1	1	1	0	-1	1	0	0	8.90740117112652	
i 1	173.0020068027211	0.2525	69	1083	6	1	3	1	0	-1	1	0	0	8.90740117112652	
i 1	173.0020068027211	1.2625	74	199	4	5	14	17	0	2	17	0	0	11.502682012294928	
i 1	173.0132448979592	0.7575000000000001	72	697	4	4	14	8	5001	-2	8	0	0	4.0	
i 1	173.2367551020408	1.7675	73	199	4	24	2	8	0	-1	8	0	0	11.892101242005808	
i 1	173.24719047619047	0.7575000000000001	69	199	6	1	9	1	0	-1	1	0	0	8.90740117112652	
i 1	173.2479931972789	1.7675	70	199	4	20	4	8	0	-2	8	0	0	7.892101242005808	
i 1	173.2656530612245	0.7575000000000001	72	1083	6	1	3	1	0	-1	1	0	0	8.90740117112652	
i 1	173.26886394557823	0.2525	74	697	2	5	3	16	0	1	16	0	0	11.502682012294928	
i 1	173.4931768707483	0.2525	77	697	4	5	6	16	5001	2	16	0	0	11.502682012294928	
i 1	173.49879591836734	0.7575000000000001	72	199	6	9	10	8	0	1	8	0	0	3.0	
i 1	173.73595238095237	0.2525	74	697	2	5	3	16	0	1	16	0	0	11.502682012294928	
i 1	173.7383605442177	0.2525	70	697	2	20	12	8	5001	-1	8	0	0	7.892101242005808	
i 1	173.74478231292517	1.7675	77	697	4	5	9	16	5001	2	16	0	0	11.502682012294928	
i 1	173.75120408163266	0.2525	70	697	2	24	2	2	0	-2	2	0	0	11.892101242005808	
i 1	173.75280952380953	0.2525	72	697	3	3	13	2	0	-2	2	0	0	4.0	
i 1	173.7544149659864	2.2725	73	697	1	24	12	8	5001	252	8	307	0	11.892101242005808	
i 1	173.75521768707483	5.3025	72	697	6	1	6	1	5001	-1	1	0	0	8.90740117112652	
i 1	173.98514965986394	0.2525	72	697	4	24	13	1	0	-1	1	0	0	9.90740117112652	
i 1	173.99719047619047	1.5150000000000001	73	199	4	20	8	2	0	-1	2	0	0	7.892101242005808	
i 1	173.9979931972789	6.0600000000000005	66	697	5	25	16	6	5001	2	6	0	0	0.29907009316095334	
i 1	174.00120408163266	0.7575000000000001	75	199	6	9	4	2	0	1	2	0	0	3.0	
i 1	174.00521768707483	6.0600000000000005	61	697	4	7	11	6	5001	2	6	0	0	1.3027655423538518	
i 1	174.0068231292517	5.8075	73	199	4	20	12	8	0	-2	8	0	0	7.892101242005808	
i 1	174.01645578231293	2.2725	72	697	4	4	16	8	5001	-2	8	0	0	4.0	
i 1	174.23916326530613	0.2525	77	199	4	5	6	16	0	1	16	0	0	11.502682012294928	
i 1	174.240768707483	0.505	69	199	6	1	4	1	0	-1	1	0	0	8.90740117112652	
i 1	174.24638775510203	0.505	75	697	5	3	6	2	5001	1	2	0	0	4.0	
i 1	174.2520068027211	0.2525	69	697	4	1	7	1	0	0	1	0	0	8.90740117112652	
i 1	174.48595238095237	0.2525	74	697	2	5	11	16	0	1	16	0	0	11.502682012294928	
i 1	174.49959863945577	1.2625	69	1083	6	1	16	1	0	-1	1	0	0	8.90740117112652	
i 1	174.7319387755102	0.2525	72	1083	6	1	14	1	0	-1	1	0	0	8.90740117112652	
i 1	174.7367551020408	0.505	72	199	6	9	7	8	0	1	8	0	0	3.0	
i 1	174.740768707483	0.2525	75	1083	6	2	15	2	0	1	2	0	0	4.0	
i 1	174.75602040816327	0.2525	77	199	4	5	16	16	0	1	16	0	0	11.502682012294928	
i 1	174.99237414965987	0.2525	75	199	6	9	3	2	0	1	2	0	0	3.0	
i 1	174.99638775510203	1.5150000000000001	70	697	2	24	9	2	0	-2	2	0	0	11.892101242005808	
i 1	175.00040136054423	0.2525	69	199	6	1	9	1	0	-1	1	0	0	8.90740117112652	
i 1	175.00361224489797	0.7575000000000001	77	697	6	5	6	16	5001	2	16	0	0	11.502682012294928	
i 1	175.0068231292517	0.505	75	1083	6	2	12	2	0	1	2	0	0	4.0	
i 1	175.01485034013606	0.2525	70	697	2	20	4	8	5001	-1	8	0	0	7.892101242005808	
i 1	175.2367551020408	0.505	72	1083	6	1	5	1	0	-1	1	0	0	8.90740117112652	
i 1	175.240768707483	1.7675	75	697	5	3	12	2	5001	1	2	0	0	4.0	
i 1	175.24959863945577	0.2525	77	1083	6	5	6	16	0	1	16	0	0	11.502682012294928	
i 1	175.48274149659863	0.2525	73	1083	4	20	16	2	0	-2	2	0	0	7.892101242005808	
i 1	175.4843469387755	0.2525	72	697	5	3	12	2	0	-2	2	0	0	4.0	
i 1	175.48755782312926	0.2525	74	697	3	5	5	17	0	1	17	0	0	11.502682012294928	
i 1	175.49478231292517	0.2525	70	697	4	20	14	8	5001	-1	8	0	0	7.892101242005808	
i 1	175.49638775510203	0.505	74	697	2	5	13	16	0	1	16	0	0	11.502682012294928	
i 1	175.50040136054423	0.2525	72	697	3	4	12	2	0	1	2	0	0	4.0	
i 1	175.51645578231293	2.525	69	697	4	24	10	0	5001	-1	0	0	0	9.90740117112652	
i 1	175.7367551020408	1.2625	77	697	4	5	5	16	5001	2	16	0	0	11.502682012294928	
i 1	175.73916326530613	0.2525	73	199	4	20	6	8	0	-2	8	0	0	7.892101242005808	
i 1	175.73996598639457	0.7575000000000001	69	199	6	1	6	1	0	-1	1	0	0	8.90740117112652	
i 1	175.74157142857143	0.2525	69	199	6	1	14	1	0	-1	1	0	0	8.90740117112652	
i 1	175.74478231292517	1.2625	70	199	4	20	14	2	0	-1	2	0	0	7.892101242005808	
i 1	175.7455850340136	2.7775	75	1083	6	2	10	2	0	1	2	0	0	4.0	
i 1	175.9883605442177	0.2525	73	697	2	24	3	8	5001	-2	8	0	0	11.892101242005808	
i 1	175.99157142857143	3.0300000000000002	77	1083	6	5	1	16	0	1	16	0	0	11.502682012294928	
i 1	176.0020068027211	0.2525	72	697	4	24	16	1	0	-1	1	0	0	9.90740117112652	
i 1	176.00602040816327	0.2525	75	199	6	9	13	2	0	1	2	0	0	3.0	
i 1	176.2479931972789	1.01	75	1083	6	2	3	2	0	1	2	0	0	4.0	
i 1	176.25040136054423	1.5150000000000001	73	199	4	24	1	8	0	-1	8	0	0	11.892101242005808	
i 1	176.2544149659864	0.2525	72	199	6	9	12	8	0	1	8	0	0	3.0	
i 1	176.51645578231293	0.505	73	697	2	24	5	8	5001	-2	8	0	0	11.892101242005808	
i 1	176.7656530612245	0.2525	75	199	6	9	16	2	0	1	2	0	0	3.0	
i 1	176.98354421768707	0.505	77	697	6	5	3	16	5001	2	16	0	0	11.502682012294928	
i 1	176.9843469387755	0.505	72	199	6	9	14	8	0	1	8	0	0	3.0	
i 1	176.98916326530613	0.2525	73	1083	4	20	9	8	0	-1	8	0	0	7.892101242005808	
i 1	176.990768707483	3.0300000000000002	66	199	5	26	8	9	0	1	9	0	0	0.29907009316095334	
i 1	176.99237414965987	0.505	72	697	4	24	11	1	0	-1	1	0	0	9.90740117112652	
i 1	176.99879591836734	0.505	72	697	4	4	3	8	5001	-2	8	0	0	4.0	
i 1	177.00040136054423	4.04	70	697	2	24	11	2	0	-2	2	0	0	11.892101242005808	
i 1	177.00120408163266	0.2525	73	697	4	24	14	8	5001	-2	8	0	0	11.892101242005808	
i 1	177.0068231292517	0.2525	72	1083	6	1	11	1	0	-1	1	0	0	8.90740117112652	
i 1	177.0116394557823	0.2525	70	697	4	20	13	8	5001	-1	8	0	0	7.892101242005808	
i 1	177.24478231292517	0.2525	77	697	6	5	3	16	5001	2	16	0	0	11.502682012294928	
i 1	177.25842857142857	0.505	73	697	2	24	4	8	5001	-2	8	0	0	11.892101242005808	
i 1	177.26083673469387	0.2525	72	697	4	4	13	2	0	1	2	0	0	4.0	
i 1	177.26083673469387	1.7675	70	697	2	20	9	8	5001	-1	8	0	0	7.892101242005808	
i 1	177.2632448979592	0.505	74	199	4	5	12	17	0	2	17	0	0	11.502682012294928	
i 1	177.26966666666667	2.02	73	199	4	20	6	8	0	-1	8	0	0	7.892101242005808	
i 1	177.48033333333333	0.2525	75	1083	6	2	5	2	0	1	2	0	0	4.0	
i 1	177.48033333333333	0.505	77	199	4	5	16	16	0	1	16	0	0	11.502682012294928	
i 1	177.48595238095237	0.2525	69	199	6	1	1	1	0	-1	1	0	0	8.90740117112652	
i 1	177.490768707483	0.2525	75	199	6	9	7	2	0	1	2	0	0	3.0	
i 1	177.50762585034013	4.7975	75	697	5	3	7	2	5001	1	2	0	0	4.0	
i 1	177.50762585034013	1.01	74	697	2	5	4	16	0	1	16	0	0	11.502682012294928	
i 1	177.7367551020408	2.2725	69	1083	6	1	7	1	0	-1	1	0	0	8.90740117112652	
i 1	177.7431768707483	0.505	72	199	6	9	15	8	0	1	8	0	0	3.0	
i 1	177.74397959183673	0.2525	72	697	4	4	1	8	5001	-2	8	0	0	4.0	
i 1	177.75040136054423	0.2525	77	697	6	5	11	16	5001	2	16	0	0	11.502682012294928	
i 1	177.76966666666667	0.2525	69	199	6	1	4	1	0	-1	1	0	0	8.90740117112652	
i 1	177.9843469387755	0.2525	74	697	3	5	13	17	0	1	17	0	0	11.502682012294928	
i 1	177.98514965986394	0.2525	72	697	4	24	13	1	0	-1	1	0	0	9.90740117112652	
i 1	177.98595238095237	2.02	77	697	6	5	5	16	5001	2	16	0	0	11.502682012294928	
i 1	177.99237414965987	0.505	72	1083	6	1	14	1	0	-1	1	0	0	8.90740117112652	
i 1	177.99879591836734	1.01	72	697	5	3	14	2	0	-2	2	0	0	4.0	
i 1	178.25040136054423	0.505	74	1083	6	5	1	16	0	1	16	0	0	11.502682012294928	
i 1	178.2544149659864	1.2625	69	697	4	1	15	1	0	0	1	0	0	8.90740117112652	
i 1	178.26083673469387	0.505	72	697	4	4	8	2	0	1	2	0	0	4.0	
i 1	178.4867551020408	0.505	75	1083	6	2	16	2	0	1	2	0	0	4.0	
i 1	178.50361224489797	0.2525	72	697	4	24	13	1	0	-1	1	0	0	9.90740117112652	
i 1	178.51886394557823	0.2525	77	697	6	5	1	16	5001	2	16	0	0	11.502682012294928	
i 1	178.73354421768707	0.2525	72	1083	6	1	11	1	0	-1	1	0	0	8.90740117112652	
i 1	178.73595238095237	0.2525	74	697	2	5	15	16	0	1	16	0	0	11.502682012294928	
i 1	178.73755782312926	0.505	77	199	4	5	14	16	0	1	16	0	0	11.502682012294928	
i 1	178.74638775510203	2.02	72	697	4	4	16	8	5001	-2	8	0	0	4.0	
i 1	178.98996598639457	0.2525	73	697	2	24	6	8	5001	-2	8	0	0	11.892101242005808	
i 1	178.99237414965987	0.2525	69	199	6	1	8	1	0	-1	1	0	0	8.90740117112652	
i 1	178.99397959183673	1.7675	73	697	2	20	8	8	0	-1	8	0	0	7.892101242005808	
i 1	179.00040136054423	0.505	69	697	4	24	9	0	5001	-1	0	0	0	9.90740117112652	
i 1	179.00120408163266	0.2525	75	1083	6	2	3	2	0	1	2	0	0	4.0	
i 1	179.0020068027211	1.01	77	697	6	5	14	16	5001	2	16	0	0	11.502682012294928	
i 1	179.00762585034013	0.505	72	697	4	4	9	2	0	1	2	0	0	4.0	
i 1	179.23113605442177	0.7575000000000001	72	697	6	1	3	1	5001	-1	1	0	0	8.90740117112652	
i 1	179.23113605442177	0.2525	73	1083	4	20	13	8	0	-1	8	0	0	7.892101242005808	
i 1	179.24157142857143	0.2525	73	697	4	24	8	8	5001	-2	8	0	0	11.892101242005808	
i 1	179.26645578231293	0.2525	75	1083	6	2	15	2	0	1	2	0	0	4.0	
i 1	179.48354421768707	0.2525	70	199	4	20	2	8	0	-1	8	0	0	7.892101242005808	
i 1	179.490768707483	0.505	72	1083	6	1	10	1	0	-1	1	0	0	8.90740117112652	
i 1	179.490768707483	0.2525	73	697	2	24	8	8	5001	-2	8	0	0	11.892101242005808	
i 1	179.50602040816327	0.505	74	697	2	5	2	16	0	1	16	0	0	11.502682012294928	
i 1	179.5068231292517	0.2525	72	697	4	24	16	1	0	-1	1	0	0	9.90740117112652	
i 1	179.5068231292517	0.2525	70	697	2	20	3	8	5001	-1	8	0	0	7.892101242005808	
i 1	179.7343469387755	0.7575000000000001	70	697	4	20	7	8	5001	-1	8	0	0	7.892101242005808	
i 1	179.740768707483	0.7575000000000001	73	1083	4	20	5	2	0	-1	2	0	0	7.892101242005808	
i 1	179.74638775510203	0.505	73	697	4	24	6	8	5001	-2	8	0	0	11.892101242005808	
i 1	179.76003401360543	0.2525	69	697	4	24	11	0	5001	-1	0	0	0	9.90740117112652	
i 1	179.98514965986394	3.0300000000000002	66	697	4	19	9	9	0	2	9	0	0	3.506464741742853	
i 1	179.98514965986394	3.0300000000000002	66	1083	3	14	6	9	0	2	9	0	0	10.42212433883081	
i 1	179.9867551020408	15.655	61	697	4	7	2	6	5001	2	6	0	0	9.11935879647696	
i 1	179.98755782312926	15.655	61	697	6	17	9	6	5001	1	6	0	0	3.506464741742853	
i 1	179.99157142857143	6.0600000000000005	66	697	5	25	13	6	5001	2	6	0	0	0.0268172013360698	
i 1	179.99237414965987	3.0300000000000002	66	697	5	25	8	9	5001	2	9	0	0	0.0268172013360698	
i 1	179.99237414965987	3.0300000000000002	61	1083	3	14	4	9	0	1	9	0	0	10.42212433883081	
i 1	179.9931768707483	3.0300000000000002	66	697	3	27	2	9	0	1	9	0	0	12.373384909427449	
i 1	179.9979931972789	1.2625	69	697	4	24	15	0	5001	-1	0	0	0	11.464552728185682	
i 1	179.9979931972789	3.0300000000000002	74	1083	6	5	9	16	0	1	16	0	0	10.164563645893459	
i 1	179.99879591836734	3.0300000000000002	66	1083	6	17	5	6	0	2	6	0	0	3.506464741742853	
i 1	179.99879591836734	3.0300000000000002	61	1083	6	17	6	6	0	1	6	0	0	3.506464741742853	
i 1	180.00040136054423	1.01	77	697	6	5	11	16	5001	2	16	0	0	10.164563645893459	
i 1	180.00120408163266	2.525	72	697	6	1	16	1	5001	-1	1	0	0	10.464552728185682	
i 1	180.00120408163266	0.2525	69	199	6	1	11	1	0	-1	1	0	0	10.464552728185682	
i 1	180.0020068027211	3.0300000000000002	61	697	3	27	16	6	0	2	6	0	0	12.373384909427449	
i 1	180.0020068027211	5.05	73	199	4	20	1	8	0	-2	8	0	0	7.892101242005808	
i 1	180.00361224489797	12.120000000000001	61	199	5	26	9	6	0	1	6	0	0	0.0268172013360698	
i 1	180.00361224489797	15.655	66	697	3	13	13	6	5001	1	6	0	0	6.513827711769256	
i 1	180.00602040816327	3.0300000000000002	61	697	4	19	4	6	0	2	6	0	0	3.506464741742853	
i 1	180.00842857142857	0.7575000000000001	77	697	6	5	15	16	5001	2	16	0	0	10.164563645893459	
i 1	180.01083673469387	15.655	66	697	6	17	14	9	5001	2	9	0	0	3.506464741742853	
i 1	180.0116394557823	15.655	61	199	5	18	2	9	0	2	9	0	0	3.506464741742853	
i 1	180.0132448979592	0.505	69	1083	6	1	1	1	0	-1	1	0	0	10.464552728185682	
i 1	180.0132448979592	15.655	66	199	5	18	9	6	0	2	6	0	0	3.506464741742853	
i 1	180.0156530612245	9.09	66	199	5	26	7	9	0	1	9	0	0	0.0268172013360698	
i 1	180.23113605442177	0.505	75	199	6	9	7	2	0	1	2	0	0	3.0	
i 1	180.24719047619047	0.2525	72	697	5	3	1	2	0	-2	2	0	0	4.0	
i 1	180.26083673469387	0.7575000000000001	72	697	4	24	11	1	0	-1	1	0	0	11.464552728185682	
i 1	180.48916326530613	0.2525	72	1083	6	1	7	1	0	-1	1	0	0	10.464552728185682	
i 1	180.48996598639457	2.02	73	199	4	20	9	8	0	-2	8	0	0	7.892101242005808	
i 1	180.49397959183673	0.2525	74	199	4	5	9	17	0	2	17	0	0	10.164563645893459	
i 1	180.49959863945577	0.2525	70	697	2	20	5	8	5001	-1	8	0	0	7.892101242005808	
i 1	180.51083673469387	2.525	75	1083	6	2	2	2	0	1	2	0	0	4.0	
i 1	180.7319387755102	0.2525	69	1083	6	1	11	1	0	-1	1	0	0	10.464552728185682	
i 1	180.74397959183673	0.2525	72	199	6	9	7	8	0	1	8	0	0	3.0	
i 1	180.74397959183673	0.2525	72	697	4	4	5	2	0	1	2	0	0	4.0	
i 1	180.75120408163266	1.2625	77	1083	6	5	4	16	0	1	16	0	0	10.164563645893459	
i 1	180.76485034013606	0.7575000000000001	70	199	4	20	14	8	0	-2	8	0	0	7.892101242005808	
i 1	180.76886394557823	0.505	77	199	7	5	3	16	0	1	16	0	0	10.164563645893459	
i 1	180.98916326530613	0.2525	72	1083	6	1	11	1	0	-1	1	0	0	10.464552728185682	
i 1	180.99397959183673	0.2525	75	199	6	9	11	2	0	1	2	0	0	3.0	
i 1	180.99719047619047	0.505	69	199	6	1	12	1	0	-1	1	0	0	10.464552728185682	
i 1	181.01244217687074	0.7575000000000001	75	1083	6	2	11	2	0	1	2	0	0	4.0	
i 1	181.01645578231293	0.2525	73	199	4	24	16	8	0	-1	8	0	0	11.892101242005808	
i 1	181.0180612244898	0.505	74	697	3	5	11	17	0	1	17	0	0	10.164563645893459	
i 1	181.2319387755102	1.2625	77	697	6	5	6	16	5001	2	16	0	0	10.164563645893459	
i 1	181.2455850340136	2.525	73	199	1	24	4	8	0	252	8	307	0	11.892101242005808	
i 1	181.24719047619047	1.2625	72	697	4	24	5	1	0	-1	1	0	0	11.464552728185682	
i 1	181.25280952380953	1.7675	69	1083	6	1	1	1	0	-1	1	0	0	10.464552728185682	
i 1	181.26725850340137	1.7675	70	697	2	20	10	8	5001	-1	8	0	0	7.892101242005808	
i 1	181.4883605442177	0.2525	69	697	4	24	1	0	5001	-1	0	0	0	11.464552728185682	
i 1	181.49478231292517	0.2525	72	199	6	9	12	8	0	1	8	0	0	3.0	
i 1	181.5020068027211	0.2525	77	697	6	5	6	16	5001	2	16	0	0	10.164563645893459	
i 1	181.51966666666667	1.5150000000000001	70	697	2	24	8	2	0	-2	2	0	0	11.892101242005808	
i 1	181.73916326530613	0.2525	75	199	6	9	11	2	0	1	2	0	0	3.0	
i 1	181.7431768707483	0.2525	69	199	6	1	14	1	0	-1	1	0	0	10.464552728185682	
i 1	181.7431768707483	0.505	77	199	7	5	11	16	0	1	16	0	0	10.164563645893459	
i 1	181.76966666666667	0.2525	72	697	4	4	5	2	0	1	2	0	0	4.0	
i 1	181.99719047619047	0.7575000000000001	72	199	6	9	16	8	0	1	8	0	0	3.0	
i 1	181.99719047619047	0.505	72	697	5	3	15	2	0	-2	2	0	0	4.0	
i 1	182.00040136054423	0.2525	74	697	2	5	7	16	0	1	16	0	0	10.164563645893459	
i 1	182.240768707483	1.01	75	199	6	9	9	2	0	1	2	0	0	3.0	
i 1	182.24397959183673	0.2525	74	697	3	5	16	17	0	1	17	0	0	10.164563645893459	
i 1	182.25842857142857	0.2525	77	697	6	5	12	16	5001	2	16	0	0	10.164563645893459	
i 1	182.26404761904763	0.2525	72	1083	6	1	1	1	0	-1	1	0	0	10.464552728185682	
i 1	182.4819387755102	0.2525	69	199	6	1	7	1	0	-1	1	0	0	10.464552728185682	
i 1	182.49478231292517	2.02	72	697	4	4	11	8	5001	-2	8	0	0	4.0	
i 1	182.4979931972789	2.02	69	697	4	24	8	0	5001	-1	0	0	0	11.464552728185682	
i 1	182.5020068027211	0.505	74	199	4	5	4	17	0	2	17	0	0	10.164563645893459	
i 1	182.5068231292517	0.7575000000000001	69	199	6	1	3	1	0	-1	1	0	0	10.464552728185682	
i 1	182.51645578231293	2.525	70	199	4	20	7	8	0	-2	8	0	0	7.892101242005808	
i 1	182.51966666666667	0.505	77	1083	6	5	16	16	0	1	16	0	0	10.164563645893459	
i 1	182.73755782312926	0.2525	75	1083	6	2	10	2	0	1	2	0	0	4.0	
i 1	182.73996598639457	0.2525	72	697	4	24	5	1	0	-1	1	0	0	11.464552728185682	
i 1	182.76404761904763	0.2525	74	697	3	5	4	17	0	1	17	0	0	10.164563645893459	
i 1	182.9867551020408	0.505	77	199	7	5	13	17	0	2	17	0	0	10.164563645893459	
i 1	182.98916326530613	12.120000000000001	61	1083	3	27	3	9	0	1	9	0	0	12.373384909427449	
i 1	182.990768707483	3.0300000000000002	66	1083	3	27	5	6	0	2	6	0	0	12.373384909427449	
i 1	182.99157142857143	0.505	69	199	7	1	15	1	0	0	1	0	0	10.464552728185682	
i 1	182.9931768707483	0.7575000000000001	72	199	7	2	1	8	0	1	8	0	0	4.0	
i 1	182.99478231292517	12.625	61	199	7	17	10	9	0	2	9	0	0	3.506464741742853	
i 1	182.99719047619047	12.120000000000001	66	199	7	17	13	9	0	1	9	0	0	3.506464741742853	
i 1	182.9979931972789	3.535	74	199	7	5	5	17	0	1	17	0	0	10.164563645893459	
i 1	183.0068231292517	2.7775	75	697	5	3	2	2	5001	1	2	0	0	4.0	
i 1	183.00842857142857	0.7575000000000001	73	1083	2	20	13	8	5001	-2	8	0	0	7.892101242005808	
i 1	183.01003401360543	12.120000000000001	61	199	4	14	10	6	0	1	6	0	0	10.42212433883081	
i 1	183.0116394557823	0.505	77	697	6	5	2	16	5001	2	16	0	0	10.164563645893459	
i 1	183.0132448979592	12.625	61	1083	4	19	10	6	0	2	6	0	0	3.506464741742853	
i 1	183.01645578231293	3.0300000000000002	66	1083	4	19	12	9	0	2	9	0	0	3.506464741742853	
i 1	183.0180612244898	0.505	72	1083	4	1	7	0	0	0	0	0	0	10.464552728185682	
i 1	183.01886394557823	0.505	70	1083	2	24	12	8	0	-2	8	0	0	11.892101242005808	
i 1	183.01886394557823	12.625	66	199	4	14	7	6	0	1	6	0	0	10.42212433883081	
i 1	183.23274149659863	0.2525	72	199	6	9	15	8	0	1	8	0	0	3.0	
i 1	183.23274149659863	0.505	74	199	7	5	10	17	0	2	17	0	0	10.164563645893459	
i 1	183.24879591836734	3.2825	72	697	6	1	7	1	5001	-1	1	0	0	10.464552728185682	
i 1	183.4819387755102	0.505	77	199	7	5	15	16	0	1	16	0	0	10.164563645893459	
i 1	183.49157142857143	0.2525	69	199	6	1	12	1	0	-1	1	0	0	10.464552728185682	
i 1	183.50120408163266	0.505	72	1083	4	24	8	1	0	-1	1	0	0	11.464552728185682	
i 1	183.50842857142857	0.2525	74	1083	2	5	14	17	0	2	17	0	0	10.164563645893459	
i 1	183.509231292517	0.505	75	199	6	9	12	2	0	1	2	0	0	3.0	
i 1	183.5156530612245	0.2525	70	1083	2	24	5	8	5001	-2	8	0	0	11.892101242005808	
i 1	183.73514965986394	0.2525	70	1083	2	24	10	8	0	-2	8	0	0	11.892101242005808	
i 1	183.73595238095237	1.5150000000000001	74	1083	3	5	9	17	0	1	17	0	0	10.164563645893459	
i 1	183.74237414965987	0.2525	73	199	4	24	13	8	0	-1	8	0	0	11.892101242005808	
i 1	183.74719047619047	0.2525	77	199	7	5	16	17	0	2	17	0	0	10.164563645893459	
i 1	183.7479931972789	1.01	72	199	6	9	6	8	0	1	8	0	0	3.0	
i 1	183.7568231292517	0.7575000000000001	69	199	7	1	15	1	0	0	1	0	0	10.464552728185682	
i 1	183.99478231292517	0.505	70	1083	2	24	10	8	5001	-2	8	0	0	11.892101242005808	
i 1	183.99719047619047	5.3025	73	1083	2	20	5	8	0	-1	8	0	0	7.892101242005808	
i 1	184.0020068027211	0.2525	72	1083	4	1	3	0	0	0	0	0	0	10.464552728185682	
i 1	184.0044149659864	0.505	74	199	7	5	4	17	0	2	17	0	0	10.164563645893459	
i 1	184.0132448979592	0.2525	72	1083	4	4	2	2	0	1	2	0	0	4.0	
i 1	184.23916326530613	0.2525	72	199	7	1	7	0	0	-1	0	0	0	10.464552728185682	
i 1	184.2431768707483	0.2525	73	1083	2	20	10	8	5001	-2	8	0	0	7.892101242005808	
i 1	184.26966666666667	0.2525	72	199	7	2	1	8	0	1	8	0	0	4.0	
i 1	184.4979931972789	2.02	73	199	4	20	15	8	0	-2	8	0	0	7.892101242005808	
i 1	184.50120408163266	0.2525	73	697	4	24	7	8	5001	-2	8	0	0	11.892101242005808	
i 1	184.50361224489797	0.505	72	1083	5	3	10	8	0	-2	8	0	0	4.0	
i 1	184.50361224489797	0.2525	73	697	4	20	6	8	5001	-2	8	0	0	7.892101242005808	
i 1	184.50842857142857	0.7575000000000001	77	199	7	5	9	17	0	2	17	0	0	10.164563645893459	
i 1	184.51886394557823	2.2725	70	1083	2	24	11	8	0	-2	8	0	0	11.892101242005808	
i 1	184.73033333333333	1.5150000000000001	69	199	7	1	3	1	0	0	1	0	0	10.464552728185682	
i 1	184.73033333333333	3.2825	69	697	4	24	15	0	5001	-1	0	0	0	11.464552728185682	
i 1	184.73916326530613	0.505	73	1083	2	24	11	8	5001	-1	8	0	0	11.892101242005808	
i 1	184.7479931972789	0.2525	72	199	7	1	14	0	0	-1	0	0	0	10.464552728185682	
i 1	184.74879591836734	0.2525	74	1083	2	5	16	17	0	2	17	0	0	10.164563645893459	
i 1	184.7520068027211	2.525	72	199	7	2	4	8	0	1	8	0	0	4.0	
i 1	184.75521768707483	2.7775	70	1083	2	20	16	2	5001	-1	2	0	0	7.892101242005808	
i 1	184.99638775510203	0.505	72	1083	4	24	16	1	0	-1	1	0	0	11.464552728185682	
i 1	185.00040136054423	0.7575000000000001	72	199	6	9	16	8	0	1	8	0	0	3.0	
i 1	185.01725850340137	2.02	77	697	6	5	1	16	5001	2	16	0	0	10.164563645893459	
i 1	185.26645578231293	3.7875	77	697	6	5	10	16	5001	2	16	0	0	10.164563645893459	
i 1	185.51083673469387	0.2525	72	199	7	1	1	0	0	-1	0	0	0	10.464552728185682	
i 1	185.51404761904763	0.2525	77	199	7	5	13	16	0	1	16	0	0	10.164563645893459	
i 1	185.73354421768707	0.2525	69	199	6	1	7	1	0	-1	1	0	0	10.464552728185682	
i 1	185.75602040816327	1.01	75	199	7	2	9	2	0	-2	2	0	0	4.0	
i 1	185.98996598639457	9.595	66	1083	3	27	14	6	0	2	6	0	0	12.373384909427449	
i 1	185.9955850340136	9.595	66	1083	4	19	2	9	0	2	9	0	0	3.506464741742853	
i 1	186.00120408163266	0.2525	75	199	6	9	16	2	0	1	2	0	0	3.0	
i 1	186.01083673469387	0.2525	74	1083	6	5	6	17	0	2	17	0	0	10.164563645893459	
i 1	186.01966666666667	0.2525	72	199	6	9	5	8	0	1	8	0	0	3.0	
i 1	186.24959863945577	1.7675	75	697	5	3	8	2	5001	1	2	0	0	4.0	
i 1	186.2520068027211	0.2525	77	199	7	5	3	17	0	2	17	0	0	10.164563645893459	
i 1	186.25521768707483	3.0300000000000002	72	697	4	4	12	8	5001	-2	8	0	0	4.0	
i 1	186.25602040816327	0.7575000000000001	72	1083	4	24	7	1	0	-1	1	0	0	11.464552728185682	
i 1	186.50040136054423	0.2525	74	199	7	5	11	17	0	2	17	0	0	10.164563645893459	
i 1	186.5180612244898	0.505	69	199	6	1	1	1	0	-1	1	0	0	10.464552728185682	
i 1	186.51886394557823	3.535	70	199	4	20	3	8	0	-2	8	0	0	7.892101242005808	
i 1	186.51966666666667	0.505	77	199	7	5	3	16	0	1	16	0	0	10.164563645893459	
i 1	186.73916326530613	0.2525	72	1083	5	3	5	8	0	-2	8	0	0	4.0	
i 1	186.73916326530613	0.2525	73	199	4	20	14	8	0	-2	8	0	0	7.892101242005808	
i 1	186.7616394557823	3.0300000000000002	77	199	7	5	3	17	0	2	17	0	0	10.164563645893459	
i 1	186.98514965986394	0.2525	75	199	6	9	4	2	0	1	2	0	0	3.0	
i 1	186.98595238095237	0.505	74	1083	6	5	13	17	0	2	17	0	0	10.164563645893459	
i 1	187.0068231292517	0.2525	72	1083	4	1	12	0	0	0	0	0	0	10.464552728185682	
i 1	187.009231292517	1.7675	72	697	6	1	15	1	5001	-1	1	0	0	10.464552728185682	
i 1	187.01485034013606	1.7675	73	199	4	24	1	8	0	-1	8	0	0	11.892101242005808	
i 1	187.0156530612245	0.2525	74	199	7	5	12	17	0	1	17	0	0	10.164563645893459	
i 1	187.01966666666667	0.505	69	199	7	1	11	1	0	0	1	0	0	10.464552728185682	
i 1	187.23354421768707	0.505	72	199	7	1	13	0	0	-1	0	0	0	10.464552728185682	
i 1	187.26404761904763	0.2525	77	697	6	5	8	16	5001	2	16	0	0	10.164563645893459	
i 1	187.2656530612245	0.2525	73	1083	2	24	11	8	5001	-1	8	0	0	11.892101242005808	
i 1	187.48595238095237	0.505	72	199	7	2	9	8	0	1	8	0	0	4.0	
i 1	187.4955850340136	0.2525	72	1083	4	4	7	2	0	1	2	0	0	4.0	
i 1	187.50120408163266	0.505	69	199	6	1	2	1	0	-1	1	0	0	10.464552728185682	
i 1	187.5116394557823	0.2525	70	697	4	24	7	8	5001	-2	8	0	0	11.892101242005808	
i 1	187.51725850340137	0.2525	70	697	4	20	16	8	5001	-1	8	0	0	7.892101242005808	
i 1	187.75521768707483	0.505	73	1083	2	20	6	2	5001	-1	2	0	0	7.892101242005808	
i 1	187.7568231292517	0.505	70	1083	2	24	4	8	5001	-2	8	0	0	11.892101242005808	
i 1	187.75762585034013	0.2525	72	1083	4	1	1	0	0	0	0	0	0	10.464552728185682	
i 1	187.76404761904763	1.2625	70	1083	2	24	13	8	0	-2	8	0	0	11.892101242005808	
i 1	187.98274149659863	0.2525	72	1083	4	24	2	1	0	-1	1	0	0	11.464552728185682	
i 1	187.98514965986394	0.2525	75	199	7	2	15	2	0	-2	2	0	0	4.0	
i 1	188.00280952380953	0.2525	72	1083	4	4	15	2	0	1	2	0	0	4.0	
i 1	188.00361224489797	0.2525	69	199	6	1	13	1	0	-1	1	0	0	10.464552728185682	
i 1	188.00762585034013	1.01	69	199	7	1	2	1	0	0	1	0	0	10.464552728185682	
i 1	188.01886394557823	0.505	75	199	6	9	12	2	0	1	2	0	0	3.0	
i 1	188.23113605442177	0.7575000000000001	69	697	4	24	2	0	5001	-1	0	0	0	11.464552728185682	
i 1	188.24237414965987	4.545	73	199	4	20	1	8	0	-2	8	0	0	7.892101242005808	
i 1	188.24478231292517	0.505	72	199	7	1	5	0	0	-1	0	0	0	10.464552728185682	
i 1	188.24478231292517	0.7575000000000001	77	697	6	5	12	16	5001	2	16	0	0	10.164563645893459	
i 1	188.24959863945577	0.505	72	1083	5	3	7	8	0	-2	8	0	0	4.0	
i 1	188.25040136054423	0.2525	70	697	4	20	6	2	5001	-1	2	0	0	7.892101242005808	
i 1	188.25280952380953	0.2525	73	697	4	24	12	2	5001	-1	2	0	0	11.892101242005808	
i 1	188.26244217687074	0.2525	72	199	6	9	16	8	0	1	8	0	0	3.0	
i 1	188.48274149659863	0.2525	70	1083	2	24	5	2	5001	-2	2	0	0	11.892101242005808	
i 1	188.4883605442177	2.525	75	697	5	3	6	2	5001	1	2	0	0	4.0	
i 1	188.51404761904763	0.7575000000000001	73	1083	2	20	14	8	5001	-2	8	0	0	7.892101242005808	
i 1	188.73755782312926	0.505	73	199	1	24	12	8	0	248	8	308	0	11.892101242005808	
i 1	188.74638775510203	0.505	72	1083	4	1	11	0	0	0	0	0	0	10.464552728185682	
i 1	188.7680612244898	0.2525	69	199	6	1	4	1	0	-1	1	0	0	10.464552728185682	
i 1	188.98595238095237	1.01	74	199	7	5	6	17	0	1	17	0	0	10.164563645893459	
i 1	188.98916326530613	0.2525	75	199	6	9	10	2	0	1	2	0	0	3.0	
i 1	188.98996598639457	3.2825	72	697	6	1	4	1	5001	-1	1	0	0	10.464552728185682	
i 1	189.0156530612245	2.02	70	1083	1	24	5	8	0	252	8	307	0	11.892101242005808	
i 1	189.01886394557823	1.01	69	199	6	1	5	1	0	0	1	0	0	10.464552728185682	
i 1	189.01886394557823	0.2525	69	199	6	1	13	1	0	-1	1	0	0	10.464552728185682	
i 1	189.23113605442177	2.02	73	199	4	20	14	8	0	-2	8	0	0	7.892101242005808	
i 1	189.2431768707483	0.7575000000000001	72	1083	4	4	13	2	0	1	2	0	0	4.0	
i 1	189.24638775510203	0.505	69	199	6	1	2	1	0	-1	1	0	0	10.464552728185682	
i 1	189.25762585034013	0.7575000000000001	72	199	6	9	2	8	0	1	8	0	0	3.0	
i 1	189.26404761904763	0.2525	72	199	7	1	7	0	0	-1	0	0	0	10.464552728185682	
i 1	189.2656530612245	2.2725	77	697	6	5	5	16	5001	2	16	0	0	10.164563645893459	
i 1	189.2680612244898	0.2525	73	199	4	24	13	8	0	-1	8	0	0	11.892101242005808	
i 1	189.48354421768707	0.505	72	1083	4	1	2	0	0	0	0	0	0	10.464552728185682	
i 1	189.50762585034013	0.7575000000000001	72	697	4	4	3	8	5001	-2	8	0	0	4.0	
i 1	189.7367551020408	1.2625	73	199	4	24	15	8	0	-1	8	0	0	11.892101242005808	
i 1	189.76244217687074	0.2525	73	697	4	24	13	8	5001	-1	8	0	0	11.892101242005808	
i 1	189.98033333333333	0.505	72	1083	4	24	2	1	0	-1	1	0	0	11.464552728185682	
i 1	189.98595238095237	0.7575000000000001	72	199	7	1	1	0	0	-1	0	0	0	10.464552728185682	
i 1	189.99478231292517	0.505	70	1083	2	24	10	8	5001	-1	8	0	0	11.892101242005808	
i 1	190.00521768707483	3.2825	72	199	7	2	11	8	0	1	8	0	0	4.0	
i 1	190.01244217687074	0.2525	75	199	7	2	8	2	0	-2	2	0	0	4.0	
i 1	190.0156530612245	0.7575000000000001	77	199	7	5	16	16	0	1	16	0	0	10.164563645893459	
i 1	190.240768707483	0.505	72	199	6	9	6	8	0	1	8	0	0	3.0	
i 1	190.25762585034013	0.2525	69	199	6	1	9	1	0	0	1	0	0	10.464552728185682	
i 1	190.26244217687074	2.525	70	199	4	20	8	8	0	-2	8	0	0	7.892101242005808	
i 1	190.48354421768707	0.2525	74	199	7	5	10	17	0	2	17	0	0	10.164563645893459	
i 1	190.4979931972789	0.2525	72	1083	4	1	14	0	0	0	0	0	0	10.464552728185682	
i 1	190.51886394557823	0.7575000000000001	74	1083	6	5	2	17	0	1	17	0	0	10.164563645893459	
i 1	190.51886394557823	0.2525	73	697	4	24	2	2	5001	-1	2	0	0	11.892101242005808	
i 1	190.7343469387755	2.2725	74	199	7	5	11	17	0	1	17	0	0	10.164563645893459	
i 1	190.74719047619047	0.7575000000000001	69	697	4	24	16	0	5001	-1	0	0	0	11.464552728185682	
i 1	190.74959863945577	1.01	72	697	4	4	6	8	5001	-2	8	0	0	4.0	
i 1	190.75120408163266	0.2525	72	1083	4	24	7	1	0	-1	1	0	0	11.464552728185682	
i 1	190.76244217687074	0.2525	70	1083	2	24	10	2	5001	-1	2	0	0	11.892101242005808	
i 1	190.98755782312926	0.2525	77	697	6	5	13	16	5001	2	16	0	0	10.164563645893459	
i 1	191.00842857142857	0.2525	75	199	7	2	2	2	0	-2	2	0	0	4.0	
i 1	191.01645578231293	1.01	69	199	6	1	6	1	0	0	1	0	0	10.464552728185682	
i 1	191.01645578231293	0.2525	70	1083	2	24	2	8	0	-2	8	0	0	11.892101242005808	
i 1	191.23113605442177	0.505	70	1083	2	24	7	2	5001	-1	2	0	0	11.892101242005808	
i 1	191.24638775510203	0.2525	75	199	6	9	1	2	0	1	2	0	0	3.0	
i 1	191.24638775510203	0.505	74	199	7	5	10	17	0	2	17	0	0	10.164563645893459	
i 1	191.24879591836734	0.2525	75	697	5	3	12	2	5001	1	2	0	0	4.0	
i 1	191.26083673469387	0.2525	69	199	6	1	13	1	0	-1	1	0	0	10.464552728185682	
i 1	191.26083673469387	0.2525	77	199	7	5	1	17	0	2	17	0	0	10.164563645893459	
i 1	191.48595238095237	0.2525	69	199	6	1	4	1	0	-1	1	0	0	10.464552728185682	
i 1	191.49719047619047	0.2525	70	1083	2	20	9	2	5001	-2	2	0	0	7.892101242005808	
i 1	191.50280952380953	0.7575000000000001	72	1083	5	3	15	8	0	-2	8	0	0	4.0	
i 1	191.5116394557823	0.505	72	1083	4	1	13	0	0	0	0	0	0	10.464552728185682	
i 1	191.5132448979592	0.7575000000000001	74	1083	6	5	10	17	0	1	17	0	0	10.164563645893459	
i 1	191.5180612244898	0.2525	75	199	7	2	10	2	0	-2	2	0	0	4.0	
i 1	191.73354421768707	0.505	72	1083	4	4	3	2	0	1	2	0	0	4.0	
i 1	191.73514965986394	0.505	77	199	7	5	13	17	0	2	17	0	0	10.164563645893459	
i 1	191.74959863945577	0.2525	74	1083	6	5	9	17	0	2	17	0	0	10.164563645893459	
i 1	191.75040136054423	1.7675	73	1083	2	20	4	8	0	-1	8	0	0	7.892101242005808	
i 1	191.9819387755102	0.2525	75	697	5	3	13	2	5001	1	2	0	0	4.0	
i 1	191.9819387755102	2.2725	77	697	6	5	8	16	5001	2	16	0	0	10.164563645893459	
i 1	191.9867551020408	0.2525	69	697	4	24	16	0	5001	-1	0	0	0	11.464552728185682	
i 1	192.00521768707483	1.7675	69	199	7	1	7	1	0	0	1	0	0	10.464552728185682	
i 1	192.00602040816327	1.7675	70	1083	2	20	3	2	5001	-2	2	0	0	7.892101242005808	
i 1	192.01725850340137	0.505	69	199	6	1	3	1	0	-1	1	0	0	10.464552728185682	
i 1	192.23274149659863	0.2525	72	1083	4	1	3	0	0	0	0	0	0	10.464552728185682	
i 1	192.23274149659863	2.2725	72	697	4	4	3	8	5001	-2	8	0	0	4.0	
i 1	192.25040136054423	0.2525	75	199	7	2	7	2	0	-2	2	0	0	4.0	
i 1	192.25040136054423	0.505	75	199	6	9	2	2	0	1	2	0	0	3.0	
i 1	192.2520068027211	0.2525	74	1083	6	5	9	17	0	2	17	0	0	10.164563645893459	
i 1	192.2680612244898	0.505	72	199	6	1	9	0	0	-1	0	0	0	10.464552728185682	
i 1	192.50361224489797	1.7675	72	697	6	1	8	1	5001	-1	1	0	0	10.464552728185682	
i 1	192.5156530612245	0.7575000000000001	77	697	6	5	8	16	5001	2	16	0	0	10.164563645893459	
i 1	192.51966666666667	0.2525	74	199	7	5	9	17	0	2	17	0	0	10.164563645893459	
i 1	192.73755782312926	0.2525	75	199	7	2	7	2	0	-2	2	0	0	4.0	
i 1	192.740768707483	0.7575000000000001	72	199	6	9	7	8	0	1	8	0	0	3.0	
i 1	192.7544149659864	0.2525	69	697	4	24	3	0	5001	-1	0	0	0	11.464552728185682	
i 1	192.75521768707483	1.01	70	1083	2	24	11	2	5001	-1	2	0	0	11.892101242005808	
i 1	192.7568231292517	0.2525	69	199	6	1	3	1	0	-1	1	0	0	10.464552728185682	
i 1	192.76725850340137	1.2625	73	199	4	24	7	8	0	-1	8	0	0	11.892101242005808	
i 1	192.99959863945577	0.505	72	1083	4	4	14	2	0	1	2	0	0	4.0	
i 1	193.01244217687074	0.7575000000000001	74	1083	6	5	13	17	0	1	17	0	0	10.164563645893459	
i 1	193.23113605442177	1.01	69	199	6	1	14	1	0	-1	1	0	0	10.464552728185682	
i 1	193.23996598639457	1.01	70	1083	2	24	13	8	0	-2	8	0	0	11.892101242005808	
i 1	193.240768707483	0.2525	74	1083	6	5	14	17	0	2	17	0	0	10.164563645893459	
i 1	193.24157142857143	0.2525	74	199	7	5	7	17	0	2	17	0	0	10.164563645893459	
i 1	193.25040136054423	2.02	75	697	5	3	16	2	5001	1	2	0	0	4.0	
i 1	193.4867551020408	0.505	72	1083	4	24	15	1	0	-1	1	0	0	11.464552728185682	
i 1	193.50280952380953	0.2525	77	697	6	5	5	16	5001	2	16	0	0	10.164563645893459	
i 1	193.51404761904763	0.2525	75	199	6	9	12	2	0	1	2	0	0	3.0	
i 1	193.51725850340137	1.7675	77	199	7	5	5	17	0	2	17	0	0	10.164563645893459	
i 1	193.73514965986394	1.01	73	1083	2	20	3	8	0	-1	8	0	0	7.892101242005808	
i 1	193.73755782312926	0.2525	73	697	4	24	14	8	5001	-1	8	0	0	11.892101242005808	
i 1	193.74397959183673	0.2525	72	1083	5	3	11	8	0	-2	8	0	0	4.0	
i 1	193.7544149659864	0.2525	72	199	7	2	12	8	0	1	8	0	0	4.0	
i 1	193.75602040816327	0.2525	73	697	4	20	13	2	5001	-2	2	0	0	7.892101242005808	
i 1	193.76244217687074	1.7675	69	697	4	24	15	0	5001	-1	0	0	0	11.464552728185682	
i 1	193.98113605442177	0.2525	69	199	6	1	4	1	0	-1	1	0	0	10.464552728185682	
i 1	193.98354421768707	0.505	74	199	7	5	10	17	0	1	17	0	0	10.164563645893459	
i 1	193.9931768707483	0.505	73	1083	2	20	5	2	5001	-1	2	0	0	7.892101242005808	
i 1	194.00842857142857	0.2525	75	199	7	2	10	2	0	-2	2	0	0	4.0	
i 1	194.01244217687074	0.2525	77	199	7	5	3	16	0	1	16	0	0	10.164563645893459	
i 1	194.23033333333333	0.2525	72	1083	4	24	12	1	0	-1	1	0	0	11.464552728185682	
i 1	194.23354421768707	0.2525	74	1083	6	5	16	17	0	2	17	0	0	10.164563645893459	
i 1	194.2431768707483	0.7575000000000001	70	199	4	20	8	8	0	-2	8	0	0	7.892101242005808	
i 1	194.24959863945577	0.505	75	199	6	9	16	2	0	1	2	0	0	3.0	
i 1	194.2544149659864	0.7575000000000001	77	697	6	5	16	16	5001	2	16	0	0	10.164563645893459	
i 1	194.2568231292517	1.2625	73	199	4	24	2	8	0	-1	8	0	0	11.892101242005808	
i 1	194.25762585034013	0.7575000000000001	69	199	7	1	7	1	0	0	1	0	0	10.464552728185682	
i 1	194.48274149659863	0.2525	72	199	6	9	4	8	0	1	8	0	0	3.0	
i 1	194.48354421768707	0.2525	73	697	4	20	9	8	5001	-2	8	0	0	7.892101242005808	
i 1	194.50280952380953	0.2525	73	697	4	24	14	2	5001	-1	2	0	0	11.892101242005808	
i 1	194.73113605442177	0.2525	72	697	6	1	8	1	5001	-1	1	0	0	10.464552728185682	
i 1	194.73514965986394	0.7575000000000001	77	697	6	5	11	16	5001	2	16	0	0	10.164563645893459	
i 1	194.74237414965987	0.2525	72	1083	4	4	4	2	0	1	2	0	0	4.0	
i 1	194.74719047619047	0.7575000000000001	72	199	7	2	11	8	0	1	8	0	0	4.0	
i 1	194.76083673469387	0.7575000000000001	70	1083	2	24	14	8	5001	-2	8	0	0	11.892101242005808	
i 1	194.98354421768707	0.505	61	1083	1	27	4	9	0	248	9	308	0	12.373384909427449	
i 1	194.98916326530613	0.505	72	697	5	1	10	1	5001	-1	1	0	0	10.464552728185682	
i 1	194.99879591836734	0.505	61	199	6	14	9	6	0	1	6	0	0	10.42212433883081	
i 1	195.0068231292517	0.505	73	199	4	20	11	8	0	-2	8	0	0	7.892101242005808	
i 1	195.01886394557823	0.505	66	199	7	17	8	9	0	1	9	0	0	3.506464741742853	
i 1	195.01966666666667	0.505	72	199	7	1	10	0	0	-1	0	0	0	10.464552728185682	
i 1	195.23916326530613	0.2525	73	199	4	20	10	8	0	-2	8	0	0	7.892101242005808	
i 1	195.23996598639457	0.2525	74	1083	6	5	14	17	0	2	17	0	0	10.164563645893459	
i 1	195.25842857142857	0.2525	74	199	7	5	14	17	0	1	17	0	0	10.164563645893459	
i 1	195.2616394557823	0.2525	72	1083	4	1	14	0	0	0	0	0	0	10.464552728185682	
i 1	195.26404761904763	0.2525	72	697	4	4	15	8	5001	-2	8	0	0	4.0	
i 1	195.48354421768707	1.01	72	204	4	1	7	2	0	-2	2	0	0	10.0	
i 1	195.48595238095237	12.625	61	204	7	17	4	16	0	1	16	0	0	0.5009235345346933	
i 1	195.49157142857143	0.2525	77	1088	4	4	1	16	0	2	16	0	0	4.0	
i 1	195.4931768707483	3.0300000000000002	61	204	4	14	5	16	0	2	16	0	0	6.513827711769258	
i 1	195.49879591836734	9.09	61	1088	4	7	7	16	0	1	16	0	0	5.211062169415406	
i 1	195.50280952380953	3.0300000000000002	63	204	3	14	8	16	0	2	16	0	0	6.513827711769258	
i 1	195.509231292517	0.2525	73	702	3	24	15	16	0	2	16	0	0	4.0	
i 1	195.5116394557823	1.5150000000000001	77	204	7	2	12	17	0	1	17	0	0	4.0	
i 1	195.51244217687074	6.0600000000000005	63	1088	3	13	7	1	0	2	1	0	0	2.605531084707703	
i 1	195.51485034013606	1.5150000000000001	74	204	5	5	16	8	0	-2	8	0	0	6.0	
i 1	195.51485034013606	0.2525	71	204	5	5	2	8	0	-1	8	0	0	6.0	
i 1	195.5180612244898	0.505	75	204	5	1	8	2	0	1	2	0	0	10.0	
i 1	195.51886394557823	0.2525	74	702	4	5	12	2	0	-2	2	0	0	6.0	
i 1	195.74719047619047	0.2525	77	702	5	9	14	17	0	2	17	0	0	3.0	
i 1	195.74879591836734	0.2525	74	702	4	4	5	16	0	1	16	0	0	4.0	
i 1	195.759231292517	0.2525	71	702	4	5	9	8	0	-1	8	0	0	6.0	
i 1	195.990768707483	0.505	77	1088	4	4	2	16	0	2	16	0	0	4.0	
i 1	195.99638775510203	0.2525	77	702	5	9	15	17	0	1	17	0	0	3.0	
i 1	196.00762585034013	0.2525	75	702	5	1	4	8	0	-2	8	0	0	10.0	
i 1	196.24397959183673	2.2725	75	204	5	1	15	2	0	1	2	0	0	10.0	
i 1	196.48354421768707	0.2525	72	702	5	1	14	2	0	1	2	0	0	10.0	
i 1	196.4883605442177	0.2525	77	702	5	9	13	17	0	1	17	0	0	3.0	
i 1	196.51083673469387	0.2525	77	702	5	9	12	17	0	2	17	0	0	3.0	
i 1	196.51083673469387	0.2525	71	1088	4	5	2	8	0	-1	8	0	0	6.0	
i 1	196.51966666666667	1.2625	73	702	3	24	12	16	0	2	16	0	0	4.0	
i 1	196.73514965986394	0.505	77	1088	4	4	10	16	0	2	16	0	0	4.0	
i 1	196.7367551020408	0.2525	72	1088	4	24	15	8	0	1	8	0	0	11.0	
i 1	196.76083673469387	0.505	71	204	5	5	7	8	0	-1	8	0	0	6.0	
i 1	196.98274149659863	0.2525	71	1088	4	5	1	2	0	-2	2	0	0	6.0	
i 1	197.00120408163266	1.5150000000000001	77	204	6	2	7	16	0	2	16	0	0	4.0	
i 1	197.23113605442177	1.7675	71	1088	4	5	4	8	0	-1	8	0	0	6.0	
i 1	197.23354421768707	1.01	73	702	3	24	12	16	0	2	16	0	0	4.0	
i 1	197.23755782312926	0.2525	72	702	5	1	5	2	0	1	2	0	0	10.0	
i 1	197.24157142857143	0.505	74	204	5	5	16	8	0	-2	8	0	0	6.0	
i 1	197.2616394557823	0.2525	74	702	4	4	8	16	0	1	16	0	0	4.0	
i 1	197.26404761904763	0.2525	72	1088	4	1	15	2	0	1	2	0	0	10.0	
i 1	197.4843469387755	0.7575000000000001	72	1088	4	24	16	8	0	1	8	0	0	11.0	
i 1	197.51645578231293	0.2525	77	1088	4	4	4	16	0	2	16	0	0	4.0	
i 1	197.7319387755102	0.2525	74	702	4	5	5	2	0	-2	2	0	0	6.0	
i 1	197.76485034013606	0.7575000000000001	73	702	1	24	11	16	0	252	16	307	0	4.0	
i 1	197.98274149659863	1.2625	72	1088	4	1	6	2	0	1	2	0	0	10.0	
i 1	198.00120408163266	0.2525	71	204	5	5	14	8	0	-1	8	0	0	6.0	
i 1	198.48274149659863	3.0300000000000002	63	204	4	14	2	16	0	2	16	0	0	6.513827711769258	
i 1	198.49478231292517	2.2725	72	204	7	1	8	2	0	-2	2	0	0	10.0	
i 1	198.49719047619047	1.2625	76	702	2	20	3	16	0	1	16	0	0	0.7914432566067586	
i 1	198.5068231292517	9.09	61	204	6	14	8	16	0	2	16	0	0	6.513827711769258	
i 1	198.51485034013606	1.2625	76	702	3	20	12	16	0	1	16	0	0	0.7914432566067586	
i 1	198.5156530612245	9.595	63	204	7	17	5	1	0	1	1	0	0	0.5009235345346933	
i 1	198.7319387755102	1.2625	74	204	7	5	15	8	0	-2	8	0	0	6.0	
i 1	198.75521768707483	0.2525	71	1088	4	5	8	2	0	-2	2	0	0	6.0	
i 1	198.76485034013606	0.2525	77	702	5	9	16	17	0	1	17	0	0	3.0	
i 1	198.7656530612245	1.7675	77	1088	5	3	8	16	0	1	16	0	0	4.0	
i 1	198.76966666666667	0.2525	72	1088	4	24	16	8	0	1	8	0	0	11.0	
i 1	198.9843469387755	0.2525	76	702	1	20	3	16	0	1	16	0	0	0.7914432566067586	
i 1	198.98996598639457	0.2525	75	204	4	1	6	2	0	1	2	0	0	10.0	
i 1	199.00040136054423	0.505	77	204	7	2	3	16	0	2	16	0	0	4.0	
i 1	199.01886394557823	0.505	71	702	4	5	15	8	0	-1	8	0	0	6.0	
i 1	199.26404761904763	0.505	77	702	5	3	6	17	0	1	17	0	0	4.0	
i 1	199.4931768707483	0.2525	71	1088	4	5	16	2	0	-2	2	0	0	6.0	
i 1	199.4955850340136	0.2525	75	702	4	1	14	8	0	-2	8	0	0	10.0	
i 1	199.49719047619047	0.2525	75	702	4	24	12	2	0	1	2	0	0	11.0	
i 1	199.5044149659864	0.2525	74	702	4	5	12	2	0	-2	2	0	0	6.0	
i 1	199.7520068027211	0.505	71	702	4	5	4	8	0	-1	8	0	0	6.0	
i 1	199.75521768707483	0.505	72	1088	4	1	2	2	0	1	2	0	0	10.0	
i 1	199.75842857142857	0.2525	77	702	5	9	6	17	0	1	17	0	0	3.0	
i 1	199.76083673469387	1.2625	76	702	1	24	1	17	0	1	17	0	0	4.791443256606758	
i 1	199.76645578231293	1.7675	73	702	3	20	9	16	0	2	16	0	0	0.7914432566067586	
i 1	199.98916326530613	2.2725	77	204	7	2	8	17	0	1	17	0	0	4.0	
i 1	200.00762585034013	1.5150000000000001	71	204	5	5	10	8	0	-1	8	0	0	6.0	
i 1	200.24157142857143	0.2525	75	702	4	24	5	2	0	1	2	0	0	11.0	
i 1	200.26485034013606	0.505	71	702	4	5	1	8	0	-1	8	0	0	6.0	
i 1	200.4819387755102	0.505	75	702	4	1	13	2	0	1	2	0	0	10.0	
i 1	200.49237414965987	0.2525	77	1088	4	4	8	16	0	2	16	0	0	4.0	
i 1	200.509231292517	1.01	75	204	4	1	5	2	0	1	2	0	0	10.0	
i 1	200.74478231292517	0.2525	71	1088	4	5	9	2	0	-2	2	0	0	6.0	
i 1	200.74719047619047	0.505	71	702	4	5	4	8	0	-1	8	0	0	6.0	
i 1	200.75120408163266	0.2525	74	702	4	4	1	16	0	1	16	0	0	4.0	
i 1	200.98033333333333	0.2525	74	702	4	5	2	2	0	-2	2	0	0	6.0	
i 1	200.98514965986394	0.505	73	1088	1	20	5	17	0	2	17	0	0	0.7914432566067586	
i 1	201.01645578231293	1.2625	72	1088	4	24	10	8	0	1	8	0	0	11.0	
i 1	201.25521768707483	0.2525	73	204	3	20	2	16	0	1	16	0	0	0.7914432566067586	
i 1	201.48514965986394	0.2525	75	702	4	1	11	8	0	-2	8	0	0	10.0	
i 1	201.48514965986394	1.5150000000000001	71	1088	4	5	15	8	0	-1	8	0	0	6.0	
i 1	201.49719047619047	6.565	61	1088	6	17	5	1	0	2	1	0	0	0.5009235345346933	
i 1	201.50040136054423	3.0300000000000002	63	1088	3	13	1	1	0	2	1	0	0	2.605531084707703	
i 1	201.50521768707483	1.01	76	702	2	20	13	16	0	2	16	0	0	0.7914432566067586	
i 1	201.5068231292517	0.2525	75	702	4	24	2	2	0	1	2	0	0	11.0	
i 1	201.5116394557823	1.01	73	702	3	24	2	16	0	2	16	0	0	4.791443256606758	
i 1	201.51645578231293	6.565	63	204	6	14	12	16	0	2	16	0	0	6.513827711769258	
i 1	201.73354421768707	0.2525	72	204	7	1	9	2	0	-2	2	0	0	10.0	
i 1	201.73916326530613	0.2525	77	702	5	9	8	17	0	2	17	0	0	3.0	
i 1	201.76003401360543	1.01	77	204	7	2	8	16	0	2	16	0	0	4.0	
i 1	201.76725850340137	0.2525	76	702	3	20	5	16	0	1	16	0	0	0.7914432566067586	
i 1	201.76886394557823	0.2525	75	702	4	1	3	2	0	1	2	0	0	10.0	
i 1	201.9867551020408	0.2525	72	702	6	1	9	2	0	1	2	0	0	10.0	
i 1	201.99397959183673	1.7675	72	1088	3	1	1	2	0	1	2	0	0	10.0	
i 1	202.00040136054423	0.2525	73	702	3	24	11	16	0	2	16	0	0	4.791443256606758	
i 1	202.01244217687074	0.2525	74	702	4	5	2	2	0	-2	2	0	0	6.0	
i 1	202.2319387755102	0.505	75	204	7	1	6	2	0	1	2	0	0	10.0	
i 1	202.2383605442177	0.505	74	204	7	5	7	8	0	-2	8	0	0	6.0	
i 1	202.26886394557823	1.2625	73	702	1	24	11	16	0	252	16	307	0	4.791443256606758	
i 1	202.26966666666667	0.2525	77	702	5	9	13	17	0	1	17	0	0	3.0	
i 1	202.4867551020408	1.7675	77	1088	4	4	14	16	0	2	16	0	0	4.0	
i 1	202.4883605442177	0.2525	72	702	4	1	4	2	0	1	2	0	0	10.0	
i 1	202.490768707483	0.2525	76	1088	2	20	3	16	0	2	16	0	0	0.7914432566067586	
i 1	202.49157142857143	0.2525	71	702	4	5	6	8	0	-1	8	0	0	6.0	
i 1	202.51083673469387	0.2525	74	702	4	4	11	16	0	1	16	0	0	4.0	
i 1	202.5132448979592	1.01	73	702	3	20	6	16	0	2	16	0	0	0.7914432566067586	
i 1	202.73755782312926	0.505	76	702	1	24	10	17	0	2	17	0	0	4.791443256606758	
i 1	202.7383605442177	0.2525	75	702	4	24	15	2	0	1	2	0	0	11.0	
i 1	202.76485034013606	0.7575000000000001	77	702	5	3	13	17	0	1	17	0	0	4.0	
i 1	202.7680612244898	0.505	76	702	2	20	6	17	0	2	17	0	0	0.7914432566067586	
i 1	202.76886394557823	0.7575000000000001	71	1088	4	5	6	2	0	-2	2	0	0	6.0	
i 1	202.99719047619047	0.2525	75	702	4	1	16	8	0	-2	8	0	0	10.0	
i 1	203.0020068027211	0.2525	71	702	4	5	11	8	0	-1	8	0	0	6.0	
i 1	203.00602040816327	0.2525	71	204	7	5	2	8	0	-1	8	0	0	6.0	
i 1	203.009231292517	0.2525	75	204	7	1	11	2	0	1	2	0	0	10.0	
i 1	203.23755782312926	0.2525	76	1088	2	20	1	17	0	1	17	0	0	0.7914432566067586	
i 1	203.24397959183673	0.2525	74	702	4	5	15	2	0	-2	2	0	0	6.0	
i 1	203.2520068027211	0.2525	77	702	5	9	4	17	0	1	17	0	0	3.0	
i 1	203.25521768707483	0.2525	76	1088	1	24	4	17	0	2	17	0	0	4.791443256606758	
i 1	203.26083673469387	0.7575000000000001	73	702	3	24	10	16	0	2	16	0	0	4.791443256606758	
i 1	203.26244217687074	1.7675	74	204	7	5	14	8	0	-2	8	0	0	6.0	
i 1	203.26886394557823	0.7575000000000001	72	204	7	1	4	2	0	-2	2	0	0	10.0	
i 1	203.49157142857143	0.2525	77	204	7	2	8	17	0	1	17	0	0	4.0	
i 1	203.4955850340136	0.2525	73	702	1	24	9	16	0	2	16	0	0	4.791443256606758	
i 1	203.5044149659864	0.505	73	702	2	20	11	16	0	1	16	0	0	0.7914432566067586	
i 1	203.7632448979592	0.505	75	702	4	24	16	2	0	1	2	0	0	11.0	
i 1	203.76725850340137	0.2525	75	702	4	1	15	2	0	1	2	0	0	10.0	
i 1	204.00361224489797	0.505	73	702	3	20	8	16	0	2	16	0	0	0.7914432566067586	
i 1	204.00762585034013	1.7675	77	1088	5	3	10	16	0	1	16	0	0	4.0	
i 1	204.00762585034013	0.2525	76	1088	2	20	2	17	0	2	17	0	0	0.7914432566067586	
i 1	204.0132448979592	0.7575000000000001	75	204	7	1	16	2	0	1	2	0	0	10.0	
i 1	204.23514965986394	0.2525	72	1088	3	1	10	2	0	1	2	0	0	10.0	
i 1	204.23514965986394	0.2525	73	702	1	24	5	16	0	2	16	0	0	4.791443256606758	
i 1	204.23595238095237	0.2525	76	702	2	20	10	16	0	2	16	0	0	0.7914432566067586	
i 1	204.2383605442177	0.2525	71	1088	4	5	15	2	0	-2	2	0	0	6.0	
i 1	204.24959863945577	1.01	71	204	7	5	4	8	0	-1	8	0	0	6.0	
i 1	204.2680612244898	0.2525	73	702	2	20	8	17	0	1	17	0	0	0.7914432566067586	
i 1	204.48113605442177	0.2525	77	1088	4	4	11	16	0	2	16	0	0	4.0	
i 1	204.48514965986394	3.0300000000000002	61	1088	4	7	15	16	0	1	16	0	0	5.211062169415406	
i 1	204.4931768707483	0.2525	72	204	7	1	9	2	0	-2	2	0	0	10.0	
i 1	204.5068231292517	0.2525	77	702	5	9	16	17	0	1	17	0	0	3.0	
i 1	204.51244217687074	3.535	63	1088	5	13	7	1	0	2	1	0	0	2.605531084707703	
i 1	204.5132448979592	3.535	63	1088	6	17	7	16	0	1	16	0	0	0.5009235345346933	
i 1	204.73755782312926	0.505	77	702	5	3	14	17	0	1	17	0	0	4.0	
i 1	204.740768707483	0.505	75	702	4	1	14	2	0	1	2	0	0	10.0	
i 1	204.74719047619047	1.2625	71	1088	4	5	6	8	0	-1	8	0	0	6.0	
i 1	204.7568231292517	1.5150000000000001	72	1088	3	24	1	8	0	1	8	0	0	11.0	
i 1	205.0068231292517	0.2525	73	702	3	20	6	16	0	2	16	0	0	0.6335246007848028	
i 1	205.23595238095237	2.525	76	702	2	20	13	16	0	1	16	0	0	0.6335246007848028	
i 1	205.23755782312926	0.2525	75	204	7	1	11	2	0	1	2	0	0	10.0	
i 1	205.2383605442177	0.2525	75	702	4	1	11	8	0	-2	8	0	0	10.0	
i 1	205.25521768707483	0.7575000000000001	76	702	1	24	4	16	0	252	16	307	0	4.633524600784803	
i 1	205.259231292517	2.2725	73	702	1	24	12	16	0	2	16	0	0	4.633524600784803	
i 1	205.26003401360543	0.2525	74	204	7	5	10	8	0	-2	8	0	0	6.0	
i 1	205.2632448979592	0.7575000000000001	77	204	7	2	14	17	0	1	17	0	0	4.0	
i 1	205.26725850340137	0.2525	74	702	4	5	4	2	0	-1	2	0	0	6.0	
i 1	205.49719047619047	0.2525	75	702	4	24	5	2	0	1	2	0	0	11.0	
i 1	205.509231292517	0.2525	76	702	2	20	10	17	0	1	17	0	0	0.6335246007848028	
i 1	205.51966666666667	0.2525	71	1088	6	5	12	2	0	-2	2	0	0	6.0	
i 1	205.74959863945577	2.02	77	204	7	2	7	16	0	2	16	0	0	4.0	
i 1	205.7656530612245	1.7675	72	1088	6	1	12	2	0	1	2	0	0	10.0	
i 1	205.76645578231293	0.505	74	702	4	4	12	16	0	1	16	0	0	4.0	
i 1	205.98033333333333	0.2525	75	702	4	1	1	2	0	1	2	0	0	10.0	
i 1	205.9867551020408	0.7575000000000001	77	1088	5	3	1	16	0	1	16	0	0	4.0	
i 1	206.0020068027211	1.7675	71	1088	6	5	5	2	0	-2	2	0	0	6.0	
i 1	206.00762585034013	0.2525	76	702	2	24	5	16	0	2	16	0	0	4.633524600784803	
i 1	206.23113605442177	1.2625	72	204	7	1	9	2	0	-2	2	0	0	10.0	
i 1	206.26966666666667	1.5150000000000001	76	702	1	24	5	16	0	252	16	307	0	4.633524600784803	
i 1	206.49157142857143	0.505	71	702	4	5	16	8	0	-1	8	0	0	6.0	
i 1	206.51485034013606	0.2525	77	702	5	9	11	17	0	1	17	0	0	3.0	
i 1	206.75280952380953	0.2525	77	204	7	2	4	17	0	1	17	0	0	4.0	
i 1	206.98113605442177	0.2525	77	702	5	3	8	17	0	1	17	0	0	4.0	
i 1	206.99879591836734	0.2525	75	702	4	24	12	2	0	1	2	0	0	11.0	
i 1	207.23996598639457	0.7575000000000001	77	1088	4	4	4	16	0	2	16	0	0	4.0	
i 1	207.24959863945577	0.2525	71	702	4	5	5	8	0	-1	8	0	0	6.0	
i 1	207.25762585034013	0.505	73	702	2	20	6	17	0	1	17	0	0	0.6335246007848028	
i 1	207.48113605442177	0.505	74	204	7	5	12	8	0	-2	8	0	0	6.0	
i 1	207.4843469387755	0.505	61	1088	5	7	13	16	0	1	16	0	0	5.211062169415406	
i 1	207.4867551020408	0.2525	76	702	2	20	6	17	0	1	17	0	0	0.6335246007848028	
i 1	207.4883605442177	0.505	73	702	3	20	11	16	0	2	16	0	0	0.6335246007848028	
i 1	207.49638775510203	0.505	77	204	7	2	8	17	0	1	17	0	0	4.0	
i 1	207.49719047619047	0.505	72	204	4	1	4	2	0	-2	2	0	0	10.0	
i 1	207.4979931972789	0.2525	73	702	2	24	4	16	0	2	16	0	0	4.633524600784803	
i 1	207.50040136054423	0.505	61	204	5	14	13	16	0	2	16	0	0	6.513827711769258	
i 1	207.50521768707483	0.505	63	702	4	18	3	16	0	1	16	0	0	0.5009235345346933	
i 1	207.50762585034013	0.2525	72	702	4	1	10	2	0	1	2	0	0	10.0	
i 1	207.5180612244898	0.2525	76	702	1	20	12	16	0	1	16	0	0	0.6335246007848028	
i 1	207.73033333333333	0.2525	71	1088	6	5	4	8	0	-1	8	0	0	6.0	
i 1	207.73916326530613	0.2525	75	702	4	24	5	2	0	1	2	0	0	11.0	
i 1	207.7479931972789	0.2525	77	702	5	3	16	17	0	1	17	0	0	4.0	
i 1	207.75361224489797	0.2525	72	1088	4	24	3	8	0	1	8	0	0	11.0	
i 1	207.76083673469387	0.2525	73	1088	2	20	14	16	0	1	16	0	0	0.6335246007848028	
i 1	207.98113605442177	7.07	63	386	6	17	16	1	0	2	1	0	0	0.5009235345346933	
i 1	207.98274149659863	2.525	61	702	5	14	10	1	0	2	1	0	0	6.513827711769258	
i 1	207.9843469387755	1.01	74	702	6	2	11	17	0	2	17	0	0	4.0	
i 1	207.9867551020408	12.625	61	702	5	14	1	16	0	1	16	0	0	6.513827711769258	
i 1	207.99237414965987	2.525	61	702	6	17	13	16	0	2	16	0	0	0.5009235345346933	
i 1	207.99478231292517	7.07	61	386	6	7	4	1	0	2	1	0	0	5.211062169415406	
i 1	207.99638775510203	5.555	63	702	6	17	16	16	0	2	16	0	0	0.5009235345346933	
i 1	208.00120408163266	0.505	76	386	3	24	12	16	0	2	16	0	0	4.633524600784803	
i 1	208.00280952380953	7.07	61	386	6	17	13	16	0	2	16	0	0	0.5009235345346933	
i 1	208.00521768707483	0.2525	74	702	6	5	7	8	0	-1	8	0	0	6.0	
i 1	208.0068231292517	12.625	63	1088	4	18	15	1	0	2	1	0	0	0.5009235345346933	
i 1	208.01244217687074	0.505	74	1088	5	9	6	16	0	1	16	0	0	3.0	
i 1	208.01404761904763	5.555	63	386	5	13	11	1	0	2	1	0	0	2.605531084707703	
i 1	208.01485034013606	0.2525	74	386	6	5	13	8	0	-1	8	0	0	6.0	
i 1	208.01485034013606	1.2625	76	386	2	20	8	17	0	1	17	0	0	0.6335246007848028	
i 1	208.0180612244898	1.7675	72	386	4	24	13	8	0	1	8	0	0	11.0	
i 1	208.24397959183673	0.2525	75	386	6	1	8	2	0	1	2	0	0	10.0	
i 1	208.2455850340136	0.505	72	1088	3	1	2	2	0	-2	2	0	0	10.0	
i 1	208.2455850340136	1.7675	74	386	6	5	3	8	0	-1	8	0	0	6.0	
i 1	208.25120408163266	0.2525	74	386	4	5	4	2	0	-1	2	0	0	6.0	
i 1	208.25521768707483	0.2525	74	386	5	3	8	17	0	1	17	0	0	4.0	
i 1	208.48354421768707	2.02	77	702	6	2	12	17	0	1	17	0	0	4.0	
i 1	208.4931768707483	0.505	75	386	4	24	15	2	0	1	2	0	0	11.0	
i 1	208.50040136054423	0.2525	74	386	4	4	14	16	0	1	16	0	0	4.0	
i 1	208.51485034013606	0.505	71	386	4	5	9	8	0	-2	8	0	0	6.0	
i 1	208.5156530612245	1.5150000000000001	76	386	1	24	6	16	0	2	16	0	0	4.633524600784803	
i 1	208.51645578231293	0.7575000000000001	74	702	6	5	14	8	0	-1	8	0	0	6.0	
i 1	208.98033333333333	0.2525	71	702	6	5	1	8	0	-1	8	0	0	6.0	
i 1	208.98274149659863	0.2525	76	1088	2	20	7	17	0	2	17	0	0	0.6335246007848028	
i 1	209.00842857142857	0.2525	77	386	5	3	6	16	0	2	16	0	0	4.0	
i 1	209.01003401360543	0.2525	75	702	6	1	3	2	0	-2	2	0	0	10.0	
i 1	209.0132448979592	0.2525	74	1088	5	9	12	16	0	1	16	0	0	3.0	
i 1	209.2367551020408	0.505	74	1088	5	9	5	17	0	1	17	0	0	3.0	
i 1	209.23755782312926	1.5150000000000001	76	1088	2	24	10	17	0	2	17	0	0	4.633524600784803	
i 1	209.2520068027211	0.2525	74	386	4	5	13	2	0	-1	2	0	0	6.0	
i 1	209.26244217687074	0.505	73	702	3	20	8	16	0	2	16	0	0	0.6335246007848028	
i 1	209.2632448979592	0.2525	72	1088	3	1	5	2	0	-2	2	0	0	10.0	
i 1	209.2656530612245	0.7575000000000001	75	386	6	1	14	2	0	1	2	0	0	10.0	
i 1	209.48274149659863	0.7575000000000001	71	702	6	5	6	8	0	-1	8	0	0	6.0	
i 1	209.49157142857143	0.2525	73	702	3	20	5	16	0	2	16	0	0	0.6335246007848028	
i 1	209.49478231292517	1.5150000000000001	72	702	4	1	13	8	0	-2	8	0	0	10.0	
i 1	209.73113605442177	0.7575000000000001	76	1088	2	20	6	16	0	2	16	0	0	0.6335246007848028	
i 1	209.73996598639457	0.2525	73	1088	2	20	9	16	0	2	16	0	0	0.6335246007848028	
i 1	209.76003401360543	0.2525	71	1088	4	5	3	2	0	-1	2	0	0	6.0	
i 1	209.7680612244898	0.2525	74	386	4	4	7	16	0	1	16	0	0	4.0	
i 1	209.98113605442177	0.7575000000000001	77	386	5	3	7	16	0	2	16	0	0	4.0	
i 1	209.98916326530613	0.2525	72	386	4	24	15	8	0	1	8	0	0	11.0	
i 1	209.9931768707483	1.01	74	702	6	5	5	8	0	-1	8	0	0	6.0	
i 1	209.99959863945577	0.505	71	386	4	5	13	8	0	-2	8	0	0	6.0	
i 1	210.01003401360543	0.2525	73	386	3	20	9	16	0	2	16	0	0	0.6335246007848028	
i 1	210.2319387755102	3.2825	76	386	1	24	10	16	0	2	16	0	0	4.633524600784803	
i 1	210.23274149659863	0.7575000000000001	76	386	2	20	12	17	0	1	17	0	0	0.6335246007848028	
i 1	210.23595238095237	0.2525	71	1088	4	5	4	2	0	-2	2	0	0	6.0	
i 1	210.23755782312926	0.2525	72	1088	3	1	16	2	0	-2	2	0	0	10.0	
i 1	210.24638775510203	0.2525	75	702	6	1	12	2	0	-2	2	0	0	10.0	
i 1	210.48595238095237	9.09	61	702	6	17	8	16	0	2	16	0	0	0.5009235345346933	
i 1	210.4867551020408	2.02	75	702	4	1	14	2	0	-2	2	0	0	10.0	
i 1	210.48755782312926	10.1	61	702	5	14	14	1	0	2	1	0	0	6.513827711769258	
i 1	210.50280952380953	0.2525	71	1088	6	5	15	2	0	-2	2	0	0	6.0	
i 1	210.50842857142857	10.1	63	1088	4	18	5	1	0	2	1	0	0	0.5009235345346933	
i 1	210.5180612244898	1.7675	74	386	4	4	6	16	0	1	16	0	0	4.0	
i 1	210.73996598639457	0.2525	75	386	6	1	3	2	0	1	2	0	0	10.0	
i 1	210.74879591836734	0.2525	74	386	4	4	12	16	0	1	16	0	0	4.0	
i 1	210.76404761904763	0.7575000000000001	73	386	3	20	9	16	0	2	16	0	0	0.6335246007848028	
i 1	210.98755782312926	0.2525	76	386	3	20	8	17	0	1	17	0	0	0.6335246007848028	
i 1	210.9883605442177	0.2525	72	1088	6	1	9	2	0	-2	2	0	0	10.0	
i 1	210.99397959183673	1.7675	74	386	6	5	1	8	0	-1	8	0	0	6.0	
i 1	211.00361224489797	0.2525	74	1088	5	9	7	16	0	1	16	0	0	3.0	
i 1	211.0044149659864	0.2525	75	386	4	24	14	2	0	1	2	0	0	11.0	
i 1	211.01485034013606	0.2525	76	702	3	20	14	17	0	1	17	0	0	0.6335246007848028	
i 1	211.01886394557823	0.505	76	1088	2	24	14	17	0	2	17	0	0	4.633524600784803	
i 1	211.25842857142857	0.2525	73	1088	2	20	5	16	0	2	16	0	0	0.6335246007848028	
i 1	211.25842857142857	0.2525	76	386	2	20	16	17	0	1	17	0	0	0.6335246007848028	
i 1	211.259231292517	0.2525	73	1088	2	20	12	17	0	2	17	0	0	0.6335246007848028	
i 1	211.48595238095237	0.2525	77	702	6	2	6	17	0	1	17	0	0	4.0	
i 1	211.73595238095237	2.525	74	702	6	2	12	17	0	2	17	0	0	4.0	
i 1	211.74638775510203	1.7675	76	386	2	20	16	17	0	1	17	0	0	0.6335246007848028	
i 1	211.7479931972789	0.2525	75	1088	3	1	13	2	0	-2	2	0	0	10.0	
i 1	211.74959863945577	1.2625	72	386	4	24	14	8	0	1	8	0	0	11.0	
i 1	211.76083673469387	0.2525	73	1088	2	20	15	17	0	1	17	0	0	0.6335246007848028	
i 1	211.7656530612245	0.7575000000000001	77	386	5	3	1	16	0	2	16	0	0	4.0	
i 1	212.01645578231293	0.2525	74	386	4	5	8	2	0	-1	2	0	0	6.0	
i 1	212.2319387755102	2.02	74	386	6	5	12	8	0	-1	8	0	0	6.0	
i 1	212.24478231292517	0.2525	75	386	4	24	2	2	0	1	2	0	0	11.0	
i 1	212.2656530612245	0.2525	74	1088	5	9	8	17	0	1	17	0	0	3.0	
i 1	212.26725850340137	0.2525	76	1088	2	24	10	17	0	2	17	0	0	4.633524600784803	
i 1	212.4843469387755	0.2525	74	386	4	5	11	2	0	-1	2	0	0	6.0	
i 1	212.5020068027211	1.01	75	386	6	1	7	2	0	1	2	0	0	10.0	
i 1	212.51966666666667	0.2525	74	1088	5	9	2	16	0	1	16	0	0	3.0	
i 1	212.73274149659863	0.2525	74	702	6	5	15	8	0	-1	8	0	0	6.0	
i 1	212.76003401360543	0.2525	71	386	4	5	6	8	0	-2	8	0	0	6.0	
i 1	212.98514965986394	0.505	76	1088	2	24	4	17	0	2	17	0	0	4.633524600784803	
i 1	212.9883605442177	0.505	76	1088	2	20	11	16	0	1	16	0	0	0.6335246007848028	
i 1	213.01645578231293	0.2525	72	386	4	1	8	2	0	1	2	0	0	10.0	
i 1	213.0180612244898	0.2525	75	1088	3	1	5	2	0	-2	2	0	0	10.0	
i 1	213.2568231292517	0.2525	75	702	4	1	15	2	0	-2	2	0	0	10.0	
i 1	213.26725850340137	0.2525	73	386	1	20	11	16	0	2	16	0	0	0.6335246007848028	
i 1	213.4843469387755	1.7675	72	702	4	1	3	8	0	-2	8	0	0	10.0	
i 1	213.48514965986394	1.7675	77	702	6	2	1	17	0	1	17	0	0	4.0	
i 1	213.48514965986394	0.2525	73	702	3	20	15	16	0	1	16	0	0	0.03877098875326901	
i 1	213.48514965986394	1.5150000000000001	63	386	5	13	11	1	0	2	1	0	0	2.605531084707703	
i 1	213.49879591836734	0.505	75	386	4	1	5	2	0	1	2	0	0	10.0	
i 1	213.49959863945577	0.2525	76	1088	2	24	9	17	0	2	17	0	0	4.038770988753269	
i 1	213.5068231292517	7.07	61	386	4	19	16	16	0	1	16	0	0	0.5009235345346933	
i 1	213.509231292517	7.07	63	702	6	17	2	16	0	2	16	0	0	0.5009235345346933	
i 1	213.5132448979592	0.505	76	386	3	20	8	17	0	1	17	0	0	0.03877098875326901	
i 1	213.51485034013606	1.01	73	386	1	20	1	16	0	2	16	0	0	0.03877098875326901	
i 1	213.73354421768707	1.5150000000000001	74	702	6	5	2	8	0	-1	8	0	0	6.0	
i 1	213.75040136054423	0.2525	71	386	4	5	2	8	0	-2	8	0	0	6.0	
i 1	213.75842857142857	1.01	76	1088	1	24	3	17	0	252	17	307	0	4.038770988753269	
i 1	213.98274149659863	1.01	73	386	1	24	6	17	0	252	17	307	0	4.038770988753269	
i 1	214.00280952380953	0.2525	76	386	2	20	12	17	0	1	17	0	0	0.03877098875326901	
i 1	214.0044149659864	0.2525	72	386	3	1	10	2	0	1	2	0	0	10.0	
i 1	214.0044149659864	1.01	76	1088	2	20	7	16	0	1	16	0	0	0.03877098875326901	
i 1	214.00602040816327	0.7575000000000001	75	702	4	1	7	2	0	-2	2	0	0	10.0	
i 1	214.0068231292517	0.505	71	702	4	5	16	8	0	-1	8	0	0	6.0	
i 1	214.01966666666667	0.7575000000000001	73	1088	2	20	5	17	0	2	17	0	0	0.03877098875326901	
i 1	214.2319387755102	0.2525	77	386	5	3	12	16	0	2	16	0	0	4.0	
i 1	214.240768707483	0.7575000000000001	74	386	4	4	6	16	0	1	16	0	0	4.0	
i 1	214.26645578231293	0.2525	72	1088	6	1	16	2	0	-2	2	0	0	10.0	
i 1	214.50361224489797	0.7575000000000001	76	386	2	24	10	16	0	2	16	0	0	4.038770988753269	
i 1	214.509231292517	0.2525	74	386	6	5	5	8	0	-1	8	0	0	6.0	
i 1	214.73033333333333	0.2525	73	702	3	20	3	17	0	2	17	0	0	0.03877098875326901	
i 1	214.73996598639457	2.02	76	1088	2	24	4	17	0	2	17	0	0	4.038770988753269	
i 1	214.74638775510203	0.2525	73	702	3	20	1	17	0	1	17	0	0	0.03877098875326901	
i 1	214.75280952380953	0.2525	72	386	4	24	1	8	0	1	8	0	0	11.0	
i 1	214.759231292517	0.2525	77	386	5	3	14	16	0	2	16	0	0	4.0	
i 1	214.76485034013606	0.2525	74	386	6	5	1	8	0	-1	8	0	0	6.0	
i 1	214.98113605442177	1.5150000000000001	61	702	6	17	8	1	0	1	1	0	0	0.5009235345346933	
i 1	214.98354421768707	1.5150000000000001	71	702	4	5	1	8	0	-1	8	0	0	6.0	
i 1	214.98354421768707	0.2525	73	386	2	24	12	17	0	1	17	0	0	4.038770988753269	
i 1	214.98916326530613	11.11	61	702	5	13	4	16	0	2	16	0	0	2.605531084707703	
i 1	214.99879591836734	1.2625	77	702	5	3	5	17	0	1	17	0	0	4.0	
i 1	214.99959863945577	1.2625	75	702	4	1	8	2	0	1	2	0	0	10.0	
i 1	215.00280952380953	4.545	61	702	6	17	8	16	0	2	16	0	0	0.5009235345346933	
i 1	215.00762585034013	0.2525	76	1088	2	20	14	17	0	1	17	0	0	0.03877098875326901	
i 1	215.00762585034013	1.5150000000000001	63	702	6	7	12	16	0	2	16	0	0	5.211062169415406	
i 1	215.00842857142857	0.505	74	386	4	4	12	16	0	1	16	0	0	4.0	
i 1	215.00842857142857	0.505	71	702	6	5	13	8	0	-2	8	0	0	6.0	
i 1	215.01003401360543	0.7575000000000001	75	702	4	24	13	8	0	-2	8	0	0	11.0	
i 1	215.01003401360543	0.2525	76	1088	2	20	2	16	0	2	16	0	0	0.03877098875326901	
i 1	215.23274149659863	0.2525	74	386	4	5	6	2	0	-1	2	0	0	6.0	
i 1	215.25120408163266	0.2525	76	702	3	24	9	17	0	2	17	0	0	4.038770988753269	
i 1	215.26083673469387	0.2525	75	1088	6	1	2	2	0	-2	2	0	0	10.0	
i 1	215.26725850340137	0.2525	77	702	4	4	1	16	0	2	16	0	0	4.0	
i 1	215.26966666666667	0.7575000000000001	76	1088	2	20	12	16	0	1	16	0	0	0.03877098875326901	
i 1	215.48514965986394	1.01	74	702	6	5	10	8	0	-1	8	0	0	6.0	
i 1	215.48514965986394	0.7575000000000001	76	386	2	24	4	16	0	2	16	0	0	4.038770988753269	
i 1	215.49638775510203	0.2525	74	702	6	2	12	17	0	2	17	0	0	4.0	
i 1	215.5156530612245	0.2525	77	702	6	2	15	17	0	1	17	0	0	4.0	
i 1	215.7383605442177	2.02	72	702	4	1	12	8	0	-2	8	0	0	10.0	
i 1	215.74879591836734	0.2525	71	1088	6	5	11	2	0	-1	2	0	0	6.0	
i 1	215.7520068027211	0.2525	73	702	3	20	16	16	0	1	16	0	0	0.03877098875326901	
i 1	215.98514965986394	1.7675	74	702	6	2	16	17	0	2	17	0	0	4.0	
i 1	215.99959863945577	0.2525	75	386	4	24	13	2	0	1	2	0	0	11.0	
i 1	216.0044149659864	0.2525	74	702	6	5	9	8	0	-2	8	0	0	6.0	
i 1	216.01645578231293	0.7575000000000001	76	1088	2	20	11	16	0	2	16	0	0	0.03877098875326901	
i 1	216.2343469387755	0.2525	75	702	4	1	16	2	0	-2	2	0	0	10.0	
i 1	216.23996598639457	0.2525	72	1088	6	1	11	2	0	-2	2	0	0	10.0	
i 1	216.24638775510203	0.2525	74	386	4	5	15	2	0	-1	2	0	0	6.0	
i 1	216.4819387755102	0.7575000000000001	76	1088	2	20	15	16	0	1	16	0	0	0.03877098875326901	
i 1	216.49397959183673	4.04	61	386	4	19	1	1	0	1	1	0	0	0.5009235345346933	
i 1	216.49397959183673	0.7575000000000001	76	1088	2	20	4	16	0	1	16	0	0	0.03877098875326901	
i 1	216.49719047619047	1.7675	74	702	4	5	13	8	0	-1	8	0	0	6.0	
i 1	216.49959863945577	0.2525	75	702	4	1	1	2	0	1	2	0	0	10.0	
i 1	216.50040136054423	9.09	61	702	6	17	15	1	0	1	1	0	0	0.5009235345346933	
i 1	216.50521768707483	0.505	71	702	6	5	13	8	0	-2	8	0	0	6.0	
i 1	216.5132448979592	9.595	63	702	5	7	9	16	0	2	16	0	0	5.211062169415406	
i 1	216.51404761904763	0.505	74	386	4	4	12	16	0	1	16	0	0	4.0	
i 1	216.740768707483	0.2525	76	386	2	24	10	16	0	2	16	0	0	4.038770988753269	
i 1	216.98033333333333	1.7675	73	386	2	24	4	17	0	1	17	0	0	4.038770988753269	
i 1	216.98354421768707	0.2525	71	386	4	5	15	8	0	-2	8	0	0	6.0	
i 1	216.9843469387755	0.2525	75	702	4	24	15	8	0	-2	8	0	0	11.0	
i 1	216.98996598639457	2.2725	77	702	6	2	13	17	0	1	17	0	0	4.0	
i 1	216.9931768707483	0.2525	74	386	6	5	6	2	0	-1	2	0	0	6.0	
i 1	217.0132448979592	1.7675	73	386	2	20	4	16	0	2	16	0	0	0.03877098875326901	
i 1	217.01725850340137	0.2525	74	1088	5	9	10	16	0	1	16	0	0	3.0	
i 1	217.2383605442177	2.2725	74	702	6	5	14	8	0	-2	8	0	0	6.0	
i 1	217.24719047619047	0.505	72	1088	6	1	9	2	0	-2	2	0	0	10.0	
i 1	217.26645578231293	0.2525	72	386	6	1	13	2	0	1	2	0	0	10.0	
i 1	217.49719047619047	0.2525	76	1088	2	20	14	16	0	1	16	0	0	0.03877098875326901	
i 1	217.5020068027211	0.7575000000000001	75	702	4	1	9	2	0	-2	2	0	0	10.0	
i 1	217.73514965986394	0.2525	75	702	4	24	16	8	0	-2	8	0	0	11.0	
i 1	217.73755782312926	0.2525	72	386	6	1	13	2	0	1	2	0	0	10.0	
i 1	217.75602040816327	0.2525	74	386	6	5	7	2	0	-1	2	0	0	6.0	
i 1	217.7616394557823	0.505	74	1088	5	9	6	17	0	1	17	0	0	3.0	
i 1	217.76645578231293	0.2525	76	1088	2	20	14	16	0	2	16	0	0	0.03877098875326901	
i 1	217.99157142857143	0.2525	76	1088	2	20	8	16	0	1	16	0	0	0.03877098875326901	
i 1	217.9955850340136	1.5150000000000001	72	702	4	1	9	8	0	-2	8	0	0	10.0	
i 1	218.00762585034013	0.505	71	386	4	5	16	8	0	-2	8	0	0	6.0	
i 1	218.01244217687074	0.2525	74	386	5	3	11	17	0	1	17	0	0	4.0	
i 1	218.23113605442177	0.2525	71	702	6	5	1	8	0	-1	8	0	0	6.0	
i 1	218.24237414965987	0.2525	77	702	4	4	1	16	0	2	16	0	0	4.0	
i 1	218.2568231292517	1.01	76	1088	2	24	12	17	0	2	17	0	0	4.038770988753269	
i 1	218.26003401360543	0.7575000000000001	76	1088	2	20	11	16	0	2	16	0	0	0.03877098875326901	
i 1	218.26083673469387	0.2525	75	702	4	24	16	8	0	-2	8	0	0	11.0	
i 1	218.2616394557823	0.2525	75	702	4	1	16	2	0	1	2	0	0	10.0	
i 1	218.2680612244898	0.2525	77	702	5	3	10	17	0	1	17	0	0	4.0	
i 1	218.49397959183673	0.505	72	1088	6	1	12	2	0	-2	2	0	0	10.0	
i 1	218.50762585034013	0.2525	72	386	6	1	9	2	0	1	2	0	0	10.0	
i 1	218.51645578231293	0.505	74	702	4	5	5	8	0	-1	8	0	0	6.0	
i 1	218.73354421768707	0.2525	76	1088	2	20	6	16	0	1	16	0	0	0.03877098875326901	
i 1	218.7343469387755	0.2525	71	1088	6	5	16	2	0	-2	2	0	0	6.0	
i 1	218.74638775510203	1.2625	76	386	2	24	12	16	0	2	16	0	0	4.038770988753269	
i 1	218.7568231292517	2.02	75	702	4	1	7	2	0	1	2	0	0	10.0	
i 1	218.76645578231293	0.2525	74	702	6	2	13	17	0	2	17	0	0	4.0	
i 1	218.76645578231293	0.7575000000000001	77	702	4	4	7	16	0	2	16	0	0	4.0	
i 1	218.9819387755102	0.505	71	702	6	5	15	8	0	-2	8	0	0	6.0	
i 1	218.9931768707483	0.2525	76	702	3	20	6	17	0	1	17	0	0	0.03877098875326901	
i 1	219.0116394557823	1.7675	77	702	5	3	6	17	0	1	17	0	0	4.0	
i 1	219.0180612244898	0.505	73	702	3	20	3	17	0	2	17	0	0	0.03877098875326901	
i 1	219.23514965986394	0.505	76	1088	2	20	1	16	0	1	16	0	0	0.03877098875326901	
i 1	219.25120408163266	0.2525	72	1088	6	1	6	2	0	-2	2	0	0	10.0	
i 1	219.25762585034013	1.2625	71	702	6	5	9	8	0	-1	8	0	0	6.0	
i 1	219.2632448979592	0.2525	74	702	6	2	10	17	0	2	17	0	0	4.0	
i 1	219.4883605442177	0.2525	75	702	4	24	9	8	0	-2	8	0	0	11.0	
i 1	219.48916326530613	0.2525	74	1088	5	9	16	16	0	1	16	0	0	3.0	
i 1	219.49157142857143	1.01	61	702	6	17	8	16	0	2	16	0	0	0.5009235345346933	
i 1	219.4955850340136	0.505	72	1088	3	1	10	2	0	-2	2	0	0	10.0	
i 1	219.50280952380953	0.505	74	386	4	4	6	16	0	1	16	0	0	4.0	
i 1	219.50280952380953	0.2525	74	386	6	5	3	2	0	-1	2	0	0	6.0	
i 1	219.50521768707483	6.565	61	702	6	17	15	16	0	2	16	0	0	0.5009235345346933	
i 1	219.5116394557823	0.2525	73	1088	2	20	2	16	0	1	16	0	0	0.03877098875326901	
i 1	219.51725850340137	0.505	71	702	4	5	14	8	0	-2	8	0	0	6.0	
i 1	219.73595238095237	0.2525	77	702	6	2	6	17	0	1	17	0	0	4.0	
i 1	219.73595238095237	0.2525	73	702	3	20	16	17	0	2	17	0	0	0.03877098875326901	
i 1	219.7520068027211	0.2525	73	702	3	20	12	17	0	1	17	0	0	0.03877098875326901	
i 1	219.99638775510203	0.505	73	1088	2	20	9	17	0	2	17	0	0	0.03877098875326901	
i 1	220.00120408163266	0.2525	71	386	6	5	8	8	0	-2	8	0	0	6.0	
i 1	220.01244217687074	0.505	77	702	4	4	15	16	0	2	16	0	0	4.0	
i 1	220.0180612244898	0.505	76	1088	2	24	9	17	0	2	17	0	0	4.038770988753269	
i 1	220.23113605442177	0.2525	75	702	4	1	9	2	0	-2	2	0	0	10.0	
i 1	220.23113605442177	0.2525	72	1088	3	1	4	2	0	-2	2	0	0	10.0	
i 1	220.2455850340136	0.7575000000000001	74	702	6	5	8	8	0	-2	8	0	0	6.0	
i 1	220.26886394557823	0.2525	77	702	6	2	4	17	0	1	17	0	0	4.0	
i 1	220.4819387755102	1.7675	73	204	3	20	8	16	0	2	16	0	0	0.03877098875326901	
i 1	220.48274149659863	1.01	77	204	6	9	5	17	0	2	17	0	0	3.0	
i 1	220.48354421768707	12.625	63	906	5	14	1	1	0	1	1	0	0	6.513827711769258	
i 1	220.48514965986394	11.11	61	906	6	17	3	1	0	1	1	0	0	0.5009235345346933	
i 1	220.48595238095237	0.2525	73	204	3	24	9	17	0	1	17	0	0	4.038770988753269	
i 1	220.490768707483	0.7575000000000001	72	906	4	1	8	2	0	-2	2	0	0	10.0	
i 1	220.4979931972789	11.11	61	204	5	19	7	1	0	2	1	0	0	0.5009235345346933	
i 1	220.49879591836734	0.2525	71	906	6	5	13	8	0	-1	8	0	0	6.0	
i 1	220.49959863945577	2.02	61	204	5	18	2	1	0	2	1	0	0	0.5009235345346933	
i 1	220.49959863945577	5.05	63	204	5	18	4	16	0	2	16	0	0	0.5009235345346933	
i 1	220.5020068027211	12.625	61	906	5	14	8	16	0	2	16	0	0	6.513827711769258	
i 1	220.50280952380953	2.02	63	906	6	17	16	1	0	1	1	0	0	0.5009235345346933	
i 1	220.5044149659864	1.7675	73	204	2	24	14	17	0	1	17	0	0	4.038770988753269	
i 1	220.5068231292517	1.2625	75	702	4	24	8	8	0	-2	8	0	0	11.0	
i 1	220.51003401360543	0.505	73	204	3	20	12	17	0	2	17	0	0	0.03877098875326901	
i 1	220.51485034013606	1.7675	77	906	6	2	11	16	0	2	16	0	0	4.0	
i 1	220.5156530612245	1.5150000000000001	71	702	4	5	5	8	0	-2	8	0	0	6.0	
i 1	220.51966666666667	8.08	61	204	5	19	11	16	0	2	16	0	0	0.5009235345346933	
i 1	220.74397959183673	0.2525	74	204	7	5	1	8	0	-2	8	0	0	6.0	
i 1	220.98996598639457	0.2525	76	204	3	20	13	16	0	1	16	0	0	0.03877098875326901	
i 1	220.9955850340136	0.2525	75	204	7	1	9	2	0	-2	2	0	0	10.0	
i 1	221.23354421768707	0.2525	72	906	4	1	13	2	0	1	2	0	0	10.0	
i 1	221.24959863945577	0.2525	73	204	2	24	3	17	0	2	17	0	0	4.038770988753269	
i 1	221.25602040816327	0.2525	74	204	5	4	9	17	0	2	17	0	0	4.0	
i 1	221.25762585034013	2.02	75	702	4	1	12	2	0	1	2	0	0	10.0	
i 1	221.48113605442177	0.2525	73	204	3	20	16	17	0	2	17	0	0	0.03877098875326901	
i 1	221.48996598639457	0.2525	71	204	7	5	14	2	0	-1	2	0	0	6.0	
i 1	221.49719047619047	2.02	77	702	4	4	11	16	0	2	16	0	0	4.0	
i 1	221.49879591836734	0.2525	74	702	6	5	6	8	0	-2	8	0	0	6.0	
i 1	221.7383605442177	1.7675	71	906	6	5	7	8	0	-1	8	0	0	6.0	
i 1	221.74478231292517	0.7575000000000001	72	906	4	1	3	2	0	-2	2	0	0	10.0	
i 1	221.76645578231293	0.2525	74	204	6	9	7	17	0	1	17	0	0	3.0	
i 1	221.7680612244898	0.7575000000000001	73	204	2	20	2	17	0	2	17	0	0	0.03877098875326901	
i 1	221.76886394557823	0.7575000000000001	76	204	2	20	5	17	0	1	17	0	0	0.03877098875326901	
i 1	221.9931768707483	0.505	74	702	6	5	15	8	0	-2	8	0	0	6.0	
i 1	221.9979931972789	0.505	74	204	5	4	3	17	0	2	17	0	0	4.0	
i 1	222.01244217687074	0.2525	71	204	7	5	10	2	0	-1	2	0	0	6.0	
i 1	222.25120408163266	0.2525	73	204	2	24	10	17	0	2	17	0	0	4.038770988753269	
i 1	222.2616394557823	0.2525	74	204	6	9	3	17	0	1	17	0	0	3.0	
i 1	222.2680612244898	0.2525	71	204	7	5	5	8	0	-1	8	0	0	6.0	
i 1	222.48113605442177	0.2525	77	906	6	2	6	16	0	2	16	0	0	4.0	
i 1	222.4819387755102	10.605	63	906	6	17	16	1	0	1	1	0	0	0.5009235345346933	
i 1	222.509231292517	0.2525	75	702	4	24	2	8	0	-2	8	0	0	11.0	
i 1	222.51083673469387	0.2525	72	204	7	1	11	2	0	1	2	0	0	10.0	
i 1	222.5132448979592	9.09	61	204	5	18	12	1	0	2	1	0	0	0.5009235345346933	
i 1	222.74638775510203	2.02	77	702	5	3	6	17	0	1	17	0	0	4.0	
i 1	222.7544149659864	1.2625	72	906	4	1	1	2	0	1	2	0	0	10.0	
i 1	222.75842857142857	0.2525	74	204	5	4	7	17	0	2	17	0	0	4.0	
i 1	222.98514965986394	0.2525	71	204	7	5	2	2	0	-1	2	0	0	6.0	
i 1	222.99879591836734	0.2525	72	204	4	1	6	2	0	-2	2	0	0	10.0	
i 1	223.00040136054423	2.02	74	906	6	5	11	2	0	-1	2	0	0	6.0	
i 1	223.00120408163266	0.2525	73	204	3	24	9	17	0	1	17	0	0	4.0	
i 1	223.23033333333333	1.7675	72	906	4	1	2	2	0	-2	2	0	0	10.0	
i 1	223.23916326530613	0.2525	75	204	4	1	13	2	0	-2	2	0	0	10.0	
i 1	223.25762585034013	0.505	74	204	7	5	11	8	0	-2	8	0	0	6.0	
i 1	223.26244217687074	0.2525	74	204	6	9	8	17	0	1	17	0	0	3.0	
i 1	223.50361224489797	0.505	71	204	7	5	10	2	0	-1	2	0	0	6.0	
i 1	223.5132448979592	0.2525	74	906	6	2	14	16	0	2	16	0	0	4.0	
i 1	223.7520068027211	0.505	73	204	1	24	11	17	0	252	17	307	0	4.0	
i 1	223.7632448979592	0.2525	71	204	7	5	5	8	0	-2	8	0	0	6.0	
i 1	223.98113605442177	0.2525	74	204	7	5	13	8	0	-2	8	0	0	6.0	
i 1	223.99157142857143	0.505	72	204	5	24	5	8	0	-2	8	0	0	11.0	
i 1	224.0020068027211	0.505	71	906	6	5	15	8	0	-1	8	0	0	6.0	
i 1	224.01244217687074	3.2825	73	204	2	24	5	17	0	1	17	0	0	4.0	
i 1	224.23274149659863	0.7575000000000001	73	204	3	24	14	17	0	1	17	0	0	4.0	
i 1	224.25040136054423	0.2525	74	204	6	9	16	17	0	1	17	0	0	3.0	
i 1	224.25521768707483	2.02	74	906	6	2	6	16	0	2	16	0	0	4.0	
i 1	224.48354421768707	1.01	72	906	4	1	16	2	0	1	2	0	0	10.0	
i 1	224.49959863945577	0.505	77	906	6	2	11	16	0	2	16	0	0	4.0	
i 1	224.50762585034013	0.2525	71	204	7	5	15	8	0	-1	8	0	0	6.0	
i 1	224.51966666666667	0.7575000000000001	74	702	4	5	13	8	0	-2	8	0	0	6.0	
i 1	224.740768707483	0.2525	74	204	5	4	10	17	0	2	17	0	0	4.0	
i 1	224.7568231292517	1.2625	71	702	6	5	5	8	0	-2	8	0	0	6.0	
i 1	224.99397959183673	0.2525	74	204	6	9	7	17	0	1	17	0	0	3.0	
i 1	225.0068231292517	0.2525	71	204	7	5	7	8	0	-1	8	0	0	6.0	
i 1	225.009231292517	0.505	75	702	4	24	11	8	0	-2	8	0	0	11.0	
i 1	225.0132448979592	0.2525	75	702	4	1	9	2	0	1	2	0	0	10.0	
i 1	225.01485034013606	0.2525	77	702	4	4	6	16	0	2	16	0	0	4.0	
i 1	225.2383605442177	0.2525	71	906	6	5	2	8	0	-1	8	0	0	6.0	
i 1	225.2383605442177	0.2525	74	204	7	5	4	8	0	-2	8	0	0	6.0	
i 1	225.24478231292517	0.505	72	204	4	1	14	2	0	-2	2	0	0	10.0	
i 1	225.26966666666667	0.505	74	204	5	4	1	17	0	2	17	0	0	4.0	
i 1	225.4819387755102	1.01	74	906	6	5	5	2	0	-1	2	0	0	6.0	
i 1	225.4867551020408	1.01	72	906	5	1	13	2	0	1	2	0	0	10.0	
i 1	225.48996598639457	0.505	61	702	6	17	16	1	0	1	1	0	0	0.5009235345346933	
i 1	225.5020068027211	9.09	63	204	5	18	1	16	0	2	16	0	0	0.5009235345346933	
i 1	225.50602040816327	0.2525	72	204	3	1	10	2	0	1	2	0	0	10.0	
i 1	225.74478231292517	0.2525	77	702	4	4	5	16	0	2	16	0	0	4.0	
i 1	225.7479931972789	0.2525	75	204	4	1	15	2	0	-2	2	0	0	10.0	
i 1	225.75842857142857	0.505	72	204	5	24	15	8	0	-2	8	0	0	11.0	
i 1	225.7680612244898	0.2525	74	204	6	9	10	17	0	1	17	0	0	3.0	
i 1	225.7680612244898	0.2525	71	204	7	5	15	8	0	-1	8	0	0	6.0	
i 1	225.98113605442177	2.525	63	590	6	17	14	1	0	2	1	0	0	0.5009235345346933	
i 1	225.98354421768707	1.2625	72	906	4	1	1	2	0	-2	2	0	0	10.0	
i 1	225.9867551020408	2.2725	77	906	6	2	16	16	0	2	16	0	0	4.0	
i 1	225.99397959183673	0.7575000000000001	74	590	6	5	11	8	0	-1	8	0	0	6.0	
i 1	225.99397959183673	7.07	61	590	5	13	10	16	0	1	16	0	0	2.605531084707703	
i 1	225.9979931972789	1.5150000000000001	74	590	6	5	6	8	0	-2	8	0	0	6.0	
i 1	226.00040136054423	0.7575000000000001	74	590	4	4	3	16	0	2	16	0	0	4.0	
i 1	226.00361224489797	7.07	61	590	5	7	8	1	0	1	1	0	0	5.211062169415406	
i 1	226.00602040816327	7.07	63	590	6	17	6	1	0	1	1	0	0	0.5009235345346933	
i 1	226.23514965986394	0.2525	74	204	5	4	5	17	0	2	17	0	0	4.0	
i 1	226.25120408163266	0.505	75	204	4	1	12	2	0	-2	2	0	0	10.0	
i 1	226.49157142857143	0.505	71	204	7	5	7	8	0	-2	8	0	0	6.0	
i 1	226.49237414965987	0.2525	74	204	6	9	10	17	0	1	17	0	0	3.0	
i 1	226.51404761904763	0.2525	72	204	4	1	4	2	0	-2	2	0	0	10.0	
i 1	226.74157142857143	2.02	75	590	4	24	9	2	0	-2	2	0	0	11.0	
i 1	226.75120408163266	0.2525	71	204	7	5	16	2	0	-1	2	0	0	6.0	
i 1	226.75521768707483	3.0300000000000002	76	204	2	24	6	17	0	1	17	0	0	4.0	
i 1	226.76003401360543	0.2525	72	906	5	1	2	2	0	1	2	0	0	10.0	
i 1	226.76244217687074	0.505	74	906	6	2	16	16	0	2	16	0	0	4.0	
i 1	226.7680612244898	3.0300000000000002	73	204	3	24	4	17	0	1	17	0	0	4.0	
i 1	226.98595238095237	2.02	74	590	6	5	5	8	0	-1	8	0	0	6.0	
i 1	226.99237414965987	0.2525	74	906	6	5	1	2	0	-1	2	0	0	6.0	
i 1	227.00762585034013	0.505	72	590	4	1	12	2	0	-2	2	0	0	10.0	
i 1	227.2520068027211	0.505	72	906	5	1	4	2	0	1	2	0	0	10.0	
i 1	227.48113605442177	0.2525	71	204	7	5	6	8	0	-1	8	0	0	6.0	
i 1	227.49879591836734	0.2525	74	204	4	5	12	8	0	-2	8	0	0	6.0	
i 1	227.51083673469387	0.505	72	204	3	1	4	2	0	1	2	0	0	10.0	
i 1	227.51725850340137	2.02	74	906	6	2	15	16	0	2	16	0	0	4.0	
i 1	227.51886394557823	0.2525	74	204	5	4	10	17	0	2	17	0	0	4.0	
i 1	227.73033333333333	0.505	71	204	7	5	6	8	0	-2	8	0	0	6.0	
i 1	227.7367551020408	0.7575000000000001	71	204	7	5	12	2	0	-1	2	0	0	6.0	
i 1	227.75280952380953	0.2525	75	204	4	1	15	2	0	-2	2	0	0	10.0	
i 1	227.7680612244898	0.7575000000000001	74	590	4	4	14	16	0	2	16	0	0	4.0	
i 1	227.99879591836734	1.7675	72	590	4	1	6	2	0	-2	2	0	0	10.0	
i 1	228.0156530612245	0.2525	72	906	5	1	13	2	0	1	2	0	0	10.0	
i 1	228.2383605442177	0.2525	71	204	7	5	9	8	0	-1	8	0	0	6.0	
i 1	228.25521768707483	0.2525	72	204	5	24	12	8	0	-2	8	0	0	11.0	
i 1	228.26404761904763	1.01	74	590	5	3	14	17	0	1	17	0	0	4.0	
i 1	228.50521768707483	0.505	72	204	3	24	14	8	0	-2	8	0	0	11.0	
i 1	228.50602040816327	4.545	71	906	6	5	11	8	0	-1	8	0	0	6.0	
i 1	228.5068231292517	0.505	74	204	6	9	10	17	0	1	17	0	0	3.0	
i 1	228.51485034013606	0.2525	74	590	6	5	10	8	0	-2	8	0	0	6.0	
i 1	228.5156530612245	4.545	63	590	6	17	10	1	0	2	1	0	0	0.5009235345346933	
i 1	228.51645578231293	4.545	61	204	5	19	2	16	0	2	16	0	0	0.5009235345346933	
i 1	228.73354421768707	1.01	72	906	5	1	10	2	0	-2	2	0	0	10.0	
i 1	228.76404761904763	0.505	71	204	7	5	15	2	0	-1	2	0	0	6.0	
i 1	228.9843469387755	0.2525	71	204	7	5	5	8	0	-2	8	0	0	6.0	
i 1	228.98916326530613	1.5150000000000001	77	906	6	2	4	16	0	2	16	0	0	4.0	
i 1	228.99478231292517	1.7675	72	906	5	1	7	2	0	1	2	0	0	10.0	
i 1	229.2367551020408	0.505	74	590	6	5	1	8	0	-1	8	0	0	6.0	
i 1	229.2479931972789	0.7575000000000001	74	204	5	4	9	17	0	2	17	0	0	4.0	
i 1	229.25842857142857	0.2525	74	204	7	5	15	8	0	-2	8	0	0	6.0	
i 1	229.48033333333333	2.02	73	204	2	24	9	17	0	1	17	0	0	4.0	
i 1	229.51725850340137	0.2525	74	590	4	4	12	16	0	2	16	0	0	4.0	
i 1	229.73755782312926	1.01	74	906	6	5	10	2	0	-1	2	0	0	6.0	
i 1	229.7479931972789	0.2525	72	204	4	1	16	2	0	-2	2	0	0	10.0	
i 1	229.759231292517	0.2525	72	204	3	1	16	2	0	1	2	0	0	10.0	
i 1	229.7656530612245	0.2525	74	204	6	3	16	17	0	1	17	0	0	4.0	
i 1	229.76966666666667	0.7575000000000001	76	204	1	24	16	17	0	248	17	308	0	4.0	
i 1	229.98113605442177	2.02	74	590	4	4	10	16	0	2	16	0	0	4.0	
i 1	229.99397959183673	2.525	72	906	5	1	6	2	0	-2	2	0	0	10.0	
i 1	230.0180612244898	0.2525	72	204	3	24	6	8	0	-2	8	0	0	11.0	
i 1	230.25521768707483	0.2525	74	590	6	5	5	8	0	-2	8	0	0	6.0	
i 1	230.4931768707483	0.2525	72	204	3	1	14	2	0	1	2	0	0	10.0	
i 1	230.50280952380953	0.2525	76	204	2	24	13	17	0	1	17	0	0	4.0	
i 1	230.51725850340137	0.7575000000000001	77	204	6	9	5	17	0	2	17	0	0	3.0	
i 1	230.51886394557823	0.505	74	204	7	5	4	8	0	-2	8	0	0	6.0	
i 1	230.73033333333333	0.505	71	204	4	5	4	8	0	-1	8	0	0	6.0	
i 1	230.7367551020408	0.2525	75	204	4	1	9	2	0	-2	2	0	0	10.0	
i 1	230.73755782312926	0.2525	72	204	4	1	2	2	0	-2	2	0	0	10.0	
i 1	230.9955850340136	4.04	73	204	3	24	12	17	0	1	17	0	0	4.0	
i 1	231.0116394557823	0.2525	74	590	6	5	3	8	0	-1	8	0	0	6.0	
i 1	231.23595238095237	0.2525	72	204	3	24	10	8	0	-2	8	0	0	11.0	
i 1	231.2455850340136	0.2525	75	204	4	1	5	2	0	-2	2	0	0	10.0	
i 1	231.26083673469387	0.2525	76	590	3	24	8	17	0	1	17	0	0	4.0	
i 1	231.26404761904763	0.2525	74	590	6	5	15	8	0	-2	8	0	0	6.0	
i 1	231.26966666666667	1.7675	74	590	5	3	10	17	0	1	17	0	0	4.0	
i 1	231.26966666666667	0.2525	71	204	7	5	12	2	0	-1	2	0	0	6.0	
i 1	231.4979931972789	1.01	74	590	6	5	8	8	0	-1	8	0	0	6.0	
i 1	231.50040136054423	1.5150000000000001	61	204	5	19	8	1	0	2	1	0	0	0.5009235345346933	
i 1	231.5020068027211	9.09	61	204	5	18	3	1	0	2	1	0	0	0.5009235345346933	
i 1	231.50762585034013	1.01	73	204	2	24	6	17	0	1	17	0	0	4.0	
i 1	231.5132448979592	0.7575000000000001	72	906	5	1	10	2	0	1	2	0	0	10.0	
i 1	231.5132448979592	1.5150000000000001	72	590	5	1	12	2	0	-2	2	0	0	10.0	
i 1	231.7632448979592	0.2525	74	204	7	5	4	8	0	-2	8	0	0	6.0	
i 1	232.00120408163266	0.7575000000000001	71	204	7	5	2	2	0	-1	2	0	0	6.0	
i 1	232.24959863945577	0.2525	72	204	3	24	13	8	0	-2	8	0	0	11.0	
i 1	232.4883605442177	0.2525	76	590	3	24	1	16	0	1	16	0	0	4.0	
i 1	232.49157142857143	0.2525	74	906	6	5	11	2	0	-1	2	0	0	6.0	
i 1	232.49478231292517	0.2525	72	204	3	1	16	2	0	1	2	0	0	10.0	
i 1	232.51083673469387	0.505	72	906	5	1	5	2	0	1	2	0	0	10.0	
i 1	232.51485034013606	0.505	73	204	2	24	12	17	0	1	17	0	0	4.0	
i 1	232.74879591836734	0.2525	74	590	6	5	3	8	0	-2	8	0	0	6.0	
i 1	232.75280952380953	0.7575000000000001	74	204	7	5	3	8	0	-2	8	0	0	6.0	
i 1	232.98033333333333	5.555	63	702	5	7	2	1	0	2	1	0	0	5.211062169415406	
i 1	232.9819387755102	5.555	63	702	6	17	15	16	0	1	16	0	0	0.5009235345346933	
i 1	232.9819387755102	2.02	71	702	6	5	11	8	0	-1	8	0	0	6.0	
i 1	232.98274149659863	0.2525	74	1088	6	5	3	8	0	-2	8	0	0	6.0	
i 1	232.990768707483	5.555	61	702	5	13	11	16	0	1	16	0	0	2.605531084707703	
i 1	232.99157142857143	4.545	63	702	4	19	14	16	0	1	16	0	0	0.5009235345346933	
i 1	232.99157142857143	7.575	63	1088	5	14	15	1	0	1	1	0	0	6.513827711769258	
i 1	232.9931768707483	7.575	61	702	4	19	5	1	0	2	1	0	0	0.5009235345346933	
i 1	232.99719047619047	1.5150000000000001	61	1088	6	17	14	16	0	2	16	0	0	0.5009235345346933	
i 1	232.9979931972789	1.01	72	702	4	24	11	2	0	-2	2	0	0	11.0	
i 1	232.99879591836734	0.7575000000000001	77	1088	6	2	2	16	0	1	16	0	0	4.0	
i 1	233.0044149659864	0.505	72	204	4	1	3	2	0	-2	2	0	0	10.0	
i 1	233.00602040816327	2.02	74	702	4	4	2	16	0	2	16	0	0	4.0	
i 1	233.00602040816327	7.575	61	1088	5	14	8	16	0	2	16	0	0	6.513827711769258	
i 1	233.01003401360543	4.545	61	702	6	17	15	1	0	1	1	0	0	0.5009235345346933	
i 1	233.01886394557823	0.2525	73	702	2	24	16	17	0	2	17	0	0	4.0	
i 1	233.49879591836734	0.505	74	702	6	5	3	2	0	-2	2	0	0	6.0	
i 1	233.51083673469387	2.2725	72	702	5	1	15	8	0	-2	8	0	0	10.0	
i 1	233.51645578231293	0.2525	71	204	7	5	8	8	0	-1	8	0	0	6.0	
i 1	233.76966666666667	0.505	74	702	6	5	11	8	0	-2	8	0	0	6.0	
i 1	234.0020068027211	0.2525	74	1088	6	5	6	8	0	-1	8	0	0	6.0	
i 1	234.0116394557823	0.505	75	204	4	1	8	2	0	-2	2	0	0	10.0	
i 1	234.23113605442177	0.2525	74	1088	6	5	16	8	0	-2	8	0	0	6.0	
i 1	234.26003401360543	2.02	74	702	6	5	11	2	0	-2	2	0	0	6.0	
i 1	234.50040136054423	1.2625	73	702	2	24	4	17	0	2	17	0	0	4.0	
i 1	234.50842857142857	0.2525	75	702	3	24	12	2	0	1	2	0	0	11.0	
i 1	234.51083673469387	2.02	77	1088	6	2	8	16	0	1	16	0	0	4.0	
i 1	234.51645578231293	3.0300000000000002	75	1088	5	1	6	2	0	-2	2	0	0	10.0	
i 1	234.51645578231293	6.0600000000000005	63	204	5	18	4	16	0	2	16	0	0	0.5009235345346933	
i 1	234.7343469387755	0.2525	71	702	6	5	6	8	0	-1	8	0	0	6.0	
i 1	234.74237414965987	0.505	75	1088	5	1	16	2	0	1	2	0	0	10.0	
i 1	234.99638775510203	0.505	74	702	3	5	7	8	0	-2	8	0	0	6.0	
i 1	235.00762585034013	0.2525	77	702	5	3	7	17	0	1	17	0	0	4.0	
i 1	235.01003401360543	0.505	74	204	6	9	9	17	0	1	17	0	0	3.0	
i 1	235.01003401360543	0.505	71	204	7	5	10	8	0	-1	8	0	0	6.0	
i 1	235.2319387755102	4.04	73	204	3	24	14	17	0	1	17	0	0	4.0	
i 1	235.2367551020408	0.2525	75	204	4	1	8	2	0	-2	2	0	0	10.0	
i 1	235.4883605442177	2.02	74	1088	6	5	3	8	0	-1	8	0	0	6.0	
i 1	235.50361224489797	0.2525	75	702	3	24	1	2	0	1	2	0	0	11.0	
i 1	235.5068231292517	0.2525	77	204	6	9	6	17	0	2	17	0	0	3.0	
i 1	235.50762585034013	0.2525	74	204	7	5	9	8	0	-2	8	0	0	6.0	
i 1	235.5180612244898	0.505	74	702	4	4	10	16	0	2	16	0	0	4.0	
i 1	235.73033333333333	0.7575000000000001	74	1088	6	5	15	8	0	-2	8	0	0	6.0	
i 1	235.7632448979592	0.505	74	702	5	3	4	16	0	1	16	0	0	4.0	
i 1	235.98274149659863	0.7575000000000001	75	1088	5	1	15	2	0	1	2	0	0	10.0	
i 1	235.98916326530613	0.2525	73	702	2	24	5	17	0	2	17	0	0	4.0	
i 1	236.01003401360543	1.5150000000000001	74	1088	6	2	15	17	0	2	17	0	0	4.0	
i 1	236.23996598639457	0.2525	77	702	4	4	9	16	0	2	16	0	0	4.0	
i 1	236.23996598639457	0.7575000000000001	71	204	7	5	12	8	0	-1	8	0	0	6.0	
i 1	236.49157142857143	0.2525	77	702	5	3	11	17	0	1	17	0	0	4.0	
i 1	236.49397959183673	0.2525	74	702	3	5	11	8	0	-2	8	0	0	6.0	
i 1	236.4955850340136	0.2525	77	204	6	9	10	17	0	2	17	0	0	3.0	
i 1	236.74397959183673	0.505	71	702	6	5	3	8	0	-1	8	0	0	6.0	
i 1	236.75762585034013	1.7675	72	702	5	1	1	8	0	-2	8	0	0	10.0	
i 1	236.99237414965987	2.02	77	1088	6	2	1	16	0	1	16	0	0	4.0	
i 1	236.99719047619047	0.2525	74	702	3	5	2	8	0	-2	8	0	0	6.0	
i 1	237.23113605442177	0.7575000000000001	73	702	2	24	3	17	0	2	17	0	0	4.0	
i 1	237.2680612244898	1.2625	74	702	6	5	12	2	0	-2	2	0	0	6.0	
i 1	237.26886394557823	0.2525	71	204	7	5	10	8	0	-1	8	0	0	6.0	
i 1	237.48113605442177	0.7575000000000001	74	1088	6	5	7	8	0	-2	8	0	0	6.0	
i 1	237.50521768707483	0.505	74	1088	6	5	6	8	0	-1	8	0	0	6.0	
i 1	237.5156530612245	3.0300000000000002	63	702	4	19	10	16	0	1	16	0	0	0.5009235345346933	
i 1	237.76485034013606	0.505	77	702	5	3	13	17	0	1	17	0	0	4.0	
i 1	237.98595238095237	0.2525	75	1088	5	1	14	2	0	-2	2	0	0	10.0	
i 1	237.98996598639457	0.2525	74	204	7	5	13	8	0	-2	8	0	0	6.0	
i 1	237.99478231292517	0.505	72	204	5	1	15	2	0	-2	2	0	0	10.0	
i 1	238.01886394557823	0.2525	73	702	2	24	7	16	0	2	16	0	0	4.0	
i 1	238.23274149659863	2.02	74	1088	6	5	10	8	0	-1	8	0	0	6.0	
i 1	238.2544149659864	0.2525	73	702	3	24	14	16	0	2	16	0	0	4.0	
i 1	238.2568231292517	0.2525	71	702	6	5	11	8	0	-1	8	0	0	6.0	
i 1	238.25842857142857	1.2625	75	1088	5	1	11	2	0	1	2	0	0	10.0	
i 1	238.48113605442177	2.02	63	590	5	13	1	1	0	2	1	0	0	2.605531084707703	
i 1	238.4883605442177	2.02	61	590	6	17	15	16	0	1	16	0	0	0.5009235345346933	
i 1	238.48996598639457	0.505	75	702	3	24	3	2	0	1	2	0	0	11.0	
i 1	238.50040136054423	1.7675	74	590	5	3	4	17	0	1	17	0	0	4.0	
i 1	238.50842857142857	0.505	71	590	6	5	4	2	0	-1	2	0	0	6.0	
i 1	238.50842857142857	2.02	63	590	5	7	15	16	0	2	16	0	0	5.211062169415406	
i 1	238.5116394557823	0.2525	75	590	5	1	14	2	0	1	2	0	0	10.0	
i 1	238.7319387755102	1.7675	75	590	4	24	3	2	0	-2	2	0	0	11.0	
i 1	238.76485034013606	0.7575000000000001	73	702	2	24	14	17	0	2	17	0	0	4.0	
i 1	239.0068231292517	0.2525	75	702	3	1	9	2	0	-2	2	0	0	10.0	
i 1	239.0068231292517	0.2525	76	590	3	24	7	17	0	1	17	0	0	4.0	
i 1	239.00842857142857	0.2525	77	702	4	4	11	16	0	2	16	0	0	4.0	
i 1	239.01244217687074	0.7575000000000001	74	204	6	9	9	17	0	1	17	0	0	3.0	
i 1	239.23113605442177	0.2525	72	204	5	1	16	2	0	-2	2	0	0	10.0	
i 1	239.2383605442177	1.01	73	702	2	24	6	16	0	2	16	0	0	4.0	
i 1	239.24879591836734	0.505	77	204	6	9	9	17	0	2	17	0	0	3.0	
i 1	239.49478231292517	0.505	75	702	3	1	3	2	0	-2	2	0	0	10.0	
i 1	239.50040136054423	0.2525	75	590	5	1	11	2	0	1	2	0	0	10.0	
i 1	239.5044149659864	0.505	71	702	6	5	3	8	0	-1	8	0	0	6.0	
i 1	239.51003401360543	0.2525	71	204	7	5	14	8	0	-1	8	0	0	6.0	
i 1	239.73514965986394	0.7575000000000001	74	1088	6	2	3	17	0	2	17	0	0	4.0	
i 1	239.74478231292517	0.2525	77	702	4	4	3	16	0	2	16	0	0	4.0	
i 1	239.74478231292517	0.7575000000000001	71	590	6	5	15	2	0	-1	2	0	0	6.0	
i 1	239.75521768707483	0.505	75	1088	5	1	11	2	0	1	2	0	0	10.0	
i 1	239.99879591836734	0.505	75	590	5	1	14	2	0	1	2	0	0	10.0	
i 1	240.00280952380953	3.0300000000000002	77	1088	6	2	14	16	0	1	16	0	0	4.0	
i 1	240.0156530612245	0.505	71	590	6	5	2	2	0	-1	2	0	0	6.0	
i 1	240.23033333333333	0.2525	74	702	6	5	12	8	0	-2	8	0	0	6.0	
i 1	240.23113605442177	0.2525	75	702	3	24	12	2	0	1	2	0	0	11.0	
i 1	240.26645578231293	0.2525	77	204	6	9	11	17	0	2	17	0	0	3.0	
i 1	240.26886394557823	1.01	73	702	2	24	14	17	0	2	17	0	0	4.0	
i 1	240.48354421768707	5.05	63	1088	5	25	3	16	0	1	16	0	0	0.39147284124284637	
i 1	240.48996598639457	0.505	74	590	4	4	8	16	0	1	16	0	0	4.0	
i 1	240.49157142857143	0.505	74	590	5	3	8	17	0	1	17	0	0	4.0	
i 1	240.49157142857143	0.7575000000000001	71	590	6	5	14	2	0	-1	2	0	0	9.948905943535717	
i 1	240.4931768707483	0.7575000000000001	61	590	5	25	12	1	0	2	1	0	0	0.39147284124284637	
i 1	240.49478231292517	6.0600000000000005	63	204	5	18	16	16	0	2	16	0	0	3.506464741742853	
i 1	240.4955850340136	0.505	75	1088	5	1	14	2	0	-2	2	0	0	7.794557119032869	
i 1	240.49638775510203	0.7575000000000001	75	590	5	1	9	2	0	1	2	0	0	7.794557119032869	
i 1	240.49638775510203	0.2525	75	590	4	24	4	2	0	-2	2	0	0	8.79455711903287	
i 1	240.49879591836734	5.05	63	1088	5	25	5	16	0	2	16	0	0	0.39147284124284637	
i 1	240.49959863945577	5.05	61	702	4	19	9	1	0	2	1	0	0	3.506464741742853	
i 1	240.50040136054423	10.605	63	204	5	26	10	1	0	1	1	0	0	0.39147284124284637	
i 1	240.5020068027211	5.05	63	702	4	19	12	16	0	1	16	0	0	3.506464741742853	
i 1	240.50280952380953	3.0300000000000002	61	204	5	18	9	1	0	2	1	0	0	3.506464741742853	
i 1	240.50361224489797	0.505	74	702	6	5	9	8	0	-2	8	0	0	9.948905943535717	
i 1	240.5068231292517	10.605	61	204	5	26	9	16	0	2	16	0	0	0.39147284124284637	
i 1	240.51485034013606	0.7575000000000001	63	590	5	25	3	1	0	1	1	0	0	0.39147284124284637	
i 1	240.5180612244898	0.2525	74	204	7	5	2	8	0	-2	8	0	0	9.948905943535717	
i 1	240.74959863945577	0.505	75	204	5	1	2	2	0	-2	2	0	0	7.794557119032869	
i 1	240.7656530612245	2.02	73	204	3	24	2	17	0	1	17	0	0	4.0	
i 1	240.98996598639457	0.505	74	1088	6	5	1	8	0	-2	8	0	0	9.948905943535717	
i 1	240.9931768707483	0.2525	71	702	6	5	7	8	0	-1	8	0	0	9.948905943535717	
i 1	241.00762585034013	0.505	75	702	3	24	3	2	0	1	2	0	0	8.79455711903287	
i 1	241.0156530612245	0.2525	77	702	5	3	9	17	0	1	17	0	0	4.0	
i 1	241.01886394557823	0.2525	74	204	6	9	16	17	0	1	17	0	0	3.0	
i 1	241.23033333333333	4.2925	61	386	5	25	1	1	0	2	1	0	0	0.39147284124284637	
i 1	241.2319387755102	0.505	71	386	6	5	5	2	0	-2	2	0	0	9.948905943535717	
i 1	241.23274149659863	0.2525	77	386	5	3	1	17	0	2	17	0	0	4.0	
i 1	241.23354421768707	2.02	74	1088	6	5	4	8	0	-1	8	0	0	9.948905943535717	
i 1	241.2343469387755	4.2925	61	386	5	25	3	16	0	1	16	0	0	0.39147284124284637	
i 1	241.23595238095237	3.535	75	1088	5	1	9	2	0	-2	2	0	0	7.794557119032869	
i 1	241.24237414965987	0.505	75	386	5	1	15	2	0	-2	2	0	0	7.794557119032869	
i 1	241.2455850340136	0.2525	77	386	4	4	5	16	0	1	16	0	0	4.0	
i 1	241.4843469387755	0.7575000000000001	72	204	5	1	11	2	0	-2	2	0	0	7.794557119032869	
i 1	241.49237414965987	0.505	77	702	4	4	5	16	0	2	16	0	0	4.0	
i 1	241.49478231292517	0.2525	71	204	7	5	8	8	0	-1	8	0	0	9.948905943535717	
i 1	241.7431768707483	0.2525	71	386	6	5	6	8	0	-2	8	0	0	9.948905943535717	
i 1	241.75120408163266	0.2525	73	702	1	24	14	17	0	2	17	0	0	4.0	
i 1	241.75280952380953	0.2525	77	386	4	4	1	16	0	1	16	0	0	4.0	
i 1	241.75361224489797	0.2525	75	1088	5	1	12	2	0	1	2	0	0	7.794557119032869	
i 1	241.75361224489797	0.505	71	702	6	5	16	8	0	-1	8	0	0	9.948905943535717	
i 1	241.99879591836734	2.7775	75	386	5	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	242.01886394557823	0.2525	77	702	5	3	15	17	0	1	17	0	0	4.0	
i 1	242.01966666666667	0.2525	77	386	5	3	13	17	0	2	17	0	0	4.0	
i 1	242.23916326530613	2.02	74	1088	4	2	7	17	0	2	17	0	0	4.0	
i 1	242.24237414965987	0.505	74	204	7	5	6	8	0	-2	8	0	0	9.948905943535717	
i 1	242.25762585034013	0.2525	75	1088	5	1	4	2	0	1	2	0	0	7.794557119032869	
i 1	242.26485034013606	0.2525	74	1088	6	5	6	8	0	-2	8	0	0	9.948905943535717	
i 1	242.48354421768707	0.2525	71	204	7	5	7	8	0	-1	8	0	0	9.948905943535717	
i 1	242.51725850340137	0.2525	75	386	4	24	2	2	0	-2	2	0	0	8.79455711903287	
i 1	242.73033333333333	1.01	74	1088	6	5	12	8	0	-2	8	0	0	9.948905943535717	
i 1	242.7544149659864	0.2525	71	702	6	5	13	8	0	-1	8	0	0	9.948905943535717	
i 1	242.76083673469387	0.505	75	702	3	24	4	2	0	1	2	0	0	8.79455711903287	
i 1	242.98033333333333	1.5150000000000001	71	386	6	5	12	8	0	-2	8	0	0	9.948905943535717	
i 1	242.9867551020408	0.505	73	204	3	24	10	17	0	1	17	0	0	4.0	
i 1	243.00361224489797	0.2525	77	386	4	4	4	16	0	1	16	0	0	4.0	
i 1	243.0068231292517	0.505	77	702	5	3	7	17	0	1	17	0	0	4.0	
i 1	243.0132448979592	0.2525	73	702	1	24	14	17	0	2	17	0	0	4.0	
i 1	243.23916326530613	0.505	77	204	6	9	12	17	0	2	17	0	0	3.0	
i 1	243.24237414965987	0.2525	71	702	6	5	3	8	0	-1	8	0	0	9.948905943535717	
i 1	243.2455850340136	0.2525	73	386	2	24	1	17	0	1	17	0	0	4.0	
i 1	243.25361224489797	0.2525	75	702	3	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	243.48354421768707	0.7575000000000001	76	702	1	24	2	17	0	1	17	0	0	4.0	
i 1	243.49237414965987	0.2525	74	204	7	5	12	8	0	-2	8	0	0	9.948905943535717	
i 1	243.4931768707483	0.505	73	204	2	24	5	17	0	1	17	0	0	4.0	
i 1	243.4979931972789	2.02	77	386	5	3	11	17	0	2	17	0	0	4.0	
i 1	243.51003401360543	0.2525	75	386	4	24	4	2	0	-2	2	0	0	8.79455711903287	
i 1	243.5132448979592	2.02	61	702	3	27	14	16	0	1	16	0	0	12.738040549334222	
i 1	243.73916326530613	1.7675	75	1088	5	1	2	2	0	1	2	0	0	7.794557119032869	
i 1	243.7431768707483	0.2525	74	702	6	5	7	8	0	-2	8	0	0	9.948905943535717	
i 1	243.76404761904763	0.505	71	204	7	5	14	8	0	-1	8	0	0	9.948905943535717	
i 1	243.76645578231293	0.2525	77	386	4	4	8	16	0	1	16	0	0	4.0	
i 1	243.99638775510203	0.2525	77	702	5	3	7	17	0	1	17	0	0	4.0	
i 1	244.0116394557823	1.5150000000000001	74	1088	6	5	1	8	0	-2	8	0	0	9.948905943535717	
i 1	244.240768707483	0.2525	74	702	6	5	16	8	0	-2	8	0	0	9.948905943535717	
i 1	244.24719047619047	1.2625	77	386	4	4	3	16	0	1	16	0	0	4.0	
i 1	244.26244217687074	0.2525	76	386	2	24	4	16	0	1	16	0	0	4.0	
i 1	244.48354421768707	0.2525	71	702	6	5	7	8	0	-1	8	0	0	9.948905943535717	
i 1	244.4867551020408	1.01	73	702	2	24	5	17	0	2	17	0	0	4.0	
i 1	244.50762585034013	0.2525	71	386	6	5	3	2	0	-2	2	0	0	9.948905943535717	
i 1	244.7343469387755	0.2525	75	702	4	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	244.76886394557823	0.2525	72	204	5	1	4	2	0	-2	2	0	0	7.794557119032869	
i 1	244.98033333333333	0.2525	74	702	6	5	11	8	0	-2	8	0	0	9.948905943535717	
i 1	244.98274149659863	0.2525	75	702	3	24	9	2	0	1	2	0	0	8.79455711903287	
i 1	245.00120408163266	0.7575000000000001	73	204	2	24	8	17	0	1	17	0	0	4.0	
i 1	245.00762585034013	0.505	71	386	6	5	6	2	0	-2	2	0	0	9.948905943535717	
i 1	245.01244217687074	0.2525	75	386	4	24	15	2	0	-2	2	0	0	8.79455711903287	
i 1	245.2520068027211	0.2525	76	386	2	24	8	16	0	2	16	0	0	4.0	
i 1	245.48354421768707	4.04	63	204	5	19	12	16	0	2	16	0	0	3.506464741742853	
i 1	245.48595238095237	3.535	71	590	6	5	10	2	0	-2	2	0	0	9.948905943535717	
i 1	245.490768707483	11.11	63	590	5	25	7	1	0	2	1	0	0	0.39147284124284637	
i 1	245.49638775510203	2.02	77	906	4	2	13	16	0	1	16	0	0	4.0	
i 1	245.49638775510203	5.555	63	204	5	19	12	16	0	2	16	0	0	3.506464741742853	
i 1	245.49638775510203	11.11	61	590	5	25	14	16	0	2	16	0	0	0.39147284124284637	
i 1	245.49638775510203	1.01	61	204	1	27	9	16	0	248	16	308	0	12.738040549334222	
i 1	245.5020068027211	2.7775	72	590	5	1	12	2	0	-2	2	0	0	7.794557119032869	
i 1	245.50762585034013	0.505	77	906	4	2	15	17	0	2	17	0	0	4.0	
i 1	245.51003401360543	11.11	61	906	5	25	4	16	0	2	16	0	0	0.39147284124284637	
i 1	245.51003401360543	0.2525	74	906	6	5	9	8	0	-1	8	0	0	9.948905943535717	
i 1	245.51083673469387	0.2525	71	590	6	5	10	2	0	-1	2	0	0	9.948905943535717	
i 1	245.51244217687074	1.7675	76	204	1	24	5	16	0	2	16	0	0	4.0	
i 1	245.5180612244898	11.11	63	906	5	25	1	1	0	2	1	0	0	0.39147284124284637	
i 1	245.5180612244898	5.555	63	204	4	27	4	1	0	1	1	0	0	12.738040549334222	
i 1	245.73113605442177	0.2525	74	590	5	3	15	17	0	2	17	0	0	4.0	
i 1	245.73755782312926	0.505	71	204	7	5	6	8	0	-1	8	0	0	9.948905943535717	
i 1	245.75040136054423	0.2525	76	204	2	24	7	16	0	1	16	0	0	4.0	
i 1	245.76645578231293	0.2525	74	906	6	5	11	8	0	-1	8	0	0	9.948905943535717	
i 1	245.9931768707483	0.7575000000000001	72	204	5	1	1	2	0	-2	2	0	0	7.794557119032869	
i 1	246.01485034013606	0.505	74	204	6	9	12	17	0	1	17	0	0	3.0	
i 1	246.01645578231293	0.505	74	204	6	3	15	17	0	2	17	0	0	4.0	
i 1	246.25120408163266	0.2525	75	204	3	24	8	2	0	1	2	0	0	8.79455711903287	
i 1	246.26083673469387	0.505	74	906	6	5	5	8	0	-1	8	0	0	9.948905943535717	
i 1	246.48274149659863	4.545	61	204	4	27	2	16	0	1	16	0	0	12.738040549334222	
i 1	246.5068231292517	0.2525	74	590	4	3	15	17	0	2	17	0	0	4.0	
i 1	246.509231292517	0.2525	76	204	2	24	16	16	0	1	16	0	0	4.0	
i 1	246.51404761904763	1.01	75	906	4	1	7	2	0	1	2	0	0	7.794557119032869	
i 1	246.5156530612245	0.2525	77	204	6	9	10	17	0	2	17	0	0	3.0	
i 1	246.74237414965987	0.2525	75	204	4	1	12	2	0	-2	2	0	0	7.794557119032869	
i 1	246.75521768707483	2.2725	74	590	4	4	1	16	0	2	16	0	0	4.0	
i 1	246.75842857142857	0.2525	71	204	7	5	16	8	0	-1	8	0	0	9.948905943535717	
i 1	246.76404761904763	0.505	71	204	7	5	2	8	0	-1	8	0	0	9.948905943535717	
i 1	246.76645578231293	0.2525	74	204	6	3	10	17	0	2	17	0	0	4.0	
i 1	246.99237414965987	1.7675	73	204	2	24	2	17	0	1	17	0	0	4.0	
i 1	246.99478231292517	0.505	74	906	6	5	12	8	0	-1	8	0	0	9.948905943535717	
i 1	247.0020068027211	0.505	77	204	6	9	2	17	0	2	17	0	0	3.0	
i 1	247.00842857142857	0.2525	75	204	5	1	6	2	0	-2	2	0	0	7.794557119032869	
i 1	247.24879591836734	0.2525	71	590	6	5	6	2	0	-1	2	0	0	9.948905943535717	
i 1	247.25280952380953	0.505	72	204	5	1	2	2	0	-2	2	0	0	7.794557119032869	
i 1	247.4979931972789	0.7575000000000001	76	204	2	24	9	16	0	1	16	0	0	4.0	
i 1	247.5068231292517	0.505	77	906	4	2	9	17	0	2	17	0	0	4.0	
i 1	247.50842857142857	0.2525	74	204	6	5	6	8	0	-2	8	0	0	9.948905943535717	
i 1	247.51244217687074	0.505	71	204	7	5	4	8	0	-1	8	0	0	9.948905943535717	
i 1	247.51485034013606	0.2525	74	204	5	4	9	16	0	1	16	0	0	4.0	
i 1	247.51645578231293	0.2525	75	204	5	1	5	2	0	-2	2	0	0	7.794557119032869	
i 1	247.73033333333333	0.2525	73	590	2	24	11	16	0	1	16	0	0	4.0	
i 1	247.759231292517	2.02	75	906	4	1	3	2	0	1	2	0	0	7.794557119032869	
i 1	247.76404761904763	0.505	74	906	6	5	5	8	0	-1	8	0	0	9.948905943535717	
i 1	247.76645578231293	0.2525	77	906	4	2	13	16	0	1	16	0	0	4.0	
i 1	247.7680612244898	0.2525	75	204	4	1	8	2	0	-2	2	0	0	7.794557119032869	
i 1	247.99157142857143	0.7575000000000001	72	204	5	1	7	2	0	-2	2	0	0	7.794557119032869	
i 1	248.00040136054423	0.505	74	590	4	3	7	17	0	2	17	0	0	4.0	
i 1	248.0116394557823	0.2525	76	204	1	24	7	17	0	2	17	0	0	4.0	
i 1	248.01485034013606	0.2525	74	204	7	5	3	8	0	-2	8	0	0	9.948905943535717	
i 1	248.2319387755102	0.2525	74	204	6	5	8	8	0	-2	8	0	0	9.948905943535717	
i 1	248.23996598639457	0.505	71	204	7	5	7	8	0	-1	8	0	0	9.948905943535717	
i 1	248.25602040816327	0.2525	72	590	4	24	15	8	0	1	8	0	0	8.79455711903287	
i 1	248.4843469387755	0.2525	72	906	5	1	13	2	0	-2	2	0	0	7.794557119032869	
i 1	248.4955850340136	1.5150000000000001	77	906	4	2	11	16	0	1	16	0	0	4.0	
i 1	248.509231292517	0.7575000000000001	74	906	6	5	5	8	0	-1	8	0	0	9.948905943535717	
i 1	248.51244217687074	0.7575000000000001	76	204	2	24	13	16	0	1	16	0	0	4.0	
i 1	248.73033333333333	0.7575000000000001	74	906	6	5	15	8	0	-1	8	0	0	9.948905943535717	
i 1	249.01003401360543	0.505	71	204	7	5	7	8	0	-1	8	0	0	9.948905943535717	
i 1	249.24879591836734	1.2625	72	590	5	1	6	2	0	-2	2	0	0	7.794557119032869	
i 1	249.2656530612245	0.2525	71	204	7	5	4	8	0	-1	8	0	0	9.948905943535717	
i 1	249.48274149659863	2.02	77	906	4	2	8	17	0	2	17	0	0	4.0	
i 1	249.48595238095237	1.01	74	906	5	5	16	8	0	-1	8	0	0	9.948905943535717	
i 1	249.49719047619047	0.2525	74	204	6	9	15	17	0	1	17	0	0	3.0	
i 1	249.5044149659864	1.01	76	204	2	20	8	17	0	1	17	0	0	0.7587699775925509	
i 1	249.51244217687074	0.2525	74	906	6	5	2	8	0	-1	8	0	0	9.948905943535717	
i 1	249.51244217687074	0.2525	71	590	6	5	3	2	0	-2	2	0	0	9.948905943535717	
i 1	249.51485034013606	0.2525	73	204	1	20	8	16	0	1	16	0	0	0.7587699775925509	
i 1	249.51886394557823	1.5150000000000001	76	204	2	20	12	16	0	1	16	0	0	0.7587699775925509	
i 1	249.73595238095237	0.2525	73	204	2	24	6	17	0	1	17	0	0	4.758769977592551	
i 1	249.73996598639457	0.7575000000000001	71	204	7	5	15	8	0	-1	8	0	0	9.948905943535717	
i 1	249.74397959183673	2.2725	71	590	6	5	5	2	0	-1	2	0	0	9.948905943535717	
i 1	249.7568231292517	0.505	77	204	6	9	15	17	0	2	17	0	0	3.0	
i 1	249.9819387755102	1.01	73	204	2	20	9	17	0	2	17	0	0	0.7587699775925509	
i 1	249.99157142857143	0.7575000000000001	73	204	1	24	16	16	0	2	16	0	0	4.758769977592551	
i 1	249.9931768707483	1.5150000000000001	75	906	4	1	5	2	0	1	2	0	0	7.794557119032869	
i 1	249.99397959183673	1.01	73	204	1	24	10	17	0	252	17	307	0	4.758769977592551	
i 1	250.0156530612245	0.2525	74	590	4	3	11	17	0	2	17	0	0	4.0	
i 1	250.23595238095237	0.2525	72	590	4	24	12	8	0	1	8	0	0	8.79455711903287	
i 1	250.24397959183673	0.2525	77	906	4	2	5	16	0	1	16	0	0	4.0	
i 1	250.25762585034013	0.2525	74	204	6	9	7	17	0	1	17	0	0	3.0	
i 1	250.48274149659863	0.505	75	204	4	24	14	2	0	1	2	0	0	8.79455711903287	
i 1	250.4955850340136	0.2525	71	204	6	5	10	8	0	-1	8	0	0	9.948905943535717	
i 1	250.50280952380953	0.2525	74	906	6	5	11	8	0	-1	8	0	0	9.948905943535717	
i 1	250.509231292517	0.505	75	204	4	1	14	2	0	-2	2	0	0	7.794557119032869	
i 1	250.51966666666667	0.2525	76	204	2	20	5	17	0	1	17	0	0	0.7587699775925509	
i 1	250.73916326530613	0.2525	74	204	7	5	11	8	0	-2	8	0	0	9.948905943535717	
i 1	250.73996598639457	0.505	76	906	2	20	16	16	0	1	16	0	0	0.7587699775925509	
i 1	250.7431768707483	0.2525	73	590	2	24	4	16	0	2	16	0	0	4.758769977592551	
i 1	250.76645578231293	0.2525	71	204	7	5	13	8	0	-1	8	0	0	9.948905943535717	
i 1	250.9883605442177	0.505	74	906	6	5	15	8	0	-1	8	0	0	9.948905943535717	
i 1	250.98996598639457	4.04	74	590	4	3	15	17	0	2	17	0	0	4.0	
i 1	250.98996598639457	0.2525	77	203	6	3	1	17	0	2	17	0	0	4.0	
i 1	250.99157142857143	5.555	61	1172	4	26	12	1	0	1	1	0	0	0.39147284124284637	
i 1	250.99237414965987	5.555	63	1172	4	26	1	16	0	2	16	0	0	0.39147284124284637	
i 1	250.99237414965987	5.555	61	203	4	27	3	1	0	2	1	0	0	12.738040549334222	
i 1	250.9931768707483	1.5150000000000001	72	590	5	1	4	2	0	-2	2	0	0	7.794557119032869	
i 1	250.99478231292517	0.2525	75	1172	5	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	251.00361224489797	2.2725	76	1172	2	20	1	16	0	2	16	0	0	0.7587699775925509	
i 1	251.0044149659864	5.555	61	203	4	27	7	16	0	1	16	0	0	12.738040549334222	
i 1	251.01404761904763	0.2525	71	1172	6	5	1	8	0	-2	8	0	0	9.948905943535717	
i 1	251.01645578231293	1.5150000000000001	63	203	5	19	15	1	0	1	1	0	0	3.506464741742853	
i 1	251.23354421768707	0.505	75	203	4	1	10	2	0	1	2	0	0	7.794557119032869	
i 1	251.23755782312926	0.2525	76	1172	2	20	16	16	0	2	16	0	0	0.7587699775925509	
i 1	251.2383605442177	2.02	74	906	5	5	9	8	0	-1	8	0	0	9.948905943535717	
i 1	251.2383605442177	0.2525	73	203	1	24	2	17	0	2	17	0	0	4.758769977592551	
i 1	251.26003401360543	0.505	74	1172	5	9	11	16	0	1	16	0	0	3.0	
i 1	251.2616394557823	0.2525	73	1172	2	20	6	16	0	1	16	0	0	0.7587699775925509	
i 1	251.26485034013606	0.7575000000000001	73	1172	2	24	16	17	0	1	17	0	0	4.758769977592551	
i 1	251.4883605442177	0.7575000000000001	73	203	1	24	13	17	0	2	17	0	0	4.758769977592551	
i 1	251.48916326530613	0.2525	71	203	7	5	9	2	0	-1	2	0	0	9.948905943535717	
i 1	251.49478231292517	0.505	76	906	2	20	2	16	0	2	16	0	0	0.7587699775925509	
i 1	251.4955850340136	0.505	75	1172	5	1	5	2	0	-2	2	0	0	7.794557119032869	
i 1	251.5068231292517	0.505	76	590	2	24	8	17	0	2	17	0	0	4.758769977592551	
i 1	251.51404761904763	0.2525	74	590	4	4	16	16	0	2	16	0	0	4.0	
i 1	251.73996598639457	0.2525	77	1172	5	9	14	17	0	2	17	0	0	3.0	
i 1	251.74478231292517	0.2525	72	203	4	24	9	2	0	-2	2	0	0	8.79455711903287	
i 1	251.74959863945577	0.2525	74	203	7	5	9	2	0	-2	2	0	0	9.948905943535717	
i 1	251.75040136054423	0.505	77	203	6	3	8	17	0	2	17	0	0	4.0	
i 1	251.99478231292517	1.5150000000000001	73	1172	2	20	9	16	0	2	16	0	0	0.7587699775925509	
i 1	251.9979931972789	0.2525	72	590	4	24	8	8	0	1	8	0	0	8.79455711903287	
i 1	252.0020068027211	0.2525	75	906	4	1	10	2	0	1	2	0	0	7.794557119032869	
i 1	252.2367551020408	0.505	71	590	6	5	3	2	0	-1	2	0	0	9.948905943535717	
i 1	252.24719047619047	0.505	77	906	4	2	2	17	0	2	17	0	0	4.0	
i 1	252.2680612244898	0.2525	73	1172	2	20	9	16	0	1	16	0	0	0.7587699775925509	
i 1	252.26886394557823	0.2525	74	1172	5	9	15	16	0	1	16	0	0	3.0	
i 1	252.26966666666667	0.2525	71	1172	6	5	1	8	0	-1	8	0	0	9.948905943535717	
i 1	252.4843469387755	0.7575000000000001	72	590	4	24	13	8	0	1	8	0	0	8.79455711903287	
i 1	252.4867551020408	1.2625	73	1172	2	24	10	17	0	1	17	0	0	4.758769977592551	
i 1	252.48755782312926	1.2625	74	590	4	4	8	16	0	2	16	0	0	4.0	
i 1	252.49478231292517	1.5150000000000001	72	590	4	1	4	2	0	-2	2	0	0	7.794557119032869	
i 1	252.73916326530613	0.2525	77	906	4	2	6	16	0	1	16	0	0	4.0	
i 1	252.74478231292517	0.7575000000000001	73	1172	2	20	12	16	0	1	16	0	0	0.7587699775925509	
i 1	252.7520068027211	0.7575000000000001	74	906	5	5	9	8	0	-1	8	0	0	9.948905943535717	
i 1	252.7632448979592	0.2525	71	203	7	5	14	2	0	-1	2	0	0	9.948905943535717	
i 1	252.99638775510203	0.2525	74	203	5	4	8	17	0	1	17	0	0	4.0	
i 1	252.99879591836734	3.2825	71	590	6	5	5	2	0	-2	2	0	0	9.948905943535717	
i 1	253.2367551020408	2.2725	75	906	4	1	3	2	0	1	2	0	0	7.794557119032869	
i 1	253.24638775510203	0.2525	74	203	5	5	9	2	0	-2	2	0	0	9.948905943535717	
i 1	253.2568231292517	0.7575000000000001	73	203	1	24	16	17	0	2	17	0	0	4.758769977592551	
i 1	253.48033333333333	0.2525	73	590	2	24	7	16	0	1	16	0	0	4.758769977592551	
i 1	253.4819387755102	0.2525	72	906	4	1	7	2	0	-2	2	0	0	7.794557119032869	
i 1	253.490768707483	1.01	73	203	1	20	9	16	0	1	16	0	0	0.7587699775925509	
i 1	253.5116394557823	0.2525	76	906	2	20	3	17	0	1	17	0	0	0.7587699775925509	
i 1	253.51404761904763	0.2525	73	906	2	20	1	16	0	1	16	0	0	0.7587699775925509	
i 1	253.5180612244898	0.2525	71	590	6	5	7	2	0	-1	2	0	0	9.948905943535717	
i 1	253.51966666666667	0.2525	71	1172	6	5	12	8	0	-1	8	0	0	9.948905943535717	
i 1	253.74397959183673	0.7575000000000001	72	590	4	24	1	8	0	1	8	0	0	8.79455711903287	
i 1	253.7520068027211	0.2525	76	1172	2	20	6	16	0	2	16	0	0	0.7587699775925509	
i 1	253.76485034013606	0.505	73	203	1	24	8	17	0	2	17	0	0	4.758769977592551	
i 1	253.76886394557823	0.505	74	1172	4	9	8	16	0	1	16	0	0	3.0	
i 1	253.98514965986394	0.7575000000000001	76	1172	2	20	5	16	0	2	16	0	0	0.7587699775925509	
i 1	253.990768707483	0.2525	72	906	4	1	11	2	0	-2	2	0	0	7.794557119032869	
i 1	253.99157142857143	0.505	71	590	6	5	7	2	0	-1	2	0	0	9.948905943535717	
i 1	254.0132448979592	0.2525	74	906	5	5	4	8	0	-1	8	0	0	9.948905943535717	
i 1	254.23996598639457	0.7575000000000001	76	906	2	20	3	17	0	1	17	0	0	0.7587699775925509	
i 1	254.24157142857143	0.505	71	1172	6	5	15	8	0	-2	8	0	0	9.948905943535717	
i 1	254.24638775510203	2.2725	73	203	1	24	16	17	0	2	17	0	0	4.758769977592551	
i 1	254.24719047619047	0.2525	73	590	2	24	4	17	0	2	17	0	0	4.758769977592551	
i 1	254.24879591836734	0.7575000000000001	76	906	2	20	13	16	0	1	16	0	0	0.7587699775925509	
i 1	254.25521768707483	2.2725	77	906	4	2	4	17	0	2	17	0	0	4.0	
i 1	254.25602040816327	0.2525	75	1172	5	1	3	2	0	-2	2	0	0	7.794557119032869	
i 1	254.4955850340136	0.2525	74	906	5	5	5	8	0	-1	8	0	0	9.948905943535717	
i 1	254.49638775510203	0.2525	77	1172	5	9	9	17	0	2	17	0	0	3.0	
i 1	254.73274149659863	1.7675	73	1172	2	24	4	17	0	1	17	0	0	4.758769977592551	
i 1	254.73595238095237	0.2525	72	906	4	1	6	2	0	-2	2	0	0	7.794557119032869	
i 1	254.7455850340136	0.505	77	906	4	2	8	16	0	1	16	0	0	4.0	
i 1	254.7455850340136	0.2525	74	203	5	5	6	2	0	-2	2	0	0	9.948905943535717	
i 1	254.7520068027211	0.505	75	203	4	1	10	2	0	1	2	0	0	7.794557119032869	
i 1	254.7544149659864	0.505	71	1172	6	5	11	8	0	-1	8	0	0	9.948905943535717	
i 1	254.9843469387755	1.5150000000000001	72	590	4	1	4	2	0	-2	2	0	0	7.794557119032869	
i 1	254.9883605442177	0.2525	76	1172	2	20	3	17	0	2	17	0	0	0.7587699775925509	
i 1	254.9955850340136	0.7575000000000001	76	1172	2	20	1	16	0	2	16	0	0	0.7587699775925509	
i 1	255.01083673469387	0.2525	74	590	4	4	2	16	0	2	16	0	0	4.0	
i 1	255.2319387755102	0.2525	74	906	5	5	12	8	0	-1	8	0	0	9.948905943535717	
i 1	255.23996598639457	0.2525	74	590	4	3	13	17	0	2	17	0	0	4.0	
i 1	255.25280952380953	0.505	74	203	5	5	2	2	0	-2	2	0	0	9.948905943535717	
i 1	255.2616394557823	0.2525	74	203	5	4	15	17	0	1	17	0	0	4.0	
i 1	255.26244217687074	0.2525	75	1172	5	1	9	2	0	-2	2	0	0	7.794557119032869	
i 1	255.4819387755102	0.505	75	1172	5	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	255.49157142857143	1.01	77	906	4	2	5	16	0	1	16	0	0	4.0	
i 1	255.50280952380953	0.2525	72	203	4	24	9	2	0	-2	2	0	0	8.79455711903287	
i 1	255.5068231292517	1.01	63	906	5	17	15	16	0	2	16	0	0	3.506464741742853	
i 1	255.51886394557823	0.505	71	1172	6	5	2	8	0	-2	8	0	0	9.948905943535717	
i 1	255.73354421768707	0.7575000000000001	74	906	5	5	8	8	0	-1	8	0	0	9.948905943535717	
i 1	255.74397959183673	0.7575000000000001	75	906	4	1	13	2	0	1	2	0	0	7.794557119032869	
i 1	255.74638775510203	0.2525	73	906	2	20	2	16	0	1	16	0	0	0.7587699775925509	
i 1	255.74959863945577	0.2525	73	906	2	20	13	16	0	2	16	0	0	0.7587699775925509	
i 1	255.9883605442177	0.505	73	1172	2	20	6	17	0	2	17	0	0	0.7587699775925509	
i 1	255.990768707483	0.505	72	906	4	1	5	2	0	-2	2	0	0	7.794557119032869	
i 1	255.9931768707483	0.2525	71	203	5	5	10	2	0	-1	2	0	0	9.948905943535717	
i 1	256.0108367346939	0.505	73	1172	2	20	2	16	0	1	16	0	0	0.7587699775925509	
i 1	256.0108367346939	0.505	73	203	1	24	10	17	0	252	17	307	0	4.758769977592551	
i 1	256.23193877551023	0.2525	71	590	5	5	15	2	0	-1	2	0	0	9.948905943535717	
i 1	256.26886394557823	0.2525	71	1172	6	5	15	8	0	-1	8	0	0	9.948905943535717	
i 1	256.48113605442177	1.7675	74	698	4	2	7	17	0	2	17	0	0	4.0	
i 1	256.48274149659863	2.02	63	698	5	25	4	1	0	2	1	0	0	0.39147284124284637	
i 1	256.4835442176871	1.01	74	698	5	5	14	2	0	-2	2	0	0	9.948905943535717	
i 1	256.4843469387755	20.2	61	698	3	27	1	16	0	2	16	0	0	12.738040549334222	
i 1	256.48675510204083	23.23	63	698	3	27	15	1	0	2	1	0	0	12.738040549334222	
i 1	256.4883605442177	5.05	61	698	5	25	7	16	0	1	16	0	0	0.39147284124284637	
i 1	256.4891632653061	0.2525	72	200	4	24	11	8	0	-2	8	0	0	8.79455711903287	
i 1	256.49157142857143	0.7575000000000001	74	200	4	4	13	16	0	2	16	0	0	4.0	
i 1	256.49157142857143	11.11	61	200	6	25	12	16	0	2	16	0	0	0.39147284124284637	
i 1	256.4931768707483	3.535	73	1084	1	24	5	17	0	1	17	0	0	4.758769977592551	
i 1	256.49558503401363	8.08	63	200	6	25	15	1	0	1	1	0	0	0.39147284124284637	
i 1	256.4971904761905	0.2525	76	1084	1	20	4	17	0	2	17	0	0	0.7587699775925509	
i 1	256.4979931972789	0.505	71	1084	5	5	8	2	0	-2	2	0	0	9.948905943535717	
i 1	256.49879591836736	14.14	61	1084	4	26	15	1	0	2	1	0	0	0.39147284124284637	
i 1	256.5028095238095	0.2525	76	1084	1	20	2	17	0	2	17	0	0	0.7587699775925509	
i 1	256.50602040816324	1.7675	72	698	4	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	256.50602040816324	17.17	63	1084	4	26	14	16	0	1	16	0	0	0.39147284124284637	
i 1	256.5116394557823	20.2	61	698	5	17	14	1	0	2	1	0	0	3.506464741742853	
i 1	256.51404761904763	0.2525	75	200	4	1	5	2	0	1	2	0	0	7.794557119032869	
i 1	256.5164557823129	1.7675	71	200	5	5	6	8	0	-2	8	0	0	9.948905943535717	
i 1	256.73996598639457	0.2525	75	698	4	1	12	8	0	-2	8	0	0	7.794557119032869	
i 1	256.7431768707483	0.2525	72	698	3	24	3	2	0	-2	2	0	0	8.79455711903287	
i 1	256.75602040816324	0.2525	73	698	2	20	6	16	0	2	16	0	0	0.7587699775925509	
i 1	256.76886394557823	0.2525	76	698	2	20	15	17	0	1	17	0	0	0.7587699775925509	
i 1	256.99237414965984	0.2525	73	1084	1	20	10	17	0	2	17	0	0	0.7587699775925509	
i 1	256.99558503401363	0.2525	73	1084	1	20	10	17	0	2	17	0	0	0.7587699775925509	
i 1	256.99879591836736	0.2525	77	698	4	2	4	16	0	1	16	0	0	4.0	
i 1	257.00521768707483	0.2525	71	698	4	5	16	8	0	-1	8	0	0	9.948905943535717	
i 1	257.00923129251703	0.7575000000000001	75	1084	4	1	12	2	0	-2	2	0	0	7.794557119032869	
i 1	257.23996598639457	0.2525	72	200	4	24	7	8	0	-2	8	0	0	8.79455711903287	
i 1	257.24879591836736	0.505	76	698	2	20	1	16	0	2	16	0	0	0.7587699775925509	
i 1	257.25120408163264	0.505	73	698	2	20	1	17	0	2	17	0	0	0.7587699775925509	
i 1	257.2528095238095	0.7575000000000001	74	1084	3	9	11	16	0	1	16	0	0	3.0	
i 1	257.25842857142857	0.505	74	1084	3	9	5	17	0	2	17	0	0	3.0	
i 1	257.26324489795917	0.505	71	1084	5	5	5	2	0	-2	2	0	0	9.948905943535717	
i 1	257.49879591836736	0.2525	71	200	6	5	15	2	0	-1	2	0	0	9.948905943535717	
i 1	257.5068231292517	1.01	75	200	4	1	3	2	0	1	2	0	0	7.794557119032869	
i 1	257.73113605442177	0.505	76	1084	1	20	4	16	0	2	16	0	0	0.7587699775925509	
i 1	257.74478231292517	1.7675	74	698	5	5	14	2	0	-1	2	0	0	9.948905943535717	
i 1	257.7471904761905	0.2525	72	698	3	1	16	2	0	1	2	0	0	7.794557119032869	
i 1	257.75923129251703	0.505	76	1084	1	20	9	16	0	2	16	0	0	0.7587699775925509	
i 1	257.76324489795917	0.2525	71	698	4	5	16	2	0	-1	2	0	0	9.948905943535717	
i 1	257.7696666666667	0.7575000000000001	77	698	4	2	1	16	0	1	16	0	0	4.0	
i 1	257.9891632653061	1.2625	72	200	4	24	2	8	0	-2	8	0	0	8.79455711903287	
i 1	258.00441496598637	0.2525	74	200	4	3	10	17	0	1	17	0	0	4.0	
i 1	258.00842857142857	2.02	74	698	5	5	6	2	0	-2	2	0	0	9.948905943535717	
i 1	258.2479931972789	0.2525	71	698	4	5	6	2	0	-1	2	0	0	9.948905943535717	
i 1	258.2520068027211	0.2525	76	698	2	20	7	16	0	1	16	0	0	0.7587699775925509	
i 1	258.25441496598637	0.505	74	200	4	4	11	16	0	2	16	0	0	4.0	
i 1	258.25441496598637	0.2525	74	1084	3	9	10	17	0	2	17	0	0	3.0	
i 1	258.26244217687076	0.2525	72	698	3	24	2	2	0	-2	2	0	0	8.79455711903287	
i 1	258.26485034013604	0.2525	76	698	2	20	2	17	0	1	17	0	0	0.7587699775925509	
i 1	258.48113605442177	0.505	72	1084	4	1	1	8	0	-2	8	0	0	7.794557119032869	
i 1	258.48514965986396	0.2525	73	1084	2	20	12	16	0	1	16	0	0	0.7587699775925509	
i 1	258.49237414965984	1.2625	77	698	6	2	6	16	0	1	16	0	0	4.0	
i 1	258.49478231292517	0.2525	71	1084	5	5	7	2	0	-2	2	0	0	9.948905943535717	
i 1	258.49478231292517	0.2525	76	1084	1	20	1	17	0	2	17	0	0	0.7587699775925509	
i 1	258.50762585034016	0.2525	75	1084	3	1	14	2	0	-2	2	0	0	7.794557119032869	
i 1	258.50762585034016	12.120000000000001	63	698	5	25	16	1	0	2	1	0	0	0.39147284124284637	
i 1	258.51003401360543	21.21	61	698	5	17	2	1	0	1	1	0	0	3.506464741742853	
i 1	258.5108367346939	0.505	74	200	4	3	3	17	0	1	17	0	0	4.0	
i 1	258.73274149659863	0.2525	74	698	2	3	3	16	0	1	16	0	0	4.0	
i 1	258.74558503401363	3.7875	75	200	4	1	3	2	0	1	2	0	0	7.794557119032869	
i 1	258.98113605442177	0.2525	74	1084	3	9	16	16	0	1	16	0	0	3.0	
i 1	259.00923129251703	0.2525	73	1084	1	20	7	16	0	1	16	0	0	0.7587699775925509	
i 1	259.0116394557823	0.2525	74	1084	3	9	2	17	0	2	17	0	0	3.0	
i 1	259.01886394557823	0.2525	73	1084	2	20	1	16	0	2	16	0	0	0.7587699775925509	
i 1	259.23595238095237	0.2525	72	698	3	24	14	2	0	-2	2	0	0	8.79455711903287	
i 1	259.2391632653061	0.505	76	200	1	24	5	17	0	252	17	307	0	4.758769977592551	
i 1	259.2431768707483	0.505	76	698	3	20	13	17	0	2	17	0	0	0.7587699775925509	
i 1	259.24397959183676	2.2725	74	200	4	4	12	16	0	2	16	0	0	4.0	
i 1	259.26404761904763	0.505	76	698	2	20	7	17	0	1	17	0	0	0.7587699775925509	
i 1	259.2664557823129	0.2525	72	1084	4	1	12	8	0	-2	8	0	0	7.794557119032869	
i 1	259.2696666666667	1.01	74	200	4	3	9	17	0	1	17	0	0	4.0	
i 1	259.49638775510203	0.2525	75	1084	3	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	259.4979931972789	3.2825	71	200	5	5	13	2	0	-1	2	0	0	9.948905943535717	
i 1	259.50762585034016	0.505	72	200	4	24	13	8	0	-2	8	0	0	8.79455711903287	
i 1	259.74478231292517	0.2525	73	1084	2	20	15	17	0	1	17	0	0	0.7587699775925509	
i 1	259.75441496598637	0.7575000000000001	73	1084	1	20	4	16	0	1	16	0	0	0.7587699775925509	
i 1	259.7664557823129	0.2525	77	698	4	4	14	17	0	1	17	0	0	4.0	
i 1	259.76886394557823	0.505	72	698	3	24	14	2	0	-2	2	0	0	8.79455711903287	
i 1	259.98514965986396	0.2525	72	698	3	1	7	2	0	1	2	0	0	7.794557119032869	
i 1	259.99558503401363	0.2525	74	1084	3	9	14	17	0	2	17	0	0	3.0	
i 1	260.23514965986396	1.2625	72	698	4	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	260.23595238095237	0.2525	72	1084	4	1	14	8	0	-2	8	0	0	7.794557119032869	
i 1	260.2471904761905	1.01	73	1084	1	24	14	17	0	1	17	0	0	4.758769977592551	
i 1	260.25361224489797	0.7575000000000001	74	1084	3	9	2	16	0	1	16	0	0	3.0	
i 1	260.25842857142857	0.505	74	698	2	3	5	16	0	1	16	0	0	4.0	
i 1	260.2616394557823	0.505	71	1084	5	5	4	2	0	-1	2	0	0	9.948905943535717	
i 1	260.2664557823129	0.2525	73	1084	2	20	9	17	0	1	17	0	0	0.7587699775925509	
i 1	260.50040136054423	0.505	73	698	2	20	5	16	0	1	16	0	0	0.7587699775925509	
i 1	260.50842857142857	0.505	73	698	3	20	8	17	0	1	17	0	0	0.7587699775925509	
i 1	260.74076870748297	0.2525	74	698	4	2	9	17	0	2	17	0	0	4.0	
i 1	260.9835442176871	0.2525	73	1084	2	20	7	16	0	2	16	0	0	0.7587699775925509	
i 1	260.99237414965984	0.505	73	1084	1	20	8	16	0	1	16	0	0	0.7587699775925509	
i 1	260.99558503401363	3.7875	76	698	1	24	12	16	0	252	16	307	0	4.758769977592551	
i 1	261.00842857142857	0.2525	72	698	3	1	16	2	0	1	2	0	0	7.794557119032869	
i 1	261.00842857142857	2.02	74	200	4	3	6	17	0	1	17	0	0	4.0	
i 1	261.01244217687076	0.2525	74	1084	3	9	10	17	0	2	17	0	0	3.0	
i 1	261.01485034013604	0.505	71	1084	5	5	15	2	0	-2	2	0	0	9.948905943535717	
i 1	261.23996598639457	0.7575000000000001	72	698	3	24	8	2	0	-2	2	0	0	8.79455711903287	
i 1	261.49076870748297	0.505	74	1084	3	9	5	16	0	1	16	0	0	3.0	
i 1	261.49879591836736	0.2525	74	1084	3	9	13	17	0	2	17	0	0	3.0	
i 1	261.49879591836736	0.2525	73	1084	1	24	8	17	0	1	17	0	0	4.758769977592551	
i 1	261.5028095238095	0.2525	75	1084	3	1	12	2	0	-2	2	0	0	7.794557119032869	
i 1	261.5028095238095	20.2	61	200	5	17	12	16	0	1	16	0	0	3.506464741742853	
i 1	261.51725850340137	12.120000000000001	61	698	5	25	12	16	0	1	16	0	0	0.39147284124284637	
i 1	261.51806122448977	1.7675	73	1084	2	20	4	16	0	1	16	0	0	0.7587699775925509	
i 1	261.73996598639457	0.505	74	200	4	4	16	16	0	2	16	0	0	4.0	
i 1	261.74076870748297	0.7575000000000001	72	698	3	1	13	2	0	1	2	0	0	7.794557119032869	
i 1	261.75923129251703	0.2525	76	1084	1	20	15	17	0	2	17	0	0	0.7587699775925509	
i 1	261.98675510204083	0.2525	71	698	4	5	9	8	0	-1	8	0	0	9.948905943535717	
i 1	262.00521768707483	0.2525	74	698	2	3	12	16	0	1	16	0	0	4.0	
i 1	262.00762585034016	2.525	72	698	4	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	262.01806122448977	0.2525	74	698	5	5	8	2	0	-1	2	0	0	9.948905943535717	
i 1	262.2568231292517	0.2525	74	1084	3	9	14	17	0	2	17	0	0	3.0	
i 1	262.25762585034016	0.2525	74	698	6	2	7	17	0	2	17	0	0	4.0	
i 1	262.25923129251703	0.505	71	1084	5	5	2	2	0	-2	2	0	0	9.948905943535717	
i 1	262.26404761904763	2.02	74	698	5	5	12	2	0	-2	2	0	0	9.948905943535717	
i 1	262.4835442176871	1.5150000000000001	73	1084	2	20	13	16	0	2	16	0	0	0.7587699775925509	
i 1	262.48755782312924	0.2525	74	1084	3	9	4	16	0	1	16	0	0	3.0	
i 1	262.4971904761905	1.7675	76	1084	1	20	16	17	0	2	17	0	0	0.7587699775925509	
i 1	262.5028095238095	0.505	75	1084	3	1	2	2	0	-2	2	0	0	7.794557119032869	
i 1	262.50762585034016	0.7575000000000001	72	200	4	24	7	8	0	-2	8	0	0	8.79455711903287	
i 1	262.5196666666667	1.5150000000000001	77	698	6	2	1	16	0	1	16	0	0	4.0	
i 1	262.73996598639457	0.505	74	698	6	2	1	17	0	2	17	0	0	4.0	
i 1	262.75361224489797	0.2525	71	1084	4	5	13	2	0	-1	2	0	0	9.948905943535717	
i 1	262.76404761904763	0.7575000000000001	71	698	4	5	10	8	0	-1	8	0	0	9.948905943535717	
i 1	262.98193877551023	0.2525	74	200	4	4	14	16	0	2	16	0	0	4.0	
i 1	262.98514965986396	0.2525	72	698	3	1	14	2	0	1	2	0	0	7.794557119032869	
i 1	262.99478231292517	0.2525	71	200	5	5	6	2	0	-1	2	0	0	9.948905943535717	
i 1	263.23675510204083	0.2525	72	1084	3	1	2	8	0	-2	8	0	0	7.794557119032869	
i 1	263.2520068027211	0.2525	74	698	2	3	14	16	0	1	16	0	0	4.0	
i 1	263.25602040816324	0.505	75	1084	3	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	263.26485034013604	0.2525	73	1084	1	24	16	17	0	1	17	0	0	4.758769977592551	
i 1	263.2656530612245	0.2525	74	1084	3	9	10	17	0	2	17	0	0	3.0	
i 1	263.4883605442177	0.7575000000000001	75	200	4	1	13	2	0	1	2	0	0	7.794557119032869	
i 1	263.5028095238095	1.01	74	200	4	3	6	17	0	1	17	0	0	4.0	
i 1	263.50762585034016	1.2625	73	1084	2	20	1	16	0	1	16	0	0	0.7587699775925509	
i 1	263.73996598639457	0.2525	71	1084	5	5	7	2	0	-2	2	0	0	9.948905943535717	
i 1	263.74397959183676	0.2525	72	1084	3	1	11	8	0	-2	8	0	0	7.794557119032869	
i 1	263.75120408163264	0.7575000000000001	74	698	5	5	3	2	0	-1	2	0	0	9.948905943535717	
i 1	263.75521768707483	0.2525	74	698	2	3	10	16	0	1	16	0	0	4.0	
i 1	263.9803333333333	0.2525	77	698	2	4	8	17	0	1	17	0	0	4.0	
i 1	263.98274149659863	0.2525	75	1084	3	1	14	2	0	-2	2	0	0	7.794557119032869	
i 1	264.01806122448977	0.505	74	200	4	4	5	16	0	2	16	0	0	4.0	
i 1	264.0196666666667	2.02	71	200	5	5	3	8	0	-2	8	0	0	9.948905943535717	
i 1	264.23996598639457	0.505	71	1084	4	5	2	2	0	-1	2	0	0	9.948905943535717	
i 1	264.24638775510203	1.2625	73	1084	1	24	8	17	0	1	17	0	0	4.758769977592551	
i 1	264.48755782312924	0.505	74	698	5	5	11	2	0	-2	2	0	0	9.948905943535717	
i 1	264.49157142857143	0.2525	73	1084	2	20	2	16	0	2	16	0	0	0.7587699775925509	
i 1	264.49237414965984	2.02	75	200	4	1	4	2	0	1	2	0	0	7.794557119032869	
i 1	264.49879591836736	0.505	72	698	6	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	264.50361224489797	1.01	74	200	6	3	4	17	0	1	17	0	0	4.0	
i 1	264.50842857142857	0.2525	72	698	2	1	10	2	0	1	2	0	0	7.794557119032869	
i 1	264.50842857142857	17.17	63	200	5	17	11	16	0	2	16	0	0	3.506464741742853	
i 1	264.51485034013604	12.120000000000001	63	200	6	25	12	1	0	1	1	0	0	0.39147284124284637	
i 1	264.73595238095237	0.2525	76	200	2	24	15	17	0	1	17	0	0	4.758769977592551	
i 1	264.7479931972789	0.505	73	698	3	20	3	16	0	1	16	0	0	0.7587699775925509	
i 1	264.74959863945577	0.505	72	200	4	24	15	8	0	-2	8	0	0	8.79455711903287	
i 1	264.75040136054423	0.505	74	698	5	5	9	2	0	-1	2	0	0	9.948905943535717	
i 1	264.9843469387755	0.505	71	698	4	5	10	8	0	-1	8	0	0	9.948905943535717	
i 1	264.9843469387755	0.2525	73	698	3	20	11	16	0	2	16	0	0	0.7587699775925509	
i 1	264.99638775510203	0.505	72	698	3	24	16	2	0	-2	2	0	0	8.79455711903287	
i 1	264.99879591836736	1.7675	74	200	4	4	7	16	0	2	16	0	0	4.0	
i 1	265.2303333333333	0.505	76	1084	2	20	1	16	0	1	16	0	0	0.7587699775925509	
i 1	265.23113605442177	2.2725	76	1084	1	20	2	17	0	2	17	0	0	0.7587699775925509	
i 1	265.24397959183676	0.2525	71	200	5	5	4	2	0	-1	2	0	0	9.948905943535717	
i 1	265.24558503401363	0.7575000000000001	73	1084	2	20	3	17	0	2	17	0	0	0.7587699775925509	
i 1	265.26485034013604	0.2525	75	1084	3	1	11	2	0	-2	2	0	0	7.794557119032869	
i 1	265.5020068027211	1.01	74	698	5	5	1	2	0	-1	2	0	0	9.948905943535717	
i 1	265.5020068027211	0.2525	71	1084	4	5	6	2	0	-2	2	0	0	9.948905943535717	
i 1	265.50521768707483	0.2525	72	200	4	24	12	8	0	-2	8	0	0	8.79455711903287	
i 1	265.5068231292517	0.2525	75	698	4	1	14	8	0	-2	8	0	0	7.794557119032869	
i 1	265.7431768707483	0.2525	72	698	6	1	7	2	0	-2	2	0	0	7.794557119032869	
i 1	265.75441496598637	0.7575000000000001	73	1084	1	24	11	17	0	1	17	0	0	4.758769977592551	
i 1	265.75923129251703	1.7675	74	698	5	5	5	2	0	-2	2	0	0	9.948905943535717	
i 1	265.7608367346939	0.505	74	200	6	3	5	17	0	1	17	0	0	4.0	
i 1	265.76324489795917	0.2525	72	698	2	1	13	2	0	1	2	0	0	7.794557119032869	
i 1	265.98113605442177	0.2525	71	1084	4	5	1	2	0	-1	2	0	0	9.948905943535717	
i 1	265.9883605442177	0.2525	74	698	2	3	14	16	0	1	16	0	0	4.0	
i 1	266.0020068027211	0.2525	76	698	3	20	9	16	0	1	16	0	0	0.7587699775925509	
i 1	266.0068231292517	1.2625	72	200	4	24	3	8	0	-2	8	0	0	8.79455711903287	
i 1	266.2303333333333	0.505	77	698	2	4	7	17	0	1	17	0	0	4.0	
i 1	266.2303333333333	0.505	76	1084	2	20	3	16	0	1	16	0	0	0.7587699775925509	
i 1	266.23996598639457	0.2525	71	1084	4	5	8	2	0	-2	2	0	0	9.948905943535717	
i 1	266.2696666666667	1.5150000000000001	74	698	6	2	13	17	0	2	17	0	0	4.0	
i 1	266.49879591836736	0.2525	75	698	4	1	6	8	0	-2	8	0	0	7.794557119032869	
i 1	266.50361224489797	0.2525	72	698	2	1	9	2	0	1	2	0	0	7.794557119032869	
i 1	266.51404761904763	3.7875	71	200	5	5	12	2	0	-1	2	0	0	9.948905943535717	
i 1	266.73113605442177	0.2525	71	1084	4	5	10	2	0	-2	2	0	0	9.948905943535717	
i 1	266.7383605442177	0.2525	74	698	2	3	13	16	0	1	16	0	0	4.0	
i 1	266.7528095238095	0.2525	74	200	6	3	11	17	0	1	17	0	0	4.0	
i 1	266.75441496598637	1.2625	75	200	4	1	1	2	0	1	2	0	0	7.794557119032869	
i 1	266.75521768707483	0.2525	72	698	6	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	266.7568231292517	0.7575000000000001	76	698	3	20	7	17	0	1	17	0	0	0.7587699775925509	
i 1	266.76806122448977	0.2525	76	698	3	20	12	16	0	1	16	0	0	0.7587699775925509	
i 1	266.98514965986396	1.7675	77	698	6	2	10	16	0	1	16	0	0	4.0	
i 1	267.00040136054423	0.2525	71	200	5	5	7	8	0	-2	8	0	0	9.948905943535717	
i 1	267.0196666666667	0.2525	74	200	4	4	10	16	0	2	16	0	0	4.0	
i 1	267.2303333333333	0.2525	73	1084	1	24	10	17	0	1	17	0	0	4.758769977592551	
i 1	267.24879591836736	0.2525	77	698	2	4	12	17	0	1	17	0	0	4.0	
i 1	267.2616394557823	0.2525	71	698	4	5	15	8	0	-1	8	0	0	9.948905943535717	
i 1	267.48113605442177	0.7575000000000001	74	1084	3	9	8	17	0	2	17	0	0	3.0	
i 1	267.49397959183676	0.2525	72	698	2	24	14	2	0	-2	2	0	0	8.79455711903287	
i 1	267.49397959183676	0.2525	76	698	3	20	8	17	0	1	17	0	0	3.336144960550463	
i 1	267.4971904761905	0.2525	72	200	4	24	5	8	0	-2	8	0	0	8.79455711903287	
i 1	267.5020068027211	12.120000000000001	61	200	6	25	16	16	0	2	16	0	0	0.39147284124284637	
i 1	267.50361224489797	0.2525	76	200	3	20	1	17	0	1	17	0	0	3.336144960550463	
i 1	267.50602040816324	0.505	71	1084	4	5	15	2	0	-2	2	0	0	9.948905943535717	
i 1	267.50762585034016	14.14	63	1084	4	18	5	1	0	2	1	0	0	3.506464741742853	
i 1	267.51886394557823	1.01	76	1084	1	20	14	17	0	2	17	0	0	3.336144960550463	
i 1	267.73595238095237	0.2525	74	698	2	3	8	16	0	1	16	0	0	4.0	
i 1	267.74478231292517	3.0300000000000002	72	698	6	1	3	2	0	-2	2	0	0	7.794557119032869	
i 1	267.75842857142857	0.7575000000000001	76	1084	2	20	10	17	0	1	17	0	0	3.336144960550463	
i 1	267.75923129251703	0.7575000000000001	73	1084	2	20	7	16	0	1	16	0	0	3.336144960550463	
i 1	267.76324489795917	0.2525	71	698	4	5	15	8	0	-1	8	0	0	9.948905943535717	
i 1	267.99157142857143	0.505	74	200	5	4	1	16	0	2	16	0	0	4.0	
i 1	268.00040136054423	0.2525	71	200	5	5	14	8	0	-2	8	0	0	9.948905943535717	
i 1	268.0116394557823	0.2525	75	698	6	1	16	8	0	-2	8	0	0	7.794557119032869	
i 1	268.01244217687076	0.2525	71	1084	4	5	11	2	0	-1	2	0	0	9.948905943535717	
i 1	268.01485034013604	1.01	72	200	4	24	16	8	0	-2	8	0	0	8.79455711903287	
i 1	268.25521768707483	2.02	74	200	6	3	6	17	0	1	17	0	0	4.0	
i 1	268.25842857142857	0.505	72	698	2	1	7	2	0	1	2	0	0	7.794557119032869	
i 1	268.4843469387755	0.2525	76	200	3	20	12	17	0	1	17	0	0	3.336144960550463	
i 1	268.4883605442177	0.505	76	698	3	20	14	17	0	1	17	0	0	3.336144960550463	
i 1	268.49237414965984	0.505	73	1084	1	24	10	17	0	1	17	0	0	7.336144960550463	
i 1	268.4931768707483	0.2525	74	698	6	2	13	17	0	2	17	0	0	4.0	
i 1	268.50521768707483	1.2625	71	1084	4	5	13	2	0	-1	2	0	0	9.948905943535717	
i 1	268.74157142857143	0.505	77	698	2	4	8	17	0	1	17	0	0	4.0	
i 1	268.7471904761905	0.7575000000000001	74	1084	3	9	7	17	0	2	17	0	0	3.0	
i 1	268.7568231292517	0.2525	76	698	3	20	6	16	0	1	16	0	0	3.336144960550463	
i 1	268.7656530612245	0.2525	75	1084	3	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	268.9835442176871	0.2525	72	1084	3	1	12	8	0	-2	8	0	0	7.794557119032869	
i 1	268.99638775510203	0.2525	75	698	6	1	7	8	0	-2	8	0	0	7.794557119032869	
i 1	269.0156530612245	0.2525	74	698	6	5	4	2	0	-1	2	0	0	9.948905943535717	
i 1	269.23113605442177	0.7575000000000001	75	200	4	1	2	2	0	1	2	0	0	7.794557119032869	
i 1	269.23514965986396	0.2525	74	200	5	4	12	16	0	2	16	0	0	4.0	
i 1	269.24478231292517	0.2525	73	698	3	20	14	16	0	2	16	0	0	3.336144960550463	
i 1	269.2608367346939	1.01	73	1084	1	24	1	17	0	1	17	0	0	7.336144960550463	
i 1	269.26324489795917	0.2525	73	698	3	20	12	17	0	2	17	0	0	3.336144960550463	
i 1	269.2664557823129	0.505	76	1084	1	20	9	17	0	2	17	0	0	3.336144960550463	
i 1	269.48514965986396	0.2525	74	698	5	5	4	2	0	-2	2	0	0	9.948905943535717	
i 1	269.48755782312924	0.2525	77	698	2	4	14	17	0	1	17	0	0	4.0	
i 1	269.49558503401363	0.505	77	698	6	2	6	16	0	1	16	0	0	4.0	
i 1	269.49959863945577	0.7575000000000001	76	698	1	24	11	16	0	1	16	0	0	7.336144960550463	
i 1	269.73755782312924	0.2525	71	698	4	5	3	8	0	-1	8	0	0	9.948905943535717	
i 1	269.7431768707483	0.2525	71	1084	4	5	7	2	0	-2	2	0	0	9.948905943535717	
i 1	269.74397959183676	1.2625	74	200	5	4	12	16	0	2	16	0	0	4.0	
i 1	269.76324489795917	0.2525	75	1084	3	1	9	2	0	-2	2	0	0	7.794557119032869	
i 1	269.98274149659863	0.505	74	698	5	5	7	2	0	-2	2	0	0	9.948905943535717	
i 1	269.9891632653061	0.2525	72	1084	3	1	8	8	0	-2	8	0	0	7.794557119032869	
i 1	269.99638775510203	0.505	72	698	2	1	6	2	0	1	2	0	0	7.794557119032869	
i 1	270.00120408163264	0.7575000000000001	73	1084	2	20	15	17	0	2	17	0	0	3.336144960550463	
i 1	270.01324489795917	0.2525	74	698	2	3	1	16	0	1	16	0	0	4.0	
i 1	270.01806122448977	0.7575000000000001	76	1084	1	20	4	17	0	2	17	0	0	3.336144960550463	
i 1	270.2471904761905	0.2525	77	698	6	2	11	16	0	1	16	0	0	4.0	
i 1	270.26485034013604	0.2525	77	698	2	4	13	17	0	1	17	0	0	4.0	
i 1	270.48595238095237	1.7675	74	698	6	5	9	2	0	-2	2	0	0	9.948905943535717	
i 1	270.4971904761905	1.01	73	698	1	20	5	17	0	1	17	0	0	3.336144960550463	
i 1	270.4979931972789	11.11	61	1084	4	18	3	1	0	1	1	0	0	3.506464741742853	
i 1	270.49959863945577	1.5150000000000001	75	200	6	1	14	2	0	1	2	0	0	7.794557119032869	
i 1	270.50120408163264	11.11	61	1084	4	26	4	1	0	2	1	0	0	0.39147284124284637	
i 1	270.51886394557823	0.2525	74	698	2	3	6	16	0	1	16	0	0	4.0	
i 1	270.7343469387755	0.2525	73	1084	2	24	16	17	0	1	17	0	0	7.336144960550463	
i 1	270.76806122448977	2.2725	74	200	6	3	5	17	0	1	17	0	0	4.0	
i 1	270.99237414965984	0.2525	73	1084	2	20	16	17	0	2	17	0	0	3.336144960550463	
i 1	271.0196666666667	0.505	72	200	4	24	10	8	0	-2	8	0	0	8.79455711903287	
i 1	271.23996598639457	1.01	73	1084	2	24	4	17	0	1	17	0	0	7.336144960550463	
i 1	271.2431768707483	0.2525	74	1084	3	9	9	17	0	2	17	0	0	3.0	
i 1	271.2608367346939	0.2525	74	200	5	4	6	16	0	2	16	0	0	4.0	
i 1	271.2616394557823	0.2525	71	698	3	5	3	2	0	-1	2	0	0	9.948905943535717	
i 1	271.5068231292517	1.01	74	698	6	5	3	2	0	-1	2	0	0	9.948905943535717	
i 1	271.5116394557823	0.2525	77	698	2	4	12	17	0	1	17	0	0	4.0	
i 1	271.51725850340137	0.2525	77	698	4	2	4	16	0	1	16	0	0	4.0	
i 1	271.7343469387755	1.2625	72	698	6	1	8	2	0	-2	2	0	0	7.794557119032869	
i 1	271.73514965986396	1.01	76	698	1	20	8	16	0	2	16	0	0	3.336144960550463	
i 1	271.75441496598637	0.505	74	200	5	4	1	16	0	2	16	0	0	4.0	
i 1	271.76404761904763	1.7675	71	200	5	5	8	8	0	-2	8	0	0	9.948905943535717	
i 1	271.76485034013604	0.2525	73	1084	2	20	7	17	0	2	17	0	0	3.336144960550463	
i 1	272.01886394557823	0.505	74	1084	3	9	9	17	0	2	17	0	0	3.0	
i 1	272.25762585034016	0.2525	71	698	3	5	6	2	0	-1	2	0	0	9.948905943535717	
i 1	272.26806122448977	1.7675	77	698	4	2	1	16	0	1	16	0	0	4.0	
i 1	272.4803333333333	0.2525	71	1084	4	5	4	2	0	-2	2	0	0	9.948905943535717	
i 1	272.49076870748297	0.2525	74	200	5	4	10	16	0	2	16	0	0	4.0	
i 1	272.5028095238095	1.5150000000000001	75	200	6	1	2	2	0	1	2	0	0	7.794557119032869	
i 1	272.5068231292517	0.2525	74	698	6	5	14	2	0	-2	2	0	0	9.948905943535717	
i 1	272.51886394557823	0.2525	75	698	6	1	9	8	0	-2	8	0	0	7.794557119032869	
i 1	272.73274149659863	0.2525	74	698	2	3	7	16	0	1	16	0	0	4.0	
i 1	272.75361224489797	2.02	74	698	6	5	1	2	0	-1	2	0	0	9.948905943535717	
i 1	272.75923129251703	0.2525	71	698	3	5	2	8	0	-1	8	0	0	9.948905943535717	
i 1	272.76485034013604	0.2525	76	200	3	20	10	17	0	1	17	0	0	3.336144960550463	
i 1	272.9931768707483	0.2525	73	698	1	20	10	16	0	2	16	0	0	3.336144960550463	
i 1	273.01003401360543	0.2525	72	200	4	24	11	8	0	-2	8	0	0	8.79455711903287	
i 1	273.24558503401363	0.2525	74	698	2	3	8	16	0	1	16	0	0	4.0	
i 1	273.2608367346939	0.2525	72	698	2	1	11	2	0	1	2	0	0	7.794557119032869	
i 1	273.26485034013604	0.2525	72	698	2	24	6	2	0	-2	2	0	0	8.79455711903287	
i 1	273.2696666666667	0.2525	74	698	6	2	11	17	0	2	17	0	0	4.0	
i 1	273.2696666666667	0.2525	71	698	3	5	16	2	0	-1	2	0	0	9.948905943535717	
i 1	273.48595238095237	1.01	74	200	6	3	9	17	0	1	17	0	0	4.0	
i 1	273.49478231292517	0.7575000000000001	76	1084	2	20	14	17	0	2	17	0	0	3.336144960550463	
i 1	273.4971904761905	8.08	61	698	3	19	12	16	0	1	16	0	0	3.506464741742853	
i 1	273.50602040816324	0.2525	73	698	3	20	3	17	0	2	17	0	0	3.336144960550463	
i 1	273.51003401360543	0.2525	71	200	5	5	7	2	0	-1	2	0	0	9.948905943535717	
i 1	273.5156530612245	0.2525	72	698	5	1	1	2	0	-2	2	0	0	7.794557119032869	
i 1	273.5164557823129	0.2525	74	698	6	5	5	2	0	-2	2	0	0	9.948905943535717	
i 1	273.51806122448977	8.08	63	1084	4	26	12	16	0	1	16	0	0	0.39147284124284637	
i 1	273.5196666666667	1.01	73	1084	2	24	4	17	0	1	17	0	0	7.336144960550463	
i 1	273.73514965986396	0.2525	73	1084	2	20	10	16	0	2	16	0	0	3.336144960550463	
i 1	273.75762585034016	1.7675	72	200	5	24	6	8	0	-2	8	0	0	8.79455711903287	
i 1	273.7608367346939	0.2525	71	200	7	5	10	8	0	-2	8	0	0	9.948905943535717	
i 1	273.98675510204083	2.2725	74	698	6	5	11	2	0	-2	2	0	0	9.948905943535717	
i 1	273.9883605442177	0.505	72	698	5	1	1	2	0	-2	2	0	0	7.794557119032869	
i 1	274.00521768707483	0.2525	73	698	3	20	12	16	0	1	16	0	0	3.336144960550463	
i 1	274.01244217687076	0.2525	74	1084	5	9	2	16	0	1	16	0	0	3.0	
i 1	274.01485034013604	0.2525	75	1084	3	1	4	2	0	-2	2	0	0	7.794557119032869	
i 1	274.24157142857143	1.7675	76	1084	2	20	1	16	0	1	16	0	0	3.336144960550463	
i 1	274.24558503401363	0.505	74	698	4	2	12	17	0	2	17	0	0	4.0	
i 1	274.2568231292517	0.2525	72	1084	3	1	16	8	0	-2	8	0	0	7.794557119032869	
i 1	274.26725850340137	1.5150000000000001	74	200	5	4	3	16	0	2	16	0	0	4.0	
i 1	274.26806122448977	0.2525	71	200	7	5	6	8	0	-2	8	0	0	9.948905943535717	
i 1	274.4803333333333	0.2525	73	698	1	24	2	17	0	1	17	0	0	7.336144960550463	
i 1	274.49478231292517	0.2525	74	698	2	3	11	16	0	1	16	0	0	4.0	
i 1	274.4979931972789	0.505	71	200	5	5	5	2	0	-1	2	0	0	9.948905943535717	
i 1	274.73113605442177	0.505	76	1084	2	20	6	17	0	2	17	0	0	3.336144960550463	
i 1	274.73193877551023	1.01	75	200	6	1	10	2	0	1	2	0	0	7.794557119032869	
i 1	274.7431768707483	0.505	74	1084	5	9	3	17	0	2	17	0	0	3.0	
i 1	274.7520068027211	0.2525	75	1084	3	1	2	2	0	-2	2	0	0	7.794557119032869	
i 1	274.76485034013604	0.7575000000000001	76	1084	2	20	9	17	0	2	17	0	0	3.336144960550463	
i 1	274.99237414965984	0.505	71	200	7	5	3	8	0	-2	8	0	0	9.948905943535717	
i 1	275.0196666666667	0.2525	71	698	3	5	15	2	0	-1	2	0	0	9.948905943535717	
i 1	275.2335442176871	0.2525	77	698	2	4	3	17	0	1	17	0	0	4.0	
i 1	275.26404761904763	0.2525	71	1084	4	5	16	2	0	-1	2	0	0	9.948905943535717	
i 1	275.26485034013604	0.2525	74	200	6	3	1	17	0	1	17	0	0	4.0	
i 1	275.26886394557823	1.01	72	698	5	1	15	2	0	-2	2	0	0	7.794557119032869	
i 1	275.4883605442177	2.02	74	698	4	2	9	17	0	2	17	0	0	4.0	
i 1	275.49879591836736	0.2525	72	1084	3	1	5	8	0	-2	8	0	0	7.794557119032869	
i 1	275.51003401360543	0.2525	74	1084	5	9	12	16	0	1	16	0	0	3.0	
i 1	275.74237414965984	0.2525	74	698	6	5	1	2	0	-1	2	0	0	9.948905943535717	
i 1	275.75602040816324	0.2525	75	1084	3	1	1	2	0	-2	2	0	0	7.794557119032869	
i 1	275.98514965986396	1.7675	75	200	6	1	13	2	0	1	2	0	0	7.794557119032869	
i 1	275.9883605442177	0.2525	76	1084	2	20	14	17	0	2	17	0	0	3.336144960550463	
i 1	275.9891632653061	0.505	72	698	2	24	7	2	0	-2	2	0	0	8.79455711903287	
i 1	275.99397959183676	0.7575000000000001	76	698	1	20	16	17	0	1	17	0	0	3.336144960550463	
i 1	276.01324489795917	0.505	71	200	5	5	14	2	0	-1	2	0	0	9.948905943535717	
i 1	276.25120408163264	0.2525	74	698	6	5	16	2	0	-1	2	0	0	9.948905943535717	
i 1	276.25602040816324	0.2525	74	200	5	4	4	16	0	2	16	0	0	4.0	
i 1	276.26324489795917	0.2525	74	200	6	3	8	17	0	1	17	0	0	4.0	
i 1	276.26806122448977	0.2525	72	698	2	1	4	2	0	1	2	0	0	7.794557119032869	
i 1	276.49076870748297	0.2525	71	698	3	5	11	8	0	-1	8	0	0	9.948905943535717	
i 1	276.49157142857143	5.05	61	698	3	27	13	16	0	2	16	0	0	12.738040549334222	
i 1	276.49237414965984	5.05	61	698	5	14	12	1	0	1	1	0	0	2.551638712202796	
i 1	276.49638775510203	1.7675	71	200	7	5	13	2	0	-1	2	0	0	9.948905943535717	
i 1	276.50441496598637	0.2525	72	1084	3	1	9	8	0	-2	8	0	0	7.794557119032869	
i 1	276.5068231292517	0.7575000000000001	76	1084	2	20	13	17	0	2	17	0	0	3.336144960550463	
i 1	276.50762585034016	1.01	76	1084	2	20	2	17	0	2	17	0	0	3.336144960550463	
i 1	276.50923129251703	0.505	77	698	2	4	7	17	0	1	17	0	0	4.0	
i 1	276.5108367346939	5.05	61	698	6	17	1	1	0	2	1	0	0	3.506464741742853	
i 1	276.51244217687076	0.2525	72	698	5	1	12	2	0	-2	2	0	0	7.794557119032869	
i 1	276.51244217687076	5.05	63	698	3	19	13	1	0	1	1	0	0	3.506464741742853	
i 1	276.76485034013604	0.2525	74	1084	5	9	13	16	0	1	16	0	0	3.0	
i 1	276.9931768707483	0.2525	74	200	4	3	9	17	0	1	17	0	0	4.0	
i 1	277.00923129251703	1.5150000000000001	77	698	4	2	12	16	0	1	16	0	0	4.0	
i 1	277.01003401360543	0.2525	74	698	4	5	12	2	0	-1	2	0	0	9.948905943535717	
i 1	277.0196666666667	0.505	71	1084	4	5	1	2	0	-2	2	0	0	9.948905943535717	
i 1	277.2431768707483	0.505	76	698	3	20	2	17	0	1	17	0	0	3.336144960550463	
i 1	277.2528095238095	0.505	73	1084	2	24	12	17	0	1	17	0	0	7.336144960550463	
i 1	277.2696666666667	0.505	75	698	5	1	13	8	0	-2	8	0	0	7.794557119032869	
i 1	277.4835442176871	1.2625	76	698	1	24	6	17	0	2	17	0	0	7.336144960550463	
i 1	277.49397959183676	0.2525	74	200	5	4	8	16	0	2	16	0	0	4.0	
i 1	277.49397959183676	0.2525	71	1084	4	5	3	2	0	-1	2	0	0	9.948905943535717	
i 1	277.49879591836736	0.2525	76	698	3	20	3	16	0	1	16	0	0	3.336144960550463	
i 1	277.73113605442177	0.2525	75	1084	5	1	8	2	0	-2	2	0	0	7.794557119032869	
i 1	277.73113605442177	0.2525	74	698	4	5	9	2	0	-1	2	0	0	9.948905943535717	
i 1	277.73755782312924	2.525	73	1084	1	24	6	17	0	252	17	307	0	7.336144960550463	
i 1	277.74879591836736	0.7575000000000001	76	1084	2	20	12	17	0	1	17	0	0	3.336144960550463	
i 1	277.74959863945577	0.505	74	1084	5	9	3	17	0	2	17	0	0	3.0	
i 1	277.75441496598637	1.5150000000000001	74	698	6	5	12	2	0	-2	2	0	0	9.948905943535717	
i 1	277.75923129251703	0.505	77	698	2	4	6	17	0	1	17	0	0	4.0	
i 1	277.7664557823129	0.7575000000000001	72	698	5	1	8	2	0	-2	2	0	0	7.794557119032869	
i 1	278.24237414965984	0.2525	75	1084	5	1	14	2	0	-2	2	0	0	7.794557119032869	
i 1	278.24237414965984	0.2525	72	698	2	1	16	2	0	1	2	0	0	7.794557119032869	
i 1	278.2431768707483	0.505	74	1084	5	9	8	16	0	1	16	0	0	3.0	
i 1	278.24478231292517	2.02	74	200	4	3	8	17	0	1	17	0	0	4.0	
i 1	278.24478231292517	0.2525	71	1084	4	5	3	2	0	-2	2	0	0	9.948905943535717	
i 1	278.24959863945577	1.2625	76	1084	2	20	9	17	0	2	17	0	0	3.336144960550463	
i 1	278.2568231292517	0.505	71	1084	4	5	5	2	0	-1	2	0	0	9.948905943535717	
i 1	278.48274149659863	0.505	72	698	2	24	11	2	0	-2	2	0	0	8.79455711903287	
i 1	278.4891632653061	0.2525	73	698	3	20	13	16	0	2	16	0	0	3.336144960550463	
i 1	278.4979931972789	0.2525	71	698	3	5	15	2	0	-1	2	0	0	9.948905943535717	
i 1	278.50842857142857	0.2525	74	1084	5	9	11	17	0	2	17	0	0	3.0	
i 1	278.50842857142857	0.2525	73	698	3	20	12	16	0	2	16	0	0	3.336144960550463	
i 1	278.51886394557823	1.01	75	200	6	1	2	2	0	1	2	0	0	7.794557119032869	
i 1	278.7471904761905	0.7575000000000001	73	1084	2	20	6	16	0	2	16	0	0	3.336144960550463	
i 1	278.75842857142857	0.2525	74	200	5	4	13	16	0	2	16	0	0	4.0	
i 1	278.75923129251703	0.2525	73	1084	2	20	12	17	0	2	17	0	0	3.336144960550463	
i 1	278.75923129251703	1.5150000000000001	73	698	1	24	5	17	0	252	17	307	0	7.336144960550463	
i 1	278.7608367346939	2.02	74	698	4	5	3	2	0	-1	2	0	0	9.948905943535717	
i 1	278.76324489795917	0.2525	72	698	5	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	278.76485034013604	0.2525	74	698	5	3	16	16	0	1	16	0	0	4.0	
i 1	278.99558503401363	0.2525	71	200	7	5	3	8	0	-2	8	0	0	9.948905943535717	
i 1	279.01003401360543	0.2525	72	200	5	24	9	8	0	-2	8	0	0	8.79455711903287	
i 1	279.0116394557823	0.2525	75	1084	5	1	9	2	0	-2	2	0	0	7.794557119032869	
i 1	279.2391632653061	0.2525	74	1084	5	9	9	17	0	2	17	0	0	3.0	
i 1	279.24879591836736	1.01	76	698	1	20	14	16	0	2	16	0	0	3.336144960550463	
i 1	279.25842857142857	0.2525	74	698	5	3	16	16	0	1	16	0	0	4.0	
i 1	279.26244217687076	0.505	71	1084	4	5	12	2	0	-2	2	0	0	9.948905943535717	
i 1	279.2696666666667	2.02	72	698	5	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	279.48996598639457	2.02	61	698	6	17	1	1	0	1	1	0	0	3.506464741742853	
i 1	279.50361224489797	2.02	61	698	5	13	15	1	0	1	1	0	0	0.16369957879808614	
i 1	279.50441496598637	0.7575000000000001	73	698	1	20	11	17	0	2	17	0	0	3.336144960550463	
i 1	279.5116394557823	0.505	74	698	4	2	3	17	0	2	17	0	0	4.0	
i 1	279.51244217687076	2.02	63	698	3	27	10	1	0	2	1	0	0	12.738040549334222	
i 1	279.7391632653061	1.5150000000000001	74	200	4	4	13	16	0	2	16	0	0	4.0	
i 1	279.74157142857143	0.2525	75	1084	5	1	11	2	0	-2	2	0	0	7.794557119032869	
i 1	279.7479931972789	0.2525	71	200	7	5	15	8	0	-2	8	0	0	9.948905943535717	
i 1	279.7616394557823	0.7575000000000001	72	1084	5	1	2	8	0	-2	8	0	0	7.794557119032869	
i 1	279.76725850340137	0.2525	71	200	7	5	4	2	0	-1	2	0	0	9.948905943535717	
i 1	279.98755782312924	0.2525	71	698	3	5	3	8	0	-1	8	0	0	9.948905943535717	
i 1	280.0156530612245	0.2525	71	1084	6	5	8	2	0	-1	2	0	0	9.948905943535717	
i 1	280.2391632653061	0.2525	74	698	4	5	6	2	0	-2	2	0	0	9.948905943535717	
i 1	280.24076870748297	0.2525	74	1084	5	9	7	17	0	2	17	0	0	3.0	
i 1	280.24397959183676	0.2525	76	200	3	20	11	16	0	2	16	0	0	3.336144960550463	
i 1	280.24397959183676	0.505	76	698	1	24	2	17	0	2	17	0	0	7.336144960550463	
i 1	280.25361224489797	0.2525	73	1084	2	24	13	17	0	1	17	0	0	7.336144960550463	
i 1	280.48514965986396	0.2525	72	698	2	1	13	2	0	1	2	0	0	7.794557119032869	
i 1	280.4883605442177	1.01	73	1084	2	20	8	16	0	1	16	0	0	3.336144960550463	
i 1	280.4931768707483	0.2525	75	1084	5	1	15	2	0	-2	2	0	0	7.794557119032869	
i 1	280.5028095238095	0.505	74	698	5	3	14	16	0	1	16	0	0	4.0	
i 1	280.51003401360543	0.2525	74	698	4	2	12	17	0	2	17	0	0	4.0	
i 1	280.5116394557823	1.01	71	200	7	5	11	8	0	-2	8	0	0	9.948905943535717	
i 1	280.51324489795917	0.2525	73	698	1	20	8	16	0	1	16	0	0	3.336144960550463	
i 1	280.5156530612245	1.01	76	1084	2	20	10	17	0	2	17	0	0	3.336144960550463	
i 1	280.74638775510203	0.7575000000000001	72	200	5	24	6	8	0	-2	8	0	0	8.79455711903287	
i 1	280.7471904761905	0.505	73	698	1	20	2	17	0	2	17	0	0	3.336144960550463	
i 1	280.7656530612245	0.2525	74	698	4	5	3	2	0	-2	2	0	0	9.948905943535717	
i 1	280.98675510204083	0.2525	71	698	3	5	10	8	0	-1	8	0	0	9.948905943535717	
i 1	280.99076870748297	0.505	71	698	3	5	8	2	0	-1	2	0	0	9.948905943535717	
i 1	281.0028095238095	0.505	74	200	4	3	1	17	0	1	17	0	0	4.0	
i 1	281.00923129251703	0.2525	74	1084	5	9	3	17	0	2	17	0	0	3.0	
i 1	281.01886394557823	0.2525	75	200	5	1	14	2	0	1	2	0	0	7.794557119032869	
i 1	281.23755782312924	0.2525	74	698	5	3	9	16	0	1	16	0	0	4.0	
i 1	281.2568231292517	0.2525	72	698	2	1	6	2	0	1	2	0	0	7.794557119032869	
i 1	281.4803333333333	1.01	75	904	5	1	9	2	0	1	2	0	0	7.794557119032869	
i 1	281.48113605442177	4.04	61	202	5	18	5	16	0	1	16	0	0	3.506464741742853	
i 1	281.48514965986396	4.04	61	202	4	27	14	16	0	1	16	0	0	12.738040549334222	
i 1	281.48595238095237	0.7575000000000001	73	202	3	20	8	16	0	2	16	0	0	3.336144960550463	
i 1	281.49157142857143	4.04	61	202	4	19	4	16	0	1	16	0	0	3.506464741742853	
i 1	281.49397959183676	4.04	63	904	5	14	5	16	0	1	16	0	0	2.551638712202796	
i 1	281.49397959183676	0.505	74	904	4	5	4	2	0	-1	2	0	0	9.948905943535717	
i 1	281.49558503401363	4.04	63	202	5	18	1	1	0	1	1	0	0	3.506464741742853	
i 1	281.4971904761905	0.2525	74	202	5	4	2	16	0	1	16	0	0	4.0	
i 1	281.49879591836736	2.02	74	588	4	3	8	16	0	1	16	0	0	4.0	
i 1	281.50120408163264	4.04	61	202	4	19	7	1	0	1	1	0	0	3.506464741742853	
i 1	281.50602040816324	4.04	63	202	5	26	3	1	0	2	1	0	0	0.39147284124284637	
i 1	281.50762585034016	0.2525	74	588	6	5	15	8	0	-2	8	0	0	9.948905943535717	
i 1	281.50842857142857	0.2525	74	904	4	2	2	17	0	2	17	0	0	4.0	
i 1	281.50842857142857	4.04	61	904	6	17	13	16	0	2	16	0	0	3.506464741742853	
i 1	281.50923129251703	4.04	61	202	4	27	9	1	0	1	1	0	0	12.738040549334222	
i 1	281.51003401360543	1.01	61	202	5	26	14	16	0	2	16	0	0	0.39147284124284637	
i 1	281.5108367346939	4.04	63	588	5	17	6	1	0	1	1	0	0	3.506464741742853	
i 1	281.5116394557823	4.04	61	904	5	13	14	16	0	1	16	0	0	0.16369957879808614	
i 1	281.51244217687076	4.04	63	904	6	17	6	16	0	1	16	0	0	3.506464741742853	
i 1	281.51404761904763	3.0300000000000002	74	588	6	5	4	8	0	-2	8	0	0	9.948905943535717	
i 1	281.51725850340137	1.01	63	588	5	17	9	16	0	2	16	0	0	3.506464741742853	
i 1	281.51806122448977	0.7575000000000001	76	202	3	20	10	17	0	1	17	0	0	3.336144960550463	
i 1	281.74558503401363	0.2525	76	202	2	24	1	17	0	1	17	0	0	7.336144960550463	
i 1	281.9931768707483	5.3025	76	202	1	24	9	17	0	252	17	307	0	7.336144960550463	
i 1	281.99959863945577	0.505	77	202	6	9	16	17	0	1	17	0	0	3.0	
i 1	282.00361224489797	0.505	75	202	6	1	13	2	0	-2	2	0	0	7.794557119032869	
i 1	282.01485034013604	0.2525	75	904	5	1	8	2	0	1	2	0	0	7.794557119032869	
i 1	282.0196666666667	0.2525	74	588	6	5	2	8	0	-2	8	0	0	9.948905943535717	
i 1	282.23514965986396	0.2525	73	202	3	20	2	17	0	2	17	0	0	3.336144960550463	
i 1	282.23996598639457	0.2525	74	202	6	3	9	16	0	2	16	0	0	4.0	
i 1	282.24638775510203	0.2525	76	202	3	24	5	16	0	1	16	0	0	7.336144960550463	
i 1	282.25602040816324	0.2525	71	202	7	5	14	2	0	-1	2	0	0	9.948905943535717	
i 1	282.4803333333333	0.7575000000000001	73	202	3	20	3	16	0	2	16	0	0	3.336144960550463	
i 1	282.4835442176871	0.2525	71	202	7	5	15	2	0	-1	2	0	0	9.948905943535717	
i 1	282.49157142857143	0.2525	72	588	4	24	7	2	0	-2	2	0	0	8.79455711903287	
i 1	282.49397959183676	0.2525	77	904	4	2	13	16	0	2	16	0	0	4.0	
i 1	282.49638775510203	3.0300000000000002	63	588	6	17	15	16	0	2	16	0	0	3.506464741742853	
i 1	282.4971904761905	0.7575000000000001	75	904	6	1	2	2	0	1	2	0	0	7.794557119032869	
i 1	282.4971904761905	3.0300000000000002	63	588	5	15	6	1	0	2	1	0	0	0.9596792899329893	
i 1	282.4971904761905	0.505	71	202	4	5	5	8	0	-1	8	0	0	9.948905943535717	
i 1	282.51003401360543	0.2525	74	904	4	2	1	17	0	2	17	0	0	4.0	
i 1	282.5116394557823	0.505	76	202	3	20	3	17	0	1	17	0	0	3.336144960550463	
i 1	282.7431768707483	1.2625	72	588	5	1	11	2	0	1	2	0	0	7.794557119032869	
i 1	282.74959863945577	0.2525	76	202	2	20	12	17	0	2	17	0	0	3.336144960550463	
i 1	282.7528095238095	0.7575000000000001	73	202	2	20	4	16	0	2	16	0	0	3.336144960550463	
i 1	282.7568231292517	0.2525	74	202	5	4	2	16	0	1	16	0	0	4.0	
i 1	282.9891632653061	0.505	71	904	4	5	15	2	0	-1	2	0	0	9.948905943535717	
i 1	282.99237414965984	1.5150000000000001	74	588	4	4	16	17	0	2	17	0	0	4.0	
i 1	283.00361224489797	0.2525	76	588	3	20	8	16	0	1	16	0	0	3.336144960550463	
i 1	283.2391632653061	0.505	74	904	4	2	14	17	0	2	17	0	0	4.0	
i 1	283.25120408163264	0.2525	74	588	4	5	9	8	0	-2	8	0	0	9.948905943535717	
i 1	283.26003401360543	0.2525	73	202	2	24	8	16	0	2	16	0	0	7.336144960550463	
i 1	283.26324489795917	0.505	75	202	6	1	12	2	0	-2	2	0	0	7.794557119032869	
i 1	283.49237414965984	0.2525	71	202	7	5	16	2	0	-1	2	0	0	9.948905943535717	
i 1	283.49558503401363	0.2525	71	202	7	5	8	2	0	-1	2	0	0	9.948905943535717	
i 1	283.49879591836736	1.7675	73	202	3	20	15	16	0	2	16	0	0	3.336144960550463	
i 1	283.50762585034016	1.7675	73	202	3	20	5	17	0	1	17	0	0	3.336144960550463	
i 1	283.73996598639457	0.2525	74	202	5	4	10	16	0	1	16	0	0	4.0	
i 1	283.76324489795917	0.2525	72	202	3	24	14	2	0	1	2	0	0	8.79455711903287	
i 1	283.76324489795917	0.2525	74	904	4	5	8	2	0	-1	2	0	0	9.948905943535717	
i 1	283.98675510204083	0.2525	74	904	4	2	6	17	0	2	17	0	0	4.0	
i 1	283.98755782312924	1.01	75	904	6	1	14	2	0	1	2	0	0	7.794557119032869	
i 1	284.01404761904763	0.7575000000000001	75	904	5	1	7	2	0	1	2	0	0	7.794557119032869	
i 1	284.23514965986396	0.2525	74	202	4	5	12	2	0	-1	2	0	0	9.948905943535717	
i 1	284.48113605442177	0.2525	71	202	7	5	2	2	0	-1	2	0	0	9.948905943535717	
i 1	284.49237414965984	1.2625	74	904	4	2	9	17	0	2	17	0	0	4.0	
i 1	284.49478231292517	0.2525	72	202	3	24	10	2	0	1	2	0	0	8.79455711903287	
i 1	284.51485034013604	1.01	71	904	4	5	5	2	0	-1	2	0	0	9.948905943535717	
i 1	284.76244217687076	0.2525	72	588	4	24	2	2	0	-2	2	0	0	8.79455711903287	
i 1	284.9931768707483	0.505	74	202	4	5	10	2	0	-1	2	0	0	9.948905943535717	
i 1	285.0116394557823	0.505	75	904	5	1	1	2	0	1	2	0	0	7.794557119032869	
i 1	285.0156530612245	0.505	72	588	5	1	16	2	0	1	2	0	0	7.794557119032869	
i 1	285.2335442176871	0.2525	72	202	6	1	13	2	0	-2	2	0	0	7.794557119032869	
i 1	285.23675510204083	0.505	73	202	3	20	16	17	0	1	17	0	0	3.336144960550463	
i 1	285.26404761904763	0.505	76	202	3	24	3	16	0	1	16	0	0	7.336144960550463	
i 1	285.4803333333333	0.2525	73	202	2	20	16	16	0	2	16	0	0	3.336144960550463	
i 1	285.48193877551023	5.8075	63	904	6	17	13	16	0	1	16	0	0	3.5064647417428527	
i 1	285.48514965986396	5.8075	63	588	6	17	10	16	0	2	16	0	0	3.5064647417428527	
i 1	285.4891632653061	0.2525	75	904	6	1	9	2	0	1	2	0	0	7.72388007207531	
i 1	285.49076870748297	3.0300000000000002	61	202	5	18	1	16	0	1	16	0	0	3.5064647417428527	
i 1	285.49237414965984	5.8075	63	588	5	15	10	1	0	2	1	0	0	0.7950005952107598	
i 1	285.49638775510203	3.0300000000000002	61	202	4	27	12	1	0	1	1	0	0	12.802460130804567	
i 1	285.4979931972789	0.2525	72	202	5	24	7	2	0	1	2	0	0	8.72388007207531	
i 1	285.4979931972789	5.8075	63	202	5	18	3	1	0	1	1	0	0	3.5064647417428527	
i 1	285.49879591836736	5.8075	61	588	5	15	12	1	0	2	1	0	0	0.7950005952107598	
i 1	285.50361224489797	4.04	71	904	4	5	1	2	0	-1	2	0	0	11.606964696238188	
i 1	285.50361224489797	0.2525	73	202	3	20	7	16	0	2	16	0	0	3.336144960550463	
i 1	285.50602040816324	0.7575000000000001	73	202	2	20	13	16	0	2	16	0	0	3.336144960550463	
i 1	285.50842857142857	5.8075	63	588	6	17	4	1	0	1	1	0	0	3.5064647417428527	
i 1	285.50923129251703	1.5150000000000001	77	904	4	2	5	16	0	2	16	0	0	4.0	
i 1	285.51003401360543	2.02	72	588	5	1	3	2	0	1	2	0	0	7.72388007207531	
i 1	285.51003401360543	5.8075	61	202	4	19	12	1	0	1	1	0	0	3.5064647417428527	
i 1	285.5116394557823	5.8075	61	202	4	19	2	16	0	1	16	0	0	3.5064647417428527	
i 1	285.51725850340137	0.2525	73	202	3	20	10	17	0	1	17	0	0	3.336144960550463	
i 1	285.51806122448977	5.8075	63	904	5	14	11	16	0	1	16	0	0	2.386960017480566	
i 1	285.51886394557823	5.8075	61	202	4	27	2	16	0	1	16	0	0	12.802460130804567	
i 1	285.5196666666667	5.8075	61	904	6	17	3	16	0	2	16	0	0	3.5064647417428527	
i 1	285.73193877551023	0.2525	74	588	4	4	9	17	0	2	17	0	0	4.0	
i 1	285.73675510204083	0.505	74	202	6	3	16	16	0	2	16	0	0	4.0	
i 1	285.75441496598637	0.2525	73	588	3	20	7	17	0	2	17	0	0	3.336144960550463	
i 1	286.0020068027211	0.7575000000000001	71	202	7	5	14	8	0	-1	8	0	0	11.606964696238188	
i 1	286.00842857142857	0.2525	76	202	2	24	2	16	0	2	16	0	0	7.336144960550463	
i 1	286.23193877551023	0.2525	74	588	4	3	2	16	0	1	16	0	0	4.0	
i 1	286.23675510204083	1.2625	73	202	3	20	11	16	0	2	16	0	0	3.336144960550463	
i 1	286.24558503401363	0.7575000000000001	73	202	3	20	1	17	0	1	17	0	0	3.336144960550463	
i 1	286.25040136054423	0.2525	74	588	4	5	1	8	0	-2	8	0	0	11.606964696238188	
i 1	286.25441496598637	0.2525	72	202	6	1	11	2	0	-2	2	0	0	7.72388007207531	
i 1	286.48514965986396	0.2525	77	202	4	9	13	17	0	1	17	0	0	3.0	
i 1	286.51324489795917	0.505	75	904	6	1	16	2	0	1	2	0	0	7.72388007207531	
i 1	286.73755782312924	0.2525	71	202	7	5	15	2	0	-1	2	0	0	11.606964696238188	
i 1	286.73996598639457	3.535	74	588	4	3	14	16	0	1	16	0	0	4.0	
i 1	286.74397959183676	1.2625	75	202	5	1	10	2	0	-2	2	0	0	7.72388007207531	
i 1	286.75441496598637	0.2525	76	202	2	24	7	16	0	2	16	0	0	7.336144960550463	
i 1	286.9835442176871	0.2525	77	202	4	9	10	17	0	1	17	0	0	3.0	
i 1	286.9883605442177	0.2525	73	904	3	20	8	16	0	1	16	0	0	3.336144960550463	
i 1	287.00762585034016	0.2525	74	588	4	5	8	8	0	-2	8	0	0	11.606964696238188	
i 1	287.23113605442177	0.2525	74	904	4	2	11	17	0	2	17	0	0	4.0	
i 1	287.2343469387755	0.2525	76	202	3	24	14	16	0	1	16	0	0	7.336144960550463	
i 1	287.23996598639457	1.7675	72	588	4	24	10	2	0	-2	2	0	0	8.72388007207531	
i 1	287.24237414965984	0.7575000000000001	73	202	2	20	11	16	0	1	16	0	0	3.336144960550463	
i 1	287.2528095238095	0.2525	76	202	3	20	14	17	0	1	17	0	0	3.336144960550463	
i 1	287.26324489795917	0.7575000000000001	76	202	2	24	5	17	0	1	17	0	0	7.336144960550463	
i 1	287.5116394557823	0.2525	74	588	4	5	4	8	0	-2	8	0	0	11.606964696238188	
i 1	287.51806122448977	0.505	74	904	4	5	6	2	0	-1	2	0	0	11.606964696238188	
i 1	287.98113605442177	0.2525	76	202	3	24	11	16	0	1	16	0	0	7.336144960550463	
i 1	288.0108367346939	0.2525	72	202	6	1	4	2	0	-2	2	0	0	7.72388007207531	
i 1	288.01324489795917	0.2525	73	588	3	24	9	16	0	1	16	0	0	7.336144960550463	
i 1	288.01806122448977	0.2525	74	588	4	5	1	8	0	-2	8	0	0	11.606964696238188	
i 1	288.23595238095237	0.2525	73	202	3	20	12	16	0	2	16	0	0	3.336144960550463	
i 1	288.24879591836736	0.2525	71	202	7	5	7	2	0	-1	2	0	0	11.606964696238188	
i 1	288.26485034013604	0.2525	76	202	3	20	14	16	0	2	16	0	0	3.336144960550463	
i 1	288.2664557823129	0.505	75	202	5	1	6	2	0	-2	2	0	0	7.72388007207531	
i 1	288.48595238095237	2.7775	61	202	5	18	11	16	0	1	16	0	0	3.5064647417428527	
i 1	288.50361224489797	2.7775	63	202	5	16	5	1	0	1	1	0	0	1.5909803063456631	
i 1	288.7391632653061	0.2525	72	202	5	1	6	2	0	1	2	0	0	7.72388007207531	
i 1	288.74397959183676	0.2525	73	202	2	20	4	17	0	1	17	0	0	6.439844327211144	
i 1	288.7656530612245	0.2525	76	202	2	24	9	17	0	1	17	0	0	10.439844327211144	
i 1	288.9803333333333	1.7675	76	202	1	24	12	17	0	252	17	307	0	10.439844327211144	
i 1	288.98274149659863	0.2525	75	904	6	1	16	2	0	1	2	0	0	7.72388007207531	
i 1	288.98595238095237	1.01	72	588	6	1	8	2	0	1	2	0	0	7.72388007207531	
i 1	288.9931768707483	0.7575000000000001	73	202	3	20	12	16	0	2	16	0	0	6.439844327211144	
i 1	289.00361224489797	0.2525	77	904	6	2	5	16	0	2	16	0	0	4.0	
i 1	289.01244217687076	0.7575000000000001	76	202	3	20	8	17	0	1	17	0	0	6.439844327211144	
i 1	289.24879591836736	0.505	74	588	4	4	8	17	0	2	17	0	0	4.0	
i 1	289.5068231292517	1.7675	74	588	4	5	6	8	0	-2	8	0	0	11.606964696238188	
i 1	289.5116394557823	0.2525	71	202	7	5	15	2	0	-1	2	0	0	11.606964696238188	
i 1	289.73113605442177	0.505	74	202	7	5	16	2	0	-1	2	0	0	11.606964696238188	
i 1	289.73755782312924	0.2525	72	588	4	24	15	2	0	-2	2	0	0	8.72388007207531	
i 1	289.74157142857143	0.2525	77	904	6	2	9	16	0	2	16	0	0	4.0	
i 1	289.75923129251703	1.01	73	202	2	20	9	16	0	2	16	0	0	6.439844327211144	
i 1	289.7696666666667	1.01	73	202	2	24	11	16	0	2	16	0	0	10.439844327211144	
i 1	289.98675510204083	1.01	75	904	6	1	12	2	0	1	2	0	0	7.72388007207531	
i 1	290.00361224489797	0.2525	74	202	4	9	9	17	0	1	17	0	0	3.0	
i 1	290.23755782312924	0.2525	75	202	5	1	16	2	0	-2	2	0	0	7.72388007207531	
i 1	290.26404761904763	1.01	77	904	6	2	4	16	0	2	16	0	0	4.0	
i 1	290.26725850340137	0.2525	71	904	4	5	9	2	0	-1	2	0	0	11.606964696238188	
i 1	290.4803333333333	0.2525	72	202	5	1	4	2	0	1	2	0	0	7.72388007207531	
i 1	290.50842857142857	0.2525	74	202	3	3	8	16	0	2	16	0	0	4.0	
i 1	290.51485034013604	0.505	71	202	7	5	3	2	0	-1	2	0	0	11.606964696238188	
i 1	290.74397959183676	0.505	76	202	2	24	5	17	0	1	17	0	0	10.439844327211144	
i 1	290.75521768707483	0.505	76	904	3	20	5	17	0	2	17	0	0	6.439844327211144	
i 1	290.7568231292517	0.505	74	202	4	9	8	17	0	1	17	0	0	3.0	
i 1	290.7616394557823	0.505	72	202	5	1	5	2	0	-2	2	0	0	7.72388007207531	
i 1	290.99478231292517	0.2525	74	588	4	5	13	8	0	-2	8	0	0	11.606964696238188	
i 1	291.00842857142857	0.2525	72	588	6	1	14	2	0	1	2	0	0	7.72388007207531	
i 1	291.23193877551023	2.525	66	199	7	17	8	9	0	1	9	0	0	3.506464741742853	
i 1	291.23274149659863	12.625	66	1083	4	18	11	9	0	1	9	0	0	3.506464741742853	
i 1	291.23274149659863	2.525	70	1083	3	20	5	2	0	-1	2	0	0	7.892101242005808	
i 1	291.23514965986396	2.02	72	697	5	1	10	1	5001	-1	1	0	0	10.464552728185682	
i 1	291.23514965986396	11.615	61	1083	4	18	5	6	0	1	6	0	0	3.506464741742853	
i 1	291.23595238095237	2.525	66	199	4	14	7	6	0	1	6	0	0	10.42212433883081	
i 1	291.23675510204083	0.7575000000000001	69	697	4	24	14	0	0	0	0	0	0	11.464552728185682	
i 1	291.24157142857143	5.05	75	697	5	3	14	2	5001	1	2	0	0	4.0	
i 1	291.24157142857143	2.525	66	697	3	27	6	6	0	1	6	0	0	12.373384909427449	
i 1	291.24237414965984	0.505	77	697	6	5	1	16	5001	2	16	0	0	10.164563645893459	
i 1	291.2431768707483	0.2525	69	697	4	24	15	0	5001	-1	0	0	0	11.464552728185682	
i 1	291.24558503401363	2.525	61	199	7	17	10	9	0	2	9	0	0	3.506464741742853	
i 1	291.2471904761905	1.2625	72	199	7	2	11	8	0	1	8	0	0	4.0	
i 1	291.2471904761905	0.2525	77	697	6	5	2	17	0	1	17	0	0	10.164563645893459	
i 1	291.2471904761905	5.555	66	697	3	13	13	6	5001	1	6	0	0	6.513827711769256	
i 1	291.24879591836736	1.7675	73	1083	3	20	13	8	0	-2	8	0	0	7.892101242005808	
i 1	291.2520068027211	1.01	72	697	4	4	15	8	5001	-2	8	0	0	4.0	
i 1	291.2528095238095	12.625	61	199	6	14	9	6	0	1	6	0	0	10.42212433883081	
i 1	291.2568231292517	12.625	66	697	1	27	8	9	0	252	9	307	0	12.373384909427449	
i 1	291.2568231292517	0.2525	70	1083	3	24	15	2	0	-1	2	0	0	11.892101242005808	
i 1	291.25842857142857	0.2525	73	697	2	24	8	8	5001	-2	8	0	0	11.892101242005808	
i 1	291.25923129251703	8.585	61	697	4	7	2	6	5001	2	6	0	0	9.11935879647696	
i 1	291.26003401360543	12.625	61	697	4	19	8	9	0	2	9	0	0	3.506464741742853	
i 1	291.26324489795917	12.625	61	697	4	19	4	6	0	2	6	0	0	3.506464741742853	
i 1	291.26324489795917	3.0300000000000002	77	697	6	5	11	16	5001	2	16	0	0	10.164563645893459	
i 1	291.2664557823129	8.585	66	697	6	17	14	9	5001	2	9	0	0	3.506464741742853	
i 1	291.26806122448977	5.555	61	697	6	17	9	6	5001	1	6	0	0	3.506464741742853	
i 1	291.26886394557823	0.2525	77	199	7	5	4	17	0	2	17	0	0	10.164563645893459	
i 1	291.50120408163264	0.2525	72	1083	5	1	12	1	0	-1	1	0	0	10.464552728185682	
i 1	291.51003401360543	0.2525	75	1083	5	9	6	2	0	-2	2	0	0	3.0	
i 1	291.75923129251703	1.01	77	199	7	5	13	17	0	2	17	0	0	10.164563645893459	
i 1	291.76003401360543	0.2525	72	199	7	1	9	0	0	-1	0	0	0	10.464552728185682	
i 1	291.98595238095237	0.2525	74	1083	6	5	10	17	0	2	17	0	0	10.164563645893459	
i 1	291.99638775510203	0.7575000000000001	69	199	7	1	15	1	0	0	1	0	0	10.464552728185682	
i 1	292.00842857142857	0.2525	72	1083	5	9	9	2	0	-2	2	0	0	3.0	
i 1	292.23996598639457	0.2525	73	1083	3	20	15	2	0	-1	2	0	0	7.892101242005808	
i 1	292.24237414965984	0.2525	73	697	2	24	12	8	5001	-2	8	0	0	11.892101242005808	
i 1	292.25120408163264	0.2525	75	1083	5	9	2	2	0	-2	2	0	0	3.0	
i 1	292.25762585034016	1.01	77	1083	6	5	5	17	0	1	17	0	0	10.164563645893459	
i 1	292.4835442176871	1.2625	69	697	4	24	4	0	5001	-1	0	0	0	11.464552728185682	
i 1	292.4891632653061	1.01	73	697	2	24	12	2	0	-1	2	0	0	11.892101242005808	
i 1	292.49959863945577	0.7575000000000001	70	697	2	20	4	2	5001	-2	2	0	0	7.892101242005808	
i 1	292.5028095238095	0.2525	72	1083	5	1	4	1	0	-1	1	0	0	10.464552728185682	
i 1	292.51244217687076	0.2525	77	697	6	5	3	16	5001	2	16	0	0	10.164563645893459	
i 1	292.74478231292517	0.2525	74	199	7	5	15	17	0	1	17	0	0	10.164563645893459	
i 1	292.74879591836736	1.01	69	697	4	24	3	0	0	0	0	0	0	11.464552728185682	
i 1	293.0020068027211	0.2525	73	1083	3	20	6	2	0	-1	2	0	0	7.892101242005808	
i 1	293.2303333333333	0.2525	72	1083	5	1	11	1	0	-1	1	0	0	10.464552728185682	
i 1	293.2335442176871	0.505	73	697	2	20	14	2	0	-2	2	0	0	7.892101242005808	
i 1	293.23595238095237	0.2525	73	697	4	24	15	8	5001	-2	8	0	0	11.892101242005808	
i 1	293.24558503401363	0.2525	70	697	4	20	13	2	5001	-2	2	0	0	7.892101242005808	
i 1	293.2528095238095	0.505	72	1083	5	9	16	2	0	-2	2	0	0	3.0	
i 1	293.25361224489797	0.2525	73	199	4	20	10	2	0	-2	2	0	0	7.892101242005808	
i 1	293.26324489795917	0.2525	72	199	7	2	6	8	0	1	8	0	0	4.0	
i 1	293.48193877551023	0.2525	69	1083	5	1	1	0	0	0	0	0	0	10.464552728185682	
i 1	293.5068231292517	1.7675	72	697	4	4	11	8	5001	-2	8	0	0	4.0	
i 1	293.5108367346939	0.7575000000000001	77	1083	6	5	10	17	0	1	17	0	0	10.164563645893459	
i 1	293.73514965986396	1.7675	74	199	6	5	16	17	0	1	17	0	0	10.164563645893459	
i 1	293.74237414965984	10.1	66	697	1	27	3	6	0	252	6	307	0	12.373384909427449	
i 1	293.74397959183676	1.01	69	697	4	24	7	0	5001	-1	0	0	0	11.464552728185682	
i 1	293.74879591836736	10.1	66	199	6	14	9	6	0	1	6	0	0	10.42212433883081	
i 1	293.7568231292517	0.2525	72	697	4	4	10	8	0	-2	8	0	0	4.0	
i 1	293.7616394557823	1.01	73	697	2	24	7	8	5001	-2	8	0	0	9.616285980919738	
i 1	293.76404761904763	1.01	73	697	2	20	12	2	0	-2	2	0	0	5.616285980919738	
i 1	293.76485034013604	2.02	72	697	6	1	16	1	5001	-1	1	0	0	10.464552728185682	
i 1	293.7696666666667	3.0300000000000002	61	199	7	17	11	9	0	2	9	0	0	3.506464741742853	
i 1	293.99638775510203	0.2525	72	199	7	2	12	8	0	1	8	0	0	4.0	
i 1	293.99879591836736	0.2525	75	697	5	3	15	2	0	1	2	0	0	4.0	
i 1	294.0068231292517	0.2525	70	1083	3	24	8	2	0	-1	2	0	0	9.616285980919738	
i 1	294.24076870748297	0.2525	69	697	4	24	1	0	0	0	0	0	0	11.464552728185682	
i 1	294.24638775510203	0.7575000000000001	77	697	6	5	16	17	0	1	17	0	0	10.164563645893459	
i 1	294.25762585034016	2.02	73	697	2	24	2	2	0	-1	2	0	0	9.616285980919738	
i 1	294.26886394557823	1.7675	70	697	2	20	14	2	5001	-2	2	0	0	5.616285980919738	
i 1	294.49638775510203	0.505	69	1083	5	1	16	0	0	0	0	0	0	10.464552728185682	
i 1	294.49879591836736	0.2525	75	697	5	3	1	2	0	1	2	0	0	4.0	
i 1	294.74478231292517	2.02	69	199	6	1	12	1	0	0	1	0	0	10.464552728185682	
i 1	294.74638775510203	0.505	70	1083	3	20	9	8	0	-1	8	0	0	5.616285980919738	
i 1	294.7471904761905	0.7575000000000001	72	1083	5	9	13	2	0	-2	2	0	0	3.0	
i 1	295.00120408163264	0.2525	70	1083	3	20	7	2	0	-1	2	0	0	5.616285980919738	
i 1	295.0068231292517	0.2525	69	697	4	24	16	0	0	0	0	0	0	11.464552728185682	
i 1	295.01806122448977	0.2525	72	199	7	2	6	8	0	1	8	0	0	4.0	
i 1	295.0196666666667	1.5150000000000001	77	697	6	5	9	16	5001	2	16	0	0	10.164563645893459	
i 1	295.2391632653061	0.505	69	697	4	24	7	0	5001	-1	0	0	0	11.464552728185682	
i 1	295.24638775510203	0.2525	70	1083	3	24	10	2	0	-1	2	0	0	9.616285980919738	
i 1	295.24959863945577	0.505	75	199	7	2	8	2	0	-2	2	0	0	4.0	
i 1	295.50040136054423	0.2525	73	1083	3	20	14	2	0	-2	2	0	0	5.616285980919738	
i 1	295.50923129251703	0.2525	75	1083	5	9	4	2	0	-2	2	0	0	3.0	
i 1	295.73193877551023	0.2525	72	697	4	4	13	8	5001	-2	8	0	0	4.0	
i 1	295.75040136054423	0.7575000000000001	73	697	2	20	2	2	0	-2	2	0	0	5.616285980919738	
i 1	295.7520068027211	3.0300000000000002	72	199	7	2	2	8	0	1	8	0	0	4.0	
i 1	295.76886394557823	0.2525	69	697	4	1	1	1	0	0	1	0	0	10.464552728185682	
i 1	295.9891632653061	0.505	75	199	7	2	2	2	0	-2	2	0	0	4.0	
i 1	295.9979931972789	5.05	77	697	6	5	6	16	5001	2	16	0	0	10.164563645893459	
i 1	296.0116394557823	0.2525	70	697	4	20	2	2	5001	-2	2	0	0	5.616285980919738	
i 1	296.01244217687076	1.7675	70	1083	3	24	15	2	0	-1	2	0	0	9.616285980919738	
i 1	296.01485034013604	2.2725	72	697	6	1	2	1	5001	-1	1	0	0	10.464552728185682	
i 1	296.0164557823129	0.2525	73	199	4	20	10	8	0	-1	8	0	0	5.616285980919738	
i 1	296.24397959183676	1.2625	70	1083	3	20	3	8	0	-2	8	0	0	5.616285980919738	
i 1	296.25040136054423	0.2525	69	1083	5	1	2	0	0	0	0	0	0	10.464552728185682	
i 1	296.2608367346939	0.2525	70	697	2	20	15	2	5001	-2	2	0	0	5.616285980919738	
i 1	296.48193877551023	0.7575000000000001	75	697	5	3	13	2	5001	1	2	0	0	4.0	
i 1	296.50923129251703	0.2525	72	697	4	4	8	8	0	-2	8	0	0	4.0	
i 1	296.5108367346939	0.2525	72	1083	5	1	9	1	0	-1	1	0	0	10.464552728185682	
i 1	296.5116394557823	0.7575000000000001	77	1083	6	5	12	17	0	1	17	0	0	10.164563645893459	
i 1	296.73274149659863	3.0300000000000002	61	697	6	17	8	6	5001	1	6	0	0	3.506464741742853	
i 1	296.7568231292517	12.625	66	697	5	13	4	6	5001	1	6	0	0	6.513827711769256	
i 1	296.75762585034016	0.2525	70	1083	3	20	14	2	0	-1	2	0	0	5.616285980919738	
i 1	296.75923129251703	0.2525	75	697	5	3	14	2	0	1	2	0	0	4.0	
i 1	297.0156530612245	0.2525	70	1083	3	20	15	2	0	-1	2	0	0	5.616285980919738	
i 1	297.2303333333333	0.2525	72	697	4	4	2	8	5001	-2	8	0	0	4.0	
i 1	297.24157142857143	1.01	77	199	6	5	7	17	0	2	17	0	0	10.164563645893459	
i 1	297.24237414965984	0.2525	75	1083	5	9	5	2	0	-2	2	0	0	3.0	
i 1	297.25441496598637	0.505	69	1083	5	1	9	0	0	0	0	0	0	10.464552728185682	
i 1	297.26485034013604	0.2525	69	199	6	1	7	1	0	0	1	0	0	10.464552728185682	
i 1	297.48274149659863	0.2525	73	697	4	24	5	8	5001	-2	8	0	0	9.616285980919738	
i 1	297.49638775510203	0.2525	73	697	2	20	6	2	0	-2	2	0	0	5.616285980919738	
i 1	297.49959863945577	0.505	72	1083	5	9	2	2	0	-2	2	0	0	3.0	
i 1	297.50441496598637	1.01	69	697	4	24	6	0	5001	-1	0	0	0	11.464552728185682	
i 1	297.50923129251703	0.2525	75	199	7	2	15	2	0	-2	2	0	0	4.0	
i 1	297.73113605442177	1.7675	73	697	2	24	15	2	0	-1	2	0	0	9.616285980919738	
i 1	297.74879591836736	0.2525	69	697	4	1	15	1	0	0	1	0	0	10.464552728185682	
i 1	297.76725850340137	1.5150000000000001	70	697	2	20	12	2	5001	-2	2	0	0	5.616285980919738	
i 1	297.98193877551023	1.7675	69	199	6	1	15	1	0	0	1	0	0	10.464552728185682	
i 1	297.98675510204083	0.2525	77	1083	6	5	2	17	0	1	17	0	0	10.164563645893459	
i 1	297.99397959183676	2.2725	72	697	4	4	14	8	5001	-2	8	0	0	4.0	
i 1	298.2431768707483	0.2525	69	1083	5	1	8	0	0	0	0	0	0	10.464552728185682	
i 1	298.24397959183676	0.2525	75	697	5	3	13	2	0	1	2	0	0	4.0	
i 1	298.25521768707483	1.01	73	1083	3	20	13	2	0	-2	2	0	0	5.616285980919738	
i 1	298.26244217687076	0.7575000000000001	70	1083	3	24	13	2	0	-1	2	0	0	9.616285980919738	
i 1	298.4883605442177	0.2525	72	1083	4	1	9	1	0	-1	1	0	0	10.464552728185682	
i 1	298.49076870748297	0.2525	74	1083	6	5	12	17	0	2	17	0	0	10.164563645893459	
i 1	298.4979931972789	0.2525	77	1083	6	5	13	17	0	1	17	0	0	10.164563645893459	
i 1	298.50762585034016	0.2525	72	199	6	1	11	0	0	-1	0	0	0	10.464552728185682	
i 1	298.51886394557823	0.505	75	199	7	2	7	2	0	-2	2	0	0	4.0	
i 1	298.73514965986396	0.2525	77	697	6	5	3	16	5001	2	16	0	0	10.164563645893459	
i 1	298.76244217687076	0.505	69	697	4	1	6	1	0	0	1	0	0	10.464552728185682	
i 1	298.76324489795917	0.505	72	697	4	4	10	8	0	-2	8	0	0	4.0	
i 1	298.76725850340137	0.2525	77	697	6	5	3	16	0	1	16	0	0	10.164563645893459	
i 1	298.9883605442177	0.2525	69	1083	5	1	8	0	0	0	0	0	0	10.464552728185682	
i 1	298.99478231292517	0.2525	72	199	7	2	10	8	0	1	8	0	0	4.0	
i 1	298.99558503401363	1.2625	77	199	6	5	13	17	0	2	17	0	0	10.164563645893459	
i 1	299.00602040816324	0.7575000000000001	70	1083	3	20	13	2	0	-1	2	0	0	5.616285980919738	
i 1	299.0156530612245	0.2525	77	697	6	5	16	17	0	1	17	0	0	10.164563645893459	
i 1	299.23755782312924	0.2525	75	697	5	3	6	2	5001	1	2	0	0	4.0	
i 1	299.24638775510203	0.2525	70	199	4	20	4	2	0	-1	2	0	0	5.616285980919738	
i 1	299.2528095238095	1.2625	70	1083	3	24	5	2	0	-1	2	0	0	9.616285980919738	
i 1	299.25602040816324	0.2525	70	697	4	20	2	2	5001	-2	2	0	0	5.616285980919738	
i 1	299.26244217687076	0.2525	72	1083	5	9	2	2	0	-2	2	0	0	3.0	
i 1	299.48996598639457	0.2525	69	1083	5	1	5	0	0	0	0	0	0	10.464552728185682	
i 1	299.49558503401363	0.2525	72	697	4	4	9	8	0	-2	8	0	0	4.0	
i 1	299.4979931972789	1.01	75	697	5	3	15	2	0	1	2	0	0	4.0	
i 1	299.51244217687076	0.2525	73	1083	3	20	11	8	0	-1	8	0	0	5.616285980919738	
i 1	299.5164557823129	0.2525	72	1083	4	1	11	1	0	-1	1	0	0	10.464552728185682	
i 1	299.51886394557823	0.2525	77	1083	6	5	14	17	0	1	17	0	0	10.164563645893459	
i 1	299.7303333333333	1.01	72	697	5	1	16	1	5001	-1	1	0	0	10.464552728185682	
i 1	299.73274149659863	3.0300000000000002	66	697	6	17	5	9	5001	2	9	0	0	3.506464741742853	
i 1	299.73595238095237	2.2725	69	697	4	24	2	0	5001	-1	0	0	0	11.464552728185682	
i 1	299.74638775510203	0.2525	77	697	6	5	12	17	0	1	17	0	0	10.164563645893459	
i 1	299.7471904761905	9.595	61	697	6	7	2	6	5001	2	6	0	0	9.11935879647696	
i 1	299.75361224489797	1.7675	75	697	5	3	9	2	5001	1	2	0	0	4.0	
i 1	299.9803333333333	0.505	72	199	6	1	7	0	0	-1	0	0	0	10.464552728185682	
i 1	300.0068231292517	0.2525	70	697	2	20	8	2	5001	-2	2	0	0	5.616285980919738	
i 1	300.00842857142857	1.01	73	697	2	20	14	2	0	-2	2	0	0	5.616285980919738	
i 1	300.24959863945577	0.505	75	1083	5	9	9	2	0	-2	2	0	0	3.0	
i 1	300.25361224489797	0.2525	73	199	2	20	7	2	0	-2	2	0	0	5.616285980919738	
i 1	300.2568231292517	0.2525	77	1083	6	5	8	17	0	1	17	0	0	10.164563645893459	
i 1	300.2608367346939	0.505	77	697	5	5	2	16	5001	2	16	0	0	10.164563645893459	
i 1	300.26485034013604	0.7575000000000001	70	697	4	20	4	2	5001	-2	2	0	0	5.616285980919738	
i 1	300.48996598639457	0.505	69	697	4	1	6	1	0	0	1	0	0	10.464552728185682	
i 1	300.49638775510203	3.0300000000000002	74	199	7	5	11	17	0	1	17	0	0	10.164563645893459	
i 1	300.4971904761905	0.505	72	697	4	4	10	8	0	-2	8	0	0	4.0	
i 1	300.75361224489797	0.2525	72	199	6	1	13	0	0	-1	0	0	0	10.464552728185682	
i 1	300.75842857142857	0.2525	70	1083	3	24	12	2	0	-1	2	0	0	9.616285980919738	
i 1	300.7696666666667	0.2525	75	697	5	3	16	2	0	1	2	0	0	4.0	
i 1	300.9835442176871	0.505	75	1083	5	9	16	2	0	-2	2	0	0	3.0	
i 1	300.98514965986396	0.7575000000000001	73	697	2	24	8	2	0	-1	2	0	0	9.616285980919738	
i 1	300.98595238095237	0.505	77	697	6	5	9	17	0	1	17	0	0	10.164563645893459	
i 1	300.98996598639457	0.505	72	697	5	1	7	1	5001	-1	1	0	0	10.464552728185682	
i 1	300.98996598639457	0.7575000000000001	70	697	2	20	13	2	5001	-2	2	0	0	5.616285980919738	
i 1	300.99237414965984	0.2525	74	1083	6	5	2	17	0	2	17	0	0	10.164563645893459	
i 1	301.01485034013604	0.2525	70	1083	3	20	3	2	0	-1	2	0	0	5.616285980919738	
i 1	301.2479931972789	0.2525	69	1083	4	1	12	0	0	0	0	0	0	10.464552728185682	
i 1	301.2616394557823	0.7575000000000001	72	199	7	2	16	8	0	1	8	0	0	4.0	
i 1	301.48193877551023	0.2525	72	1083	6	1	1	1	0	-1	1	0	0	10.464552728185682	
i 1	301.49237414965984	0.2525	73	697	2	20	15	2	0	-2	2	0	0	5.616285980919738	
i 1	301.4979931972789	0.2525	75	199	7	2	14	2	0	-2	2	0	0	4.0	
i 1	301.50842857142857	0.2525	69	199	6	1	3	1	0	0	1	0	0	10.464552728185682	
i 1	301.51003401360543	0.2525	77	1083	6	5	4	17	0	1	17	0	0	10.164563645893459	
i 1	301.75361224489797	0.505	70	1083	3	24	13	2	0	-1	2	0	0	9.616285980919738	
i 1	301.75441496598637	0.7575000000000001	73	697	2	24	13	8	5001	-2	8	0	0	9.616285980919738	
i 1	301.75762585034016	1.7675	75	697	5	3	11	2	5001	1	2	0	0	4.0	
i 1	301.76003401360543	0.2525	77	697	6	5	15	16	5001	2	16	0	0	10.164563645893459	
i 1	301.7608367346939	3.535	72	697	5	1	15	1	5001	-1	1	0	0	10.464552728185682	
i 1	301.7616394557823	0.505	75	697	5	3	1	2	0	1	2	0	0	4.0	
i 1	301.99157142857143	0.2525	69	697	4	24	10	0	0	0	0	0	0	11.464552728185682	
i 1	302.01404761904763	0.7575000000000001	73	697	2	20	9	2	0	-2	2	0	0	5.616285980919738	
i 1	302.0156530612245	0.2525	72	697	4	4	15	8	5001	-2	8	0	0	4.0	
i 1	302.23755782312924	0.2525	77	1083	6	5	12	17	0	1	17	0	0	10.164563645893459	
i 1	302.24157142857143	0.2525	72	199	6	1	11	0	0	-1	0	0	0	10.464552728185682	
i 1	302.2471904761905	0.2525	75	1083	5	9	5	2	0	-2	2	0	0	3.0	
i 1	302.2471904761905	0.505	72	1083	5	9	8	2	0	-2	2	0	0	3.0	
i 1	302.25842857142857	0.2525	77	697	6	5	14	16	0	1	16	0	0	10.164563645893459	
i 1	302.48675510204083	0.2525	73	697	4	24	2	8	5001	-2	8	0	0	9.616285980919738	
i 1	302.49397959183676	0.2525	70	1083	3	20	5	2	0	-1	2	0	0	5.616285980919738	
i 1	302.4971904761905	0.2525	74	1083	6	5	4	17	0	2	17	0	0	10.164563645893459	
i 1	302.4979931972789	0.2525	77	697	6	5	2	16	5001	2	16	0	0	10.164563645893459	
i 1	302.5020068027211	1.2625	73	697	2	24	16	2	0	-1	2	0	0	9.616285980919738	
i 1	302.50923129251703	0.2525	70	697	4	20	2	2	5001	-2	2	0	0	5.616285980919738	
i 1	302.5108367346939	0.2525	73	199	2	20	12	2	0	-2	2	0	0	5.616285980919738	
i 1	302.7383605442177	0.2525	77	697	6	5	3	16	0	1	16	0	0	10.164563645893459	
i 1	302.7391632653061	1.01	77	697	5	5	8	16	5001	2	16	0	0	10.164563645893459	
i 1	302.73996598639457	1.01	70	697	2	20	12	2	5001	-2	2	0	0	5.616285980919738	
i 1	302.76485034013604	1.01	61	1083	4	18	15	6	0	1	6	0	0	3.506464741742853	
i 1	302.98274149659863	0.2525	72	199	6	2	13	8	0	1	8	0	0	4.0	
i 1	302.98996598639457	0.2525	69	697	4	24	12	0	0	0	0	0	0	11.464552728185682	
i 1	303.00361224489797	0.2525	72	697	4	4	13	8	5001	-2	8	0	0	4.0	
i 1	303.00441496598637	0.2525	69	1083	6	1	8	0	0	0	0	0	0	10.464552728185682	
i 1	303.2335442176871	1.01	77	697	5	5	14	16	5001	2	16	0	0	10.164563645893459	
i 1	303.2656530612245	0.505	72	1083	5	9	11	2	0	-2	2	0	0	3.0	
i 1	303.50842857142857	0.505	72	697	4	4	3	8	5001	-2	8	0	0	4.0	
i 1	303.5116394557823	0.2525	69	697	4	24	13	0	5001	-1	0	0	0	11.464552728185682	
i 1	303.5164557823129	0.2525	72	199	6	1	16	0	0	-1	0	0	0	10.464552728185682	
i 1	303.73193877551023	8.08	66	4	6	14	12	6	0	1	6	0	0	10.42212433883081	
i 1	303.7335442176871	5.05	61	4	6	14	16	9	0	1	9	0	0	10.42212433883081	
i 1	303.73514965986396	0.2525	69	4	7	1	12	1	0	-1	1	0	0	10.464552728185682	
i 1	303.7391632653061	2.2725	72	4	6	2	4	8	0	1	8	0	0	4.0	
i 1	303.7391632653061	0.505	73	888	2	24	15	2	0	-2	2	0	0	9.616285980919738	
i 1	303.73996598639457	12.625	61	888	1	27	2	9	0	252	9	307	0	12.373384909427449	
i 1	303.73996598639457	0.505	73	4	2	20	2	2	0	-2	2	0	0	5.616285980919738	
i 1	303.74237414965984	8.08	61	888	4	19	13	6	0	2	6	0	0	3.506464741742853	
i 1	303.75040136054423	2.02	66	4	5	18	9	9	0	1	9	0	0	3.506464741742853	
i 1	303.75602040816324	12.625	66	888	1	27	7	6	0	248	6	308	0	12.373384909427449	
i 1	303.76003401360543	5.05	61	888	4	19	11	9	0	2	9	0	0	3.506464741742853	
i 1	303.7616394557823	1.2625	77	4	7	5	1	17	0	2	17	0	0	10.164563645893459	
i 1	303.76324489795917	2.02	66	4	5	18	3	6	0	1	6	0	0	3.506464741742853	
i 1	303.76806122448977	0.2525	70	697	4	20	16	2	5001	-2	2	0	0	5.616285980919738	
i 1	303.9891632653061	0.2525	72	4	7	1	12	1	0	0	1	0	0	10.464552728185682	
i 1	303.9891632653061	0.2525	74	4	7	5	2	16	0	1	16	0	0	10.164563645893459	
i 1	303.99237414965984	0.2525	75	697	5	3	13	2	5001	1	2	0	0	4.0	
i 1	304.01886394557823	0.505	72	888	3	1	11	1	0	-1	1	0	0	10.464552728185682	
i 1	304.2431768707483	0.2525	73	4	1	20	9	2	0	-1	2	0	0	5.616285980919738	
i 1	304.2616394557823	0.2525	74	888	6	5	3	16	0	1	16	0	0	10.164563645893459	
i 1	304.26324489795917	0.2525	72	697	4	4	3	8	5001	-2	8	0	0	4.0	
i 1	304.26404761904763	1.7675	70	888	2	20	8	2	0	-1	2	0	0	5.616285980919738	
i 1	304.26886394557823	1.7675	70	888	2	24	9	2	5001	-1	2	0	0	9.616285980919738	
i 1	304.4883605442177	0.2525	73	888	2	24	9	2	0	-2	2	0	0	9.616285980919738	
i 1	304.4971904761905	0.2525	72	4	6	1	6	1	0	0	1	0	0	10.464552728185682	
i 1	304.50842857142857	0.2525	75	888	4	4	5	2	0	1	2	0	0	4.0	
i 1	304.5156530612245	0.2525	72	888	5	3	7	2	0	-2	2	0	0	4.0	
i 1	304.7303333333333	0.2525	69	697	4	24	5	0	5001	-1	0	0	0	11.464552728185682	
i 1	304.73595238095237	0.505	72	4	6	9	9	2	0	1	2	0	0	3.0	
i 1	304.99879591836736	1.5150000000000001	77	697	5	5	16	16	5001	2	16	0	0	10.164563645893459	
i 1	305.00923129251703	1.2625	72	4	6	1	9	1	0	-1	1	0	0	10.464552728185682	
i 1	305.2391632653061	0.2525	73	4	4	24	4	2	0	-2	2	0	0	9.616285980919738	
i 1	305.2528095238095	0.2525	72	888	5	3	11	2	0	-2	2	0	0	4.0	
i 1	305.25441496598637	0.505	75	697	5	3	15	2	5001	1	2	0	0	4.0	
i 1	305.25842857142857	0.2525	72	888	3	1	16	1	0	-1	1	0	0	10.464552728185682	
i 1	305.4843469387755	0.2525	72	4	7	2	2	2	0	-2	2	0	0	4.0	
i 1	305.51003401360543	0.505	73	4	1	24	9	2	0	252	2	307	0	9.616285980919738	
i 1	305.5116394557823	0.505	69	697	4	24	10	0	5001	-1	0	0	0	11.464552728185682	
i 1	305.74237414965984	0.2525	77	4	7	5	3	17	0	2	17	0	0	10.164563645893459	
i 1	305.74879591836736	1.7675	72	697	4	4	13	8	5001	-2	8	0	0	4.0	
i 1	305.76324489795917	3.0300000000000002	66	4	5	18	10	6	0	1	6	0	0	3.506464741742853	
i 1	305.7664557823129	0.2525	73	4	1	20	10	2	0	-1	2	0	0	5.616285980919738	
i 1	305.76886394557823	6.0600000000000005	61	4	6	25	16	6	0	1	6	0	0	0.0268172013360698	
i 1	305.98193877551023	0.2525	75	697	5	3	15	2	5001	1	2	0	0	4.0	
i 1	305.98193877551023	0.2525	73	697	4	24	13	2	5001	-1	2	0	0	9.616285980919738	
i 1	305.9891632653061	1.7675	74	4	5	5	5	16	0	1	16	0	0	10.164563645893459	
i 1	306.0116394557823	0.2525	69	4	7	1	16	1	0	-1	1	0	0	10.464552728185682	
i 1	306.0164557823129	1.01	73	4	4	24	9	2	0	-2	2	0	0	9.616285980919738	
i 1	306.2343469387755	0.2525	72	4	5	1	5	1	0	0	1	0	0	10.464552728185682	
i 1	306.2391632653061	1.01	72	697	5	1	15	1	5001	-1	1	0	0	10.464552728185682	
i 1	306.2608367346939	0.2525	72	888	5	3	12	2	0	-2	2	0	0	4.0	
i 1	306.26806122448977	0.505	73	4	1	20	1	2	0	-1	2	0	0	5.616285980919738	
i 1	306.4843469387755	0.2525	77	697	6	5	6	16	5001	2	16	0	0	10.164563645893459	
i 1	306.51886394557823	0.7575000000000001	72	4	6	9	3	2	0	1	2	0	0	3.0	
i 1	306.73595238095237	0.2525	74	888	6	5	16	16	0	1	16	0	0	10.164563645893459	
i 1	306.75923129251703	0.2525	73	697	4	24	8	8	5001	-2	8	0	0	9.616285980919738	
i 1	306.99478231292517	0.505	73	888	2	24	1	8	5001	-2	8	0	0	9.616285980919738	
i 1	307.00521768707483	0.505	70	888	2	20	6	2	0	-1	2	0	0	5.616285980919738	
i 1	307.24076870748297	0.2525	72	4	6	2	14	2	0	-2	2	0	0	4.0	
i 1	307.25762585034016	1.5150000000000001	69	697	4	24	5	0	5001	-1	0	0	0	11.464552728185682	
i 1	307.48514965986396	0.2525	73	697	4	24	11	8	5001	-2	8	0	0	9.616285980919738	
i 1	307.48996598639457	0.2525	72	4	6	9	6	2	0	1	2	0	0	3.0	
i 1	307.5020068027211	0.2525	75	697	5	3	12	2	5001	1	2	0	0	4.0	
i 1	307.5028095238095	0.7575000000000001	73	4	4	24	4	2	0	-2	2	0	0	9.616285980919738	
i 1	307.74157142857143	1.5150000000000001	72	4	6	2	4	8	0	1	8	0	0	4.0	
i 1	307.74478231292517	0.2525	73	4	1	20	7	2	0	-1	2	0	0	5.616285980919738	
i 1	307.74638775510203	1.5150000000000001	77	697	6	5	15	16	5001	2	16	0	0	10.164563645893459	
i 1	307.76404761904763	0.2525	72	4	6	9	2	2	0	-2	2	0	0	3.0	
i 1	308.01003401360543	0.2525	77	4	7	5	12	17	0	2	17	0	0	10.164563645893459	
i 1	308.0156530612245	0.505	72	4	6	2	15	2	0	-2	2	0	0	4.0	
i 1	308.2528095238095	0.505	74	4	5	5	8	16	0	1	16	0	0	10.164563645893459	
i 1	308.2616394557823	0.2525	70	888	2	20	2	2	0	-1	2	0	0	5.616285980919738	
i 1	308.49558503401363	1.01	73	4	4	24	14	2	0	-2	2	0	0	9.616285980919738	
i 1	308.50040136054423	0.2525	75	888	4	4	11	2	0	1	2	0	0	4.0	
i 1	308.51485034013604	0.2525	73	697	4	24	13	8	5001	-1	8	0	0	9.616285980919738	
i 1	308.73113605442177	6.0600000000000005	66	4	6	25	4	6	0	2	6	0	0	0.0268172013360698	
i 1	308.73193877551023	3.0300000000000002	61	888	4	19	7	9	0	2	9	0	0	3.506464741742853	
i 1	308.75361224489797	0.2525	77	4	5	5	15	17	0	2	17	0	0	10.164563645893459	
i 1	308.75842857142857	7.575	61	4	6	14	10	9	0	1	9	0	0	10.42212433883081	
i 1	308.75923129251703	0.2525	72	4	6	2	13	2	0	-2	2	0	0	4.0	
i 1	308.76485034013604	0.505	73	4	1	20	13	2	0	-1	2	0	0	5.616285980919738	
i 1	308.76886394557823	0.505	72	4	6	1	16	1	0	-1	1	0	0	10.464552728185682	
i 1	308.99237414965984	0.2525	74	888	6	5	12	16	0	1	16	0	0	10.164563645893459	
i 1	309.23595238095237	1.5150000000000001	72	622	4	4	13	2	0	1	2	0	0	4.0	
i 1	309.25361224489797	1.5150000000000001	69	622	4	24	13	0	0	0	0	0	0	11.464552728185682	
i 1	309.25842857142857	0.2525	77	4	5	5	12	17	0	2	17	0	0	10.164563645893459	
i 1	309.25842857142857	7.07	61	622	6	7	3	6	0	2	6	0	0	9.11935879647696	
i 1	309.25923129251703	0.2525	77	4	5	5	5	17	0	1	17	0	0	10.164563645893459	
i 1	309.2608367346939	5.555	66	622	5	13	15	6	0	2	6	0	0	6.513827711769256	
i 1	309.26404761904763	0.2525	70	622	1	24	10	8	0	-2	8	0	0	9.616285980919738	
i 1	309.2664557823129	0.2525	72	888	6	1	11	1	0	-1	1	0	0	10.464552728185682	
i 1	309.49157142857143	0.505	74	4	5	5	14	16	0	1	16	0	0	10.164563645893459	
i 1	309.4931768707483	0.505	72	4	6	1	3	1	0	-1	1	0	0	10.464552728185682	
i 1	309.51404761904763	0.7575000000000001	70	888	2	20	16	2	0	-1	2	0	0	5.616285980919738	
i 1	309.51806122448977	1.2625	77	622	6	5	13	16	0	1	16	0	0	10.164563645893459	
i 1	309.98755782312924	0.2525	72	4	5	1	12	1	0	0	1	0	0	10.464552728185682	
i 1	310.00923129251703	0.2525	74	4	5	5	12	16	0	2	16	0	0	10.164563645893459	
i 1	310.23595238095237	0.2525	72	622	5	3	9	2	0	1	2	0	0	4.0	
i 1	310.24076870748297	1.5150000000000001	73	4	4	24	13	2	0	-2	2	0	0	9.616285980919738	
i 1	310.2431768707483	1.5150000000000001	73	4	1	20	2	2	0	-1	2	0	0	5.616285980919738	
i 1	310.24397959183676	0.2525	69	888	4	24	15	0	0	-1	0	0	0	11.464552728185682	
i 1	310.24879591836736	0.2525	74	888	6	5	15	16	0	1	16	0	0	10.164563645893459	
i 1	310.49237414965984	0.505	72	4	6	2	4	2	0	-2	2	0	0	4.0	
i 1	310.49478231292517	1.01	77	4	5	5	16	17	0	2	17	0	0	10.164563645893459	
i 1	310.7303333333333	1.01	69	622	5	1	8	1	0	-1	1	0	0	10.464552728185682	
i 1	310.75361224489797	0.7575000000000001	72	622	5	3	2	2	0	1	2	0	0	4.0	
i 1	310.75521768707483	0.2525	74	888	6	5	5	16	0	1	16	0	0	10.164563645893459	
i 1	311.00120408163264	0.2525	72	622	4	4	5	2	0	1	2	0	0	4.0	
i 1	311.01725850340137	0.2525	74	888	6	5	14	16	0	1	16	0	0	10.164563645893459	
i 1	311.25441496598637	0.505	72	4	6	9	13	2	0	1	2	0	0	3.0	
i 1	311.4803333333333	0.2525	74	4	5	5	9	16	0	1	16	0	0	10.164563645893459	
i 1	311.49478231292517	0.2525	72	622	4	4	7	2	0	1	2	0	0	4.0	
i 1	311.49558503401363	1.5150000000000001	77	622	6	5	7	17	0	2	17	0	0	10.164563645893459	
i 1	311.73274149659863	3.0300000000000002	61	888	4	19	7	6	0	2	6	0	0	3.506464741742853	
i 1	311.73274149659863	4.545	66	622	5	25	5	9	0	1	9	0	0	0.0268172013360698	
i 1	311.73755782312924	0.505	70	888	2	20	7	2	0	-1	2	0	0	5.616285980919738	
i 1	311.7383605442177	4.545	66	4	6	14	13	6	0	1	6	0	0	10.42212433883081	
i 1	311.7528095238095	1.2625	72	622	4	4	13	2	0	1	2	0	0	4.0	
i 1	311.75521768707483	0.505	77	622	4	5	2	16	0	1	16	0	0	10.164563645893459	
i 1	311.76244217687076	1.01	69	622	4	24	8	0	0	0	0	0	0	11.464552728185682	
i 1	311.76244217687076	0.2525	75	888	4	4	10	2	0	1	2	0	0	4.0	
i 1	311.7696666666667	4.545	61	4	6	25	10	6	0	1	6	0	0	0.0268172013360698	
i 1	311.99076870748297	0.2525	69	888	4	24	3	0	0	-1	0	0	0	11.464552728185682	
i 1	312.25521768707483	0.7575000000000001	72	4	6	1	6	1	0	0	1	0	0	10.464552728185682	
i 1	312.25762585034016	0.2525	77	4	5	5	16	17	0	2	17	0	0	10.164563645893459	
i 1	312.25842857142857	0.2525	73	4	2	20	1	2	0	-1	2	0	0	5.616285980919738	
i 1	312.26725850340137	0.2525	70	4	4	20	8	2	0	-1	2	0	0	5.616285980919738	
i 1	312.4803333333333	2.525	70	888	2	20	3	2	0	-1	2	0	0	5.616285980919738	
i 1	312.50361224489797	0.2525	74	888	6	5	14	16	0	1	16	0	0	10.164563645893459	
i 1	312.5068231292517	0.2525	72	4	6	9	14	2	0	1	2	0	0	3.0	
i 1	312.73996598639457	1.5150000000000001	69	622	5	1	1	1	0	-1	1	0	0	10.464552728185682	
i 1	312.7616394557823	0.505	77	622	4	5	1	16	0	1	16	0	0	10.164563645893459	
i 1	312.76725850340137	0.7575000000000001	72	622	5	3	13	2	0	1	2	0	0	4.0	
i 1	312.99397959183676	2.2725	74	4	5	5	6	16	0	1	16	0	0	10.164563645893459	
i 1	313.0028095238095	0.505	69	622	4	24	7	0	0	0	0	0	0	11.464552728185682	
i 1	313.01725850340137	1.5150000000000001	72	4	6	2	4	8	0	1	8	0	0	4.0	
i 1	313.24237414965984	0.2525	74	4	5	5	13	16	0	2	16	0	0	10.164563645893459	
i 1	313.4835442176871	0.2525	72	622	4	4	15	2	0	1	2	0	0	4.0	
i 1	313.4883605442177	0.505	77	622	6	5	8	17	0	2	17	0	0	10.164563645893459	
i 1	313.5028095238095	0.2525	72	888	3	1	10	1	0	-1	1	0	0	10.464552728185682	
i 1	313.75923129251703	0.2525	72	4	6	9	4	2	0	-2	2	0	0	3.0	
i 1	313.76886394557823	0.2525	72	4	5	1	4	1	0	0	1	0	0	10.464552728185682	
i 1	314.01725850340137	0.505	74	888	3	5	12	16	0	1	16	0	0	10.164563645893459	
i 1	314.24879591836736	0.2525	69	622	4	24	3	0	0	0	0	0	0	11.464552728185682	
i 1	314.2696666666667	0.2525	69	888	4	24	6	0	0	-1	0	0	0	11.464552728185682	
i 1	314.48755782312924	0.2525	77	4	5	5	3	17	0	2	17	0	0	10.164563645893459	
i 1	314.50040136054423	0.2525	72	888	3	1	12	1	0	-1	1	0	0	10.464552728185682	
i 1	314.50842857142857	0.2525	69	622	5	1	8	1	0	-1	1	0	0	10.464552728185682	
i 1	314.73755782312924	1.5150000000000001	66	4	6	25	3	6	0	2	6	0	0	0.0268172013360698	
i 1	314.73996598639457	0.2525	74	4	6	5	8	16	0	2	16	0	0	10.164563645893459	
i 1	314.74879591836736	1.5150000000000001	66	622	5	13	4	6	0	2	6	0	0	6.513827711769256	
i 1	314.75602040816324	1.5150000000000001	72	622	5	3	15	2	0	1	2	0	0	4.0	
i 1	314.7616394557823	1.5150000000000001	72	4	7	1	6	1	0	-1	1	0	0	10.464552728185682	
i 1	314.7656530612245	1.5150000000000001	61	622	5	25	3	9	0	2	9	0	0	0.0268172013360698	
i 1	314.98595238095237	0.2525	70	622	1	24	12	2	0	-1	2	0	0	9.616285980919738	
i 1	314.99959863945577	0.505	77	622	4	5	1	16	0	1	16	0	0	10.164563645893459	
i 1	315.0068231292517	1.01	73	4	1	24	15	2	0	-2	2	0	0	9.616285980919738	
i 1	315.24879591836736	0.505	74	888	3	5	15	16	0	1	16	0	0	10.164563645893459	
i 1	315.2656530612245	0.2525	73	4	1	20	9	2	0	-1	2	0	0	5.616285980919738	
i 1	315.48193877551023	0.7575000000000001	77	622	4	5	9	17	0	2	17	0	0	10.164563645893459	
i 1	315.48996598639457	0.505	70	622	1	24	6	2	0	-1	2	0	0	9.616285980919738	
i 1	315.74959863945577	0.2525	77	4	5	5	13	17	0	2	17	0	0	10.164563645893459	
i 1	315.9883605442177	0.2525	77	4	6	5	8	17	0	1	17	0	0	10.164563645893459	
i 1	315.99558503401363	0.2525	70	888	2	20	6	2	0	-1	2	0	0	5.616285980919738	
i 1	316.00120408163264	0.2525	72	4	5	1	2	1	0	0	1	0	0	10.464552728185682	
i 1	316.2303333333333	4.545	61	1093	5	25	14	9	0	2	9	0	0	0.0268172013360698	
i 1	316.23113605442177	1.01	69	707	4	24	2	1	0	-1	1	0	0	11.464552728185682	
i 1	316.23113605442177	2.02	75	707	5	3	15	2	0	1	2	0	0	4.0	
i 1	316.23193877551023	0.7575000000000001	69	1093	3	1	3	1	0	0	1	0	0	10.464552728185682	
i 1	316.23996598639457	4.545	66	1093	5	14	4	9	0	2	9	0	0	10.42212433883081	
i 1	316.24157142857143	4.545	61	1093	1	27	6	6	0	252	6	307	0	12.373384909427449	
i 1	316.24157142857143	0.2525	70	209	1	24	1	2	0	-1	2	0	0	9.616285980919738	
i 1	316.24959863945577	4.545	66	1093	5	14	12	6	0	2	6	0	0	10.42212433883081	
i 1	316.25120408163264	1.01	74	707	4	5	16	16	0	2	16	0	0	10.164563645893459	
i 1	316.2568231292517	4.545	66	707	5	13	12	6	0	1	6	0	0	6.513827711769256	
i 1	316.25762585034016	4.545	61	1093	5	25	9	6	0	2	6	0	0	0.0268172013360698	
i 1	316.26244217687076	1.5150000000000001	61	707	6	7	16	6	0	1	6	0	0	9.11935879647696	
i 1	316.26324489795917	1.5150000000000001	61	707	5	25	10	6	0	1	6	0	0	0.0268172013360698	
i 1	316.2696666666667	4.545	66	707	5	25	15	6	0	1	6	0	0	0.0268172013360698	
i 1	316.48755782312924	0.2525	73	1093	1	20	5	8	0	-2	8	0	0	5.616285980919738	
i 1	316.4971904761905	0.2525	73	209	1	20	9	2	0	-1	2	0	0	5.616285980919738	
i 1	316.51244217687076	0.2525	74	209	6	5	1	16	0	1	16	0	0	10.164563645893459	
i 1	316.7303333333333	2.02	77	1093	4	5	16	17	0	2	17	0	0	10.164563645893459	
i 1	316.76886394557823	0.7575000000000001	70	209	1	24	2	2	0	-1	2	0	0	9.616285980919738	
i 1	316.98193877551023	0.505	72	1093	6	1	14	0	0	0	0	0	0	10.464552728185682	
i 1	317.23996598639457	0.2525	72	209	6	9	16	2	0	-2	2	0	0	3.0	
i 1	317.2608367346939	0.505	69	707	5	1	2	1	0	0	1	0	0	10.464552728185682	
i 1	317.26725850340137	0.2525	74	209	6	5	2	16	0	1	16	0	0	10.164563645893459	
i 1	317.48675510204083	1.01	72	707	4	4	2	2	0	1	2	0	0	4.0	
i 1	317.49397959183676	0.2525	74	209	6	5	13	17	0	2	17	0	0	10.164563645893459	
i 1	317.50120408163264	0.2525	69	707	4	24	16	1	0	-1	1	0	0	11.464552728185682	
i 1	317.50842857142857	0.2525	73	707	1	24	9	8	0	-2	8	0	0	9.616285980919738	
i 1	317.51244217687076	0.2525	70	1093	2	20	1	8	0	-1	8	0	0	5.616285980919738	
i 1	317.73274149659863	0.2525	74	209	4	5	3	16	0	1	16	0	0	10.164563645893459	
i 1	317.7335442176871	3.0300000000000002	61	707	5	25	12	6	0	1	6	0	0	0.0268172013360698	
i 1	317.7343469387755	0.7575000000000001	73	209	1	20	5	8	0	-1	8	0	0	5.616285980919738	
i 1	317.7343469387755	1.01	73	209	1	20	8	2	0	-1	2	0	0	5.616285980919738	
i 1	317.7383605442177	0.2525	69	209	5	1	7	1	0	-1	1	0	0	10.464552728185682	
i 1	317.74638775510203	0.505	69	707	6	1	3	1	0	0	1	0	0	10.464552728185682	
i 1	317.74638775510203	3.0300000000000002	66	1093	6	17	10	9	0	1	9	0	0	3.506464741742853	
i 1	317.75361224489797	3.0300000000000002	61	707	5	7	8	6	0	1	6	0	0	9.11935879647696	
i 1	317.76003401360543	3.0300000000000002	66	209	5	26	13	6	0	2	6	0	0	0.0268172013360698	
i 1	317.9803333333333	0.2525	69	1093	3	24	5	1	0	0	1	0	0	11.464552728185682	
i 1	317.98595238095237	0.505	74	707	4	5	6	17	0	2	17	0	0	10.164563645893459	
i 1	318.25040136054423	0.505	72	1093	6	1	3	0	0	0	0	0	0	10.464552728185682	
i 1	318.2616394557823	1.5150000000000001	69	707	4	24	9	1	0	-1	1	0	0	11.464552728185682	
i 1	318.2656530612245	0.2525	72	1093	5	2	10	2	0	-2	2	0	0	4.0	
i 1	318.48675510204083	1.5150000000000001	75	707	5	3	11	2	0	1	2	0	0	4.0	
i 1	318.49478231292517	0.2525	70	1093	1	20	11	8	0	-1	8	0	0	5.616285980919738	
i 1	318.5116394557823	0.2525	72	1093	4	3	7	2	0	-2	2	0	0	4.0	
i 1	318.5164557823129	1.01	74	209	4	5	15	16	0	1	16	0	0	10.164563645893459	
i 1	318.73274149659863	0.2525	75	209	5	9	14	2	0	1	2	0	0	3.0	
i 1	318.76244217687076	0.2525	70	209	1	24	11	2	0	-1	2	0	0	9.616285980919738	
i 1	318.7656530612245	0.505	69	1093	3	24	5	1	0	0	1	0	0	11.464552728185682	
i 1	318.76725850340137	0.7575000000000001	74	707	4	5	8	17	0	2	17	0	0	10.164563645893459	
i 1	318.98113605442177	0.2525	70	707	1	24	8	8	0	-1	8	0	0	9.616285980919738	
i 1	319.00762585034016	0.2525	70	1093	2	20	1	8	0	-1	8	0	0	5.616285980919738	
i 1	319.00842857142857	0.505	72	1093	5	2	6	2	0	-2	2	0	0	4.0	
i 1	319.24237414965984	0.2525	72	1093	6	1	4	0	0	0	0	0	0	10.464552728185682	
i 1	319.2479931972789	1.5150000000000001	73	209	1	20	8	8	0	-1	8	0	0	5.616285980919738	
i 1	319.2479931972789	1.5150000000000001	73	1093	1	24	6	8	0	252	8	307	0	9.616285980919738	
i 1	319.24879591836736	1.7675	73	209	1	20	11	2	0	-1	2	0	0	5.616285980919738	
i 1	319.4835442176871	1.2625	77	1093	4	5	12	16	0	2	16	0	0	10.164563645893459	
i 1	319.48675510204083	0.2525	69	209	5	1	6	1	0	-1	1	0	0	10.464552728185682	
i 1	319.4971904761905	0.2525	75	209	5	9	7	2	0	1	2	0	0	3.0	
i 1	319.50602040816324	0.2525	77	1093	3	5	3	17	0	1	17	0	0	10.164563645893459	
i 1	319.73514965986396	0.505	69	209	5	1	1	1	0	-1	1	0	0	10.464552728185682	
i 1	319.76003401360543	0.505	75	1093	4	4	8	8	0	1	8	0	0	4.0	
i 1	319.76003401360543	0.2525	77	1093	4	5	13	17	0	2	17	0	0	10.164563645893459	
i 1	319.9835442176871	0.505	74	707	4	5	16	17	0	2	17	0	0	10.164563645893459	
i 1	320.0156530612245	0.7575000000000001	72	707	4	4	12	2	0	1	2	0	0	4.0	
i 1	320.2343469387755	0.505	69	707	6	1	1	1	0	0	1	0	0	10.464552728185682	
i 1	320.25040136054423	0.2525	75	707	5	3	13	2	0	1	2	0	0	4.0	
i 1	320.4979931972789	0.2525	72	1093	5	2	13	8	0	-2	8	0	0	4.0	
i 1	320.49959863945577	0.2525	74	209	6	5	10	17	0	2	17	0	0	10.164563645893459	
i 1	320.73514965986396	6.0600000000000005	66	1093	5	14	15	9	0	2	9	0	0	2.605531084707703	
i 1	320.73996598639457	0.505	72	209	5	9	6	2	0	-2	2	0	0	3.010334626567461	
i 1	320.74157142857143	3.0300000000000002	66	1093	5	14	16	6	0	2	6	0	0	2.605531084707703	
i 1	320.74157142857143	12.120000000000001	61	707	5	7	16	6	0	1	6	0	0	1.3027655423538516	
i 1	320.7431768707483	0.2525	77	1093	4	5	2	17	0	2	17	0	0	8.121115351221295	
i 1	320.75120408163264	1.01	69	707	6	1	4	1	0	0	1	0	0	11.514767055251998	
i 1	320.75120408163264	0.505	77	1093	5	5	7	16	0	2	16	0	0	8.121115351221295	
i 1	320.7568231292517	0.7575000000000001	72	707	4	4	5	2	0	1	2	0	0	4.010334626567461	
i 1	320.76806122448977	0.2525	70	1093	1	20	15	8	0	-1	8	0	0	5.616285980919738	
i 1	320.98996598639457	0.505	74	209	4	5	1	16	0	1	16	0	0	8.121115351221295	
i 1	321.00361224489797	0.7575000000000001	70	209	1	24	4	2	0	-1	2	0	0	9.616285980919738	
i 1	321.26003401360543	0.2525	72	1093	3	3	16	2	0	-2	2	0	0	4.010334626567461	
i 1	321.26404761904763	1.01	74	707	4	5	5	16	0	2	16	0	0	8.121115351221295	
i 1	321.48675510204083	0.2525	72	1093	5	2	11	2	0	-2	2	0	0	4.010334626567461	
i 1	321.5068231292517	0.2525	75	1093	4	4	16	8	0	1	8	0	0	4.010334626567461	
i 1	321.5116394557823	0.7575000000000001	77	1093	5	5	8	16	0	2	16	0	0	8.121115351221295	
i 1	321.73113605442177	1.01	69	1093	6	1	1	1	0	-1	1	0	0	11.514767055251998	
i 1	321.74638775510203	1.5150000000000001	72	707	4	4	15	2	0	1	2	0	0	4.010334626567461	
i 1	321.76244217687076	0.2525	72	5	5	4	4	2	0	-2	2	0	0	4.010334626567461	
i 1	321.99237414965984	0.505	75	209	5	9	16	2	0	1	2	0	0	3.010334626567461	
i 1	322.2303333333333	0.505	74	209	4	5	12	17	0	2	17	0	0	8.121115351221295	
i 1	322.2528095238095	1.01	74	707	4	5	7	17	0	2	17	0	0	8.121115351221295	
i 1	322.49076870748297	0.2525	72	209	5	9	4	2	0	-2	2	0	0	3.010334626567461	
i 1	322.7383605442177	1.01	69	707	6	1	13	1	0	0	1	0	0	11.514767055251998	
i 1	322.74076870748297	0.2525	74	5	5	5	14	16	0	2	16	0	0	8.121115351221295	
i 1	322.75923129251703	2.2725	75	707	5	3	7	2	0	1	2	0	0	4.010334626567461	
i 1	323.00923129251703	0.2525	74	5	5	5	6	16	0	1	16	0	0	8.121115351221295	
i 1	323.2303333333333	0.505	77	1093	4	5	7	17	0	2	17	0	0	8.121115351221295	
i 1	323.23514965986396	0.505	74	707	4	5	5	16	0	2	16	0	0	8.121115351221295	
i 1	323.24558503401363	1.2625	70	209	1	24	15	2	0	-1	2	0	0	9.616285980919738	
i 1	323.25040136054423	0.2525	72	5	4	3	9	2	0	-2	2	0	0	4.010334626567461	
i 1	323.25842857142857	1.2625	73	209	1	20	5	2	0	-1	2	0	0	5.616285980919738	
i 1	323.49959863945577	0.2525	69	707	4	24	5	1	0	-1	1	0	0	12.514767055251998	
i 1	323.5068231292517	0.2525	72	1093	5	2	8	8	0	-2	8	0	0	4.010334626567461	
i 1	323.73193877551023	5.05	66	1093	4	14	4	6	0	2	6	0	0	2.605531084707703	
i 1	323.73675510204083	1.01	77	1093	5	5	5	17	0	2	17	0	0	8.121115351221295	
i 1	323.7431768707483	0.505	72	5	4	1	8	1	0	0	1	0	0	11.514767055251998	
i 1	323.75521768707483	2.02	69	707	4	24	2	1	0	-1	1	0	0	12.514767055251998	
i 1	323.76244217687076	0.2525	74	5	5	5	14	16	0	2	16	0	0	8.121115351221295	
i 1	323.9979931972789	0.505	74	707	4	5	6	16	0	2	16	0	0	8.121115351221295	
i 1	324.23675510204083	0.505	72	1093	6	1	15	0	0	0	0	0	0	11.514767055251998	
i 1	324.2479931972789	0.2525	72	707	4	4	14	2	0	1	2	0	0	4.010334626567461	
i 1	324.51003401360543	1.01	72	1093	4	2	15	2	0	-2	2	0	0	4.010334626567461	
i 1	324.51725850340137	0.2525	74	5	5	5	11	16	0	2	16	0	0	8.121115351221295	
i 1	324.7391632653061	0.7575000000000001	74	707	4	5	4	16	0	2	16	0	0	8.121115351221295	
i 1	324.74478231292517	0.505	77	1093	5	5	11	16	0	2	16	0	0	8.121115351221295	
i 1	324.7616394557823	0.2525	69	5	4	24	1	1	0	-1	1	0	0	12.514767055251998	
i 1	325.0108367346939	0.2525	72	5	4	4	6	2	0	-2	2	0	0	4.010334626567461	
i 1	325.01244217687076	0.2525	72	5	4	1	7	1	0	0	1	0	0	11.514767055251998	
i 1	325.25361224489797	0.2525	70	209	1	24	5	2	0	-1	2	0	0	9.616285980919738	
i 1	325.25441496598637	0.2525	74	209	4	5	5	17	0	2	17	0	0	8.121115351221295	
i 1	325.25441496598637	0.2525	74	707	1	24	7	8	0	1	8	0	0	9.616285980919738	
i 1	325.26806122448977	0.2525	72	1093	5	2	8	8	0	-2	8	0	0	4.010334626567461	
i 1	325.49959863945577	0.2525	74	707	4	5	1	17	0	2	17	0	0	8.121115351221295	
i 1	325.51485034013604	1.5150000000000001	75	707	5	3	7	2	0	1	2	0	0	4.010334626567461	
i 1	325.51806122448977	1.5150000000000001	77	1093	5	5	7	17	0	2	17	0	0	8.121115351221295	
i 1	325.74157142857143	0.2525	74	209	4	5	15	16	0	1	16	0	0	8.121115351221295	
i 1	325.76806122448977	1.7675	69	707	6	1	4	1	0	0	1	0	0	11.514767055251998	
i 1	326.01886394557823	0.505	74	707	4	5	3	17	0	2	17	0	0	8.121115351221295	
i 1	326.24959863945577	0.505	71	1093	1	20	13	2	0	1	2	0	0	5.616285980919738	
i 1	326.2520068027211	0.2525	69	1093	6	1	13	1	0	-1	1	0	0	11.514767055251998	
i 1	326.2528095238095	0.505	73	209	1	20	3	2	0	-1	2	0	0	5.616285980919738	
i 1	326.4979931972789	0.2525	74	5	3	5	2	16	0	1	16	0	0	8.121115351221295	
i 1	326.75040136054423	2.02	66	1093	4	14	13	9	0	2	9	0	0	2.605531084707703	
i 1	326.7568231292517	0.505	74	707	4	5	15	17	0	2	17	0	0	8.121115351221295	
i 1	326.7696666666667	0.2525	69	1093	5	1	16	1	0	-1	1	0	0	11.514767055251998	
i 1	326.9803333333333	0.505	71	209	1	20	4	2	0	-2	2	0	0	3.092081747133257	
i 1	326.9835442176871	0.505	74	5	3	5	4	16	0	2	16	0	0	8.121115351221295	
i 1	326.99397959183676	1.5150000000000001	72	707	4	4	9	2	0	1	2	0	0	4.010334626567461	
i 1	327.0164557823129	0.2525	69	5	4	24	8	1	0	-1	1	0	0	12.514767055251998	
i 1	327.0164557823129	0.505	73	209	1	20	1	2	0	-1	2	0	0	3.092081747133257	
i 1	327.25040136054423	1.5150000000000001	77	1093	5	5	16	16	0	2	16	0	0	8.121115351221295	
i 1	327.2656530612245	1.01	69	707	4	24	7	1	0	-1	1	0	0	12.514767055251998	
i 1	327.4835442176871	0.505	69	209	7	1	10	1	0	-1	1	0	0	11.514767055251998	
i 1	327.4891632653061	0.2525	74	707	1	24	12	2	0	1	2	0	0	7.092081747133257	
i 1	327.49959863945577	0.2525	74	707	4	5	1	17	0	2	17	0	0	8.121115351221295	
i 1	327.50120408163264	0.2525	70	209	1	24	4	2	0	-1	2	0	0	7.092081747133257	
i 1	327.73274149659863	0.2525	74	5	3	5	11	16	0	2	16	0	0	8.121115351221295	
i 1	327.74076870748297	0.2525	75	209	5	9	5	2	0	1	2	0	0	3.010334626567461	
i 1	328.0156530612245	2.7775	69	707	6	1	15	1	0	0	1	0	0	11.514767055251998	
i 1	328.01806122448977	0.7575000000000001	72	5	4	3	13	2	0	-2	2	0	0	4.010334626567461	
i 1	328.26003401360543	0.2525	69	1093	5	1	2	1	0	-1	1	0	0	11.514767055251998	
i 1	328.4803333333333	0.505	73	209	1	20	9	2	0	-1	2	0	0	3.092081747133257	
i 1	328.48193877551023	0.505	69	707	4	24	16	1	0	-1	1	0	0	12.514767055251998	
i 1	328.50040136054423	0.2525	75	707	5	3	14	2	0	1	2	0	0	4.010334626567461	
i 1	328.51404761904763	0.2525	71	1093	1	20	16	2	0	-2	2	0	0	3.092081747133257	
i 1	328.73274149659863	10.1	60	911	4	14	15	0	0	0	0	0	0	2.605531084707703	
i 1	328.74879591836736	0.2525	72	209	4	3	14	1	0	0	1	0	0	4.010334626567461	
i 1	328.75521768707483	1.5150000000000001	72	911	4	2	10	0	0	-1	0	0	0	4.010334626567461	
i 1	328.7608367346939	0.2525	74	209	1	20	16	2	0	-2	2	0	0	3.092081747133257	
i 1	328.76404761904763	13.13	60	911	4	14	8	5	0	1	5	0	0	2.605531084707703	
i 1	328.7664557823129	1.01	74	707	4	5	6	17	0	2	17	0	0	8.121115351221295	
i 1	328.98996598639457	0.2525	74	707	1	24	3	8	0	-2	8	0	0	7.092081747133257	
i 1	328.99237414965984	0.2525	70	209	1	24	14	2	0	-1	2	0	0	7.092081747133257	
i 1	328.99959863945577	0.2525	69	209	7	1	8	1	0	-1	1	0	0	11.514767055251998	
i 1	329.24076870748297	0.2525	69	707	4	24	10	1	0	-1	1	0	0	12.514767055251998	
i 1	329.24157142857143	1.7675	70	209	1	24	7	2	0	252	2	307	0	7.092081747133257	
i 1	329.24638775510203	0.2525	75	707	5	3	14	2	0	1	2	0	0	4.010334626567461	
i 1	329.26244217687076	0.2525	71	209	4	24	5	8	0	-1	8	0	0	12.514767055251998	
i 1	329.48996598639457	0.2525	69	209	7	1	16	1	0	-1	1	0	0	11.514767055251998	
i 1	329.5020068027211	0.2525	71	911	6	1	6	8	0	-1	8	0	0	11.514767055251998	
i 1	329.73996598639457	0.2525	75	707	4	3	3	2	0	1	2	0	0	4.010334626567461	
i 1	329.7471904761905	0.505	74	911	5	1	16	8	0	-2	8	0	0	11.514767055251998	
i 1	329.7479931972789	0.505	74	707	5	5	10	17	0	2	17	0	0	8.121115351221295	
i 1	329.74959863945577	0.505	72	209	5	9	13	2	0	-2	2	0	0	3.010334626567461	
i 1	329.75441496598637	2.2725	73	209	1	20	12	2	0	-1	2	0	0	3.092081747133257	
i 1	329.75521768707483	0.2525	74	707	1	24	5	8	0	1	8	0	0	7.092081747133257	
i 1	329.75842857142857	0.7575000000000001	74	911	2	20	9	8	0	1	8	0	0	3.092081747133257	
i 1	329.98113605442177	1.01	69	911	5	5	16	1	0	-1	1	0	0	8.121115351221295	
i 1	329.99879591836736	0.2525	71	209	6	1	9	2	0	-1	2	0	0	11.514767055251998	
i 1	330.0164557823129	0.2525	72	911	4	2	15	1	0	-1	1	0	0	4.010334626567461	
i 1	330.2431768707483	2.2725	69	707	4	24	14	1	0	-1	1	0	0	12.514767055251998	
i 1	330.25842857142857	1.5150000000000001	72	707	4	4	13	2	0	1	2	0	0	4.010334626567461	
i 1	330.26485034013604	0.2525	69	209	7	1	10	1	0	-1	1	0	0	11.514767055251998	
i 1	330.5116394557823	1.5150000000000001	74	209	1	20	10	2	0	1	2	0	0	3.092081747133257	
i 1	330.7520068027211	0.2525	74	911	5	1	10	8	0	-2	8	0	0	11.514767055251998	
i 1	330.98675510204083	0.2525	71	209	6	1	9	2	0	-1	2	0	0	11.514767055251998	
i 1	330.98755782312924	0.2525	70	209	1	24	2	2	0	-1	2	0	0	7.092081747133257	
i 1	331.00842857142857	1.5150000000000001	74	707	5	5	7	16	0	2	16	0	0	8.121115351221295	
i 1	331.24076870748297	0.2525	75	209	5	9	4	2	0	1	2	0	0	3.010334626567461	
i 1	331.24879591836736	0.505	69	707	6	1	5	1	0	0	1	0	0	11.514767055251998	
i 1	331.24879591836736	0.2525	72	209	3	5	14	0	0	-1	0	0	0	8.121115351221295	
i 1	331.25521768707483	0.2525	74	209	4	5	12	17	0	2	17	0	0	8.121115351221295	
i 1	331.25521768707483	1.5150000000000001	70	209	1	24	7	2	0	248	2	308	0	7.092081747133257	
i 1	331.48514965986396	1.2625	75	707	4	3	8	2	0	1	2	0	0	4.010334626567461	
i 1	331.49879591836736	0.505	69	209	3	5	5	1	0	0	1	0	0	8.121115351221295	
i 1	331.73514965986396	0.7575000000000001	69	209	7	1	9	1	0	-1	1	0	0	11.514767055251998	
i 1	331.73996598639457	0.2525	69	209	7	1	13	1	0	-1	1	0	0	11.514767055251998	
i 1	331.75923129251703	0.2525	72	209	5	9	5	2	0	-2	2	0	0	3.010334626567461	
i 1	331.98193877551023	0.2525	72	209	3	5	14	0	0	-1	0	0	0	8.121115351221295	
i 1	332.00361224489797	0.2525	72	209	4	3	3	1	0	0	1	0	0	4.010334626567461	
i 1	332.00842857142857	0.7575000000000001	69	707	6	1	4	1	0	0	1	0	0	11.514767055251998	
i 1	332.0156530612245	0.2525	69	209	4	4	14	0	0	0	0	0	0	4.010334626567461	
i 1	332.2303333333333	0.2525	69	209	3	5	5	1	0	0	1	0	0	8.121115351221295	
i 1	332.23274149659863	0.2525	72	911	4	2	3	1	0	-1	1	0	0	4.010334626567461	
i 1	332.24397959183676	0.2525	74	209	4	5	11	17	0	2	17	0	0	8.121115351221295	
i 1	332.48274149659863	0.2525	74	209	1	20	4	2	0	1	2	0	0	3.092081747133257	
i 1	332.50040136054423	0.505	69	911	5	5	16	1	0	-1	1	0	0	8.121115351221295	
i 1	332.50361224489797	1.5150000000000001	72	911	4	2	14	0	0	-1	0	0	0	4.010334626567461	
i 1	332.51404761904763	0.2525	71	911	5	1	11	8	0	-1	8	0	0	11.514767055251998	
i 1	332.7343469387755	1.2625	74	707	5	5	14	17	0	2	17	0	0	8.121115351221295	
i 1	332.73514965986396	0.505	72	707	4	4	7	2	0	1	2	0	0	4.010334626567461	
i 1	332.73675510204083	7.07	61	707	4	7	5	6	0	1	6	0	0	1.3027655423538516	
i 1	332.73996598639457	0.2525	70	209	1	24	14	2	0	-1	2	0	0	7.092081747133257	
i 1	332.7608367346939	0.505	74	911	5	1	11	8	0	-2	8	0	0	11.514767055251998	
i 1	332.7664557823129	0.2525	71	707	1	24	6	2	0	-2	2	0	0	7.092081747133257	
i 1	332.76725850340137	0.505	69	707	5	1	15	1	0	0	1	0	0	11.514767055251998	
i 1	333.00923129251703	0.2525	75	707	4	3	4	2	0	1	2	0	0	4.010334626567461	
i 1	333.25040136054423	1.01	69	707	4	24	1	1	0	-1	1	0	0	12.514767055251998	
i 1	333.2528095238095	0.2525	72	209	4	3	6	1	0	0	1	0	0	4.010334626567461	
i 1	333.25361224489797	0.2525	71	209	7	1	12	2	0	-1	2	0	0	11.514767055251998	
i 1	333.48514965986396	0.505	74	911	5	1	9	8	0	-2	8	0	0	11.514767055251998	
i 1	333.49558503401363	0.505	75	209	5	9	14	2	0	1	2	0	0	3.010334626567461	
i 1	333.5196666666667	0.2525	74	209	4	5	7	17	0	2	17	0	0	8.121115351221295	
i 1	333.7343469387755	2.7775	69	911	5	5	8	1	0	0	1	0	0	8.121115351221295	
i 1	333.98996598639457	1.7675	69	707	5	1	11	1	0	0	1	0	0	11.514767055251998	
i 1	333.99157142857143	0.2525	69	209	3	5	15	1	0	0	1	0	0	8.121115351221295	
i 1	334.0020068027211	1.5150000000000001	75	707	4	3	7	2	0	1	2	0	0	4.010334626567461	
i 1	334.0196666666667	0.2525	72	209	4	3	9	1	0	0	1	0	0	4.010334626567461	
i 1	334.24558503401363	0.2525	74	209	4	5	12	17	0	2	17	0	0	8.121115351221295	
i 1	334.2608367346939	0.2525	72	911	4	2	4	0	0	-1	0	0	0	4.010334626567461	
i 1	334.2616394557823	0.2525	71	911	5	1	10	8	0	-1	8	0	0	11.514767055251998	
i 1	334.2696666666667	0.505	69	209	7	1	8	1	0	-1	1	0	0	11.514767055251998	
i 1	334.48595238095237	0.7575000000000001	71	911	2	20	15	2	0	1	2	0	0	3.092081747133257	
i 1	334.5028095238095	0.7575000000000001	71	707	1	24	6	2	0	252	2	307	0	7.092081747133257	
i 1	334.51324489795917	0.505	69	911	5	5	10	1	0	-1	1	0	0	8.121115351221295	
i 1	334.51806122448977	0.2525	71	209	5	24	2	8	0	-1	8	0	0	12.514767055251998	
i 1	334.99558503401363	0.2525	74	209	4	5	11	17	0	2	17	0	0	8.121115351221295	
i 1	335.01003401360543	0.2525	72	911	4	2	9	1	0	-1	1	0	0	4.010334626567461	
i 1	335.01324489795917	0.2525	70	209	1	24	7	2	0	-1	2	0	0	7.092081747133257	
i 1	335.24638775510203	1.01	72	707	4	4	11	2	0	1	2	0	0	4.010334626567461	
i 1	335.25040136054423	0.2525	69	209	3	5	16	1	0	0	1	0	0	8.121115351221295	
i 1	335.2520068027211	0.505	72	209	3	5	1	0	0	-1	0	0	0	8.121115351221295	
i 1	335.4883605442177	0.2525	72	209	5	9	6	2	0	-2	2	0	0	3.010334626567461	
i 1	335.51003401360543	0.2525	74	911	2	20	11	8	0	-2	8	0	0	3.092081747133257	
i 1	335.51886394557823	0.505	73	209	1	20	14	2	0	-1	2	0	0	3.092081747133257	
i 1	335.73113605442177	0.505	74	911	6	1	15	8	0	-2	8	0	0	11.514767055251998	
i 1	335.74879591836736	0.2525	74	209	5	5	5	16	0	1	16	0	0	8.121115351221295	
i 1	335.76324489795917	0.2525	71	209	2	20	12	8	0	1	8	0	0	3.092081747133257	
i 1	335.76886394557823	1.5150000000000001	75	707	4	3	3	2	0	1	2	0	0	4.010334626567461	
i 1	336.00602040816324	1.2625	74	707	5	5	9	16	0	2	16	0	0	8.121115351221295	
i 1	336.00923129251703	2.02	69	707	4	24	16	1	0	-1	1	0	0	12.514767055251998	
i 1	336.0108367346939	0.2525	72	911	4	2	12	1	0	-1	1	0	0	4.010334626567461	
i 1	336.23755782312924	0.2525	72	209	5	9	4	2	0	-2	2	0	0	3.010334626567461	
i 1	336.2383605442177	0.2525	71	911	5	1	11	8	0	-1	8	0	0	11.514767055251998	
i 1	336.25602040816324	0.2525	72	911	4	2	9	0	0	-1	0	0	0	4.010334626567461	
i 1	336.50361224489797	0.2525	71	209	1	20	2	2	0	1	2	0	0	3.092081747133257	
i 1	336.51003401360543	0.2525	72	209	3	5	14	0	0	-1	0	0	0	8.121115351221295	
i 1	336.51485034013604	1.01	71	209	7	1	9	2	0	-1	2	0	0	11.514767055251998	
i 1	336.74959863945577	1.7675	74	707	5	5	6	17	0	2	17	0	0	8.121115351221295	
i 1	336.75923129251703	0.2525	69	209	7	1	10	1	0	-1	1	0	0	11.514767055251998	
i 1	336.9803333333333	0.2525	69	707	5	1	13	1	0	0	1	0	0	11.514767055251998	
i 1	337.00521768707483	0.2525	69	209	3	5	15	1	0	0	1	0	0	8.121115351221295	
i 1	337.23274149659863	0.505	71	209	2	20	4	8	0	1	8	0	0	3.092081747133257	
i 1	337.24076870748297	0.505	74	209	5	5	6	17	0	2	17	0	0	8.121115351221295	
i 1	337.24157142857143	0.2525	75	209	4	9	16	2	0	1	2	0	0	3.010334626567461	
i 1	337.26244217687076	0.505	71	209	5	24	6	8	0	-1	8	0	0	12.514767055251998	
i 1	337.2656530612245	0.505	72	911	4	2	5	0	0	-1	0	0	0	4.010334626567461	
i 1	337.26725850340137	1.7675	72	707	4	4	2	2	0	1	2	0	0	4.010334626567461	
i 1	337.4843469387755	0.2525	69	911	5	5	9	1	0	-1	1	0	0	8.121115351221295	
i 1	337.48996598639457	1.2625	69	707	5	1	9	1	0	0	1	0	0	11.514767055251998	
i 1	337.48996598639457	0.505	72	209	4	3	1	1	0	0	1	0	0	4.010334626567461	
i 1	337.50842857142857	0.505	73	209	1	20	8	2	0	-1	2	0	0	3.092081747133257	
i 1	337.51806122448977	3.0300000000000002	70	209	1	24	9	2	0	-1	2	0	0	7.092081747133257	
i 1	337.73755782312924	0.2525	69	911	5	5	12	1	0	0	1	0	0	8.121115351221295	
i 1	337.74397959183676	0.2525	71	707	1	24	14	2	0	1	2	0	0	7.092081747133257	
i 1	337.7471904761905	0.2525	71	911	2	20	6	2	0	-2	2	0	0	3.092081747133257	
i 1	337.75120408163264	0.2525	74	911	2	20	16	2	0	-2	2	0	0	3.092081747133257	
i 1	337.9835442176871	0.2525	72	911	4	2	11	0	0	-1	0	0	0	4.010334626567461	
i 1	337.99478231292517	0.505	71	209	7	1	12	2	0	-1	2	0	0	11.514767055251998	
i 1	337.99879591836736	0.2525	71	209	2	20	5	2	0	-2	2	0	0	3.092081747133257	
i 1	338.00040136054423	0.2525	69	209	7	1	16	1	0	-1	1	0	0	11.514767055251998	
i 1	338.26244217687076	0.2525	72	209	4	3	10	1	0	0	1	0	0	4.010334626567461	
i 1	338.48595238095237	0.2525	69	209	7	1	9	1	0	-1	1	0	0	11.514767055251998	
i 1	338.48675510204083	1.01	72	911	4	2	13	0	0	-1	0	0	0	4.010334626567461	
i 1	338.50040136054423	1.2625	74	707	5	5	11	16	0	2	16	0	0	8.121115351221295	
i 1	338.73193877551023	12.120000000000001	60	911	5	14	7	0	0	0	0	0	0	2.605531084707703	
i 1	338.73755782312924	1.01	69	707	4	24	4	1	0	-1	1	0	0	12.514767055251998	
i 1	338.74959863945577	0.2525	71	911	6	1	11	8	0	-1	8	0	0	11.514767055251998	
i 1	338.76806122448977	0.2525	71	209	7	1	7	2	0	-1	2	0	0	11.514767055251998	
i 1	338.76806122448977	0.2525	74	707	2	24	1	2	0	-2	2	0	0	7.092081747133257	
i 1	339.00602040816324	1.5150000000000001	71	209	2	20	16	2	0	-2	2	0	0	3.092081747133257	
i 1	339.01003401360543	0.2525	72	209	4	3	8	1	0	0	1	0	0	4.010334626567461	
i 1	339.2479931972789	0.505	72	707	4	4	10	2	0	1	2	0	0	4.010334626567461	
i 1	339.51886394557823	0.2525	75	209	4	9	11	2	0	1	2	0	0	3.010334626567461	
i 1	339.51886394557823	0.2525	71	209	1	24	16	8	0	1	8	0	0	7.092081747133257	
i 1	339.73595238095237	1.7675	72	911	4	2	8	0	0	-1	0	0	0	4.010334626567461	
i 1	339.7391632653061	1.7675	74	595	4	24	7	2	0	-2	2	0	0	12.514767055251998	
i 1	339.7391632653061	1.7675	71	209	1	24	2	8	0	248	8	308	0	7.092081747133257	
i 1	339.73996598639457	1.2625	72	595	5	5	4	1	0	0	1	0	0	8.121115351221295	
i 1	339.74638775510203	0.7575000000000001	69	595	4	3	14	0	0	0	0	0	0	4.010334626567461	
i 1	339.75441496598637	0.2525	71	209	2	20	13	2	0	-2	2	0	0	3.092081747133257	
i 1	339.7664557823129	8.08	67	595	4	7	4	0	0	1	0	0	0	1.3027655423538516	
i 1	339.9835442176871	0.2525	69	209	4	4	13	0	0	0	0	0	0	4.010334626567461	
i 1	340.2656530612245	1.2625	71	209	1	20	15	8	0	-2	8	0	0	3.092081747133257	
i 1	340.26886394557823	0.2525	69	209	3	5	14	1	0	0	1	0	0	8.121115351221295	
i 1	340.49237414965984	0.505	74	911	6	1	5	8	0	-2	8	0	0	11.514767055251998	
i 1	340.50120408163264	0.2525	72	911	4	2	14	1	0	-1	1	0	0	4.010334626567461	
i 1	340.50602040816324	0.2525	72	209	4	9	11	2	0	-2	2	0	0	3.010334626567461	
i 1	340.51244217687076	1.2625	69	911	5	5	8	1	0	0	1	0	0	8.121115351221295	
i 1	340.75923129251703	0.2525	71	209	2	20	3	2	0	-2	2	0	0	3.092081747133257	
i 1	340.7656530612245	0.2525	69	209	4	4	10	0	0	0	0	0	0	4.010334626567461	
i 1	340.99558503401363	0.2525	74	209	5	5	4	17	0	2	17	0	0	8.121115351221295	
i 1	340.99558503401363	0.2525	73	209	1	20	13	2	0	-1	2	0	0	3.092081747133257	
i 1	341.0028095238095	0.2525	72	911	4	2	10	1	0	-1	1	0	0	4.010334626567461	
i 1	341.00602040816324	0.7575000000000001	69	595	4	3	11	0	0	0	0	0	0	4.010334626567461	
i 1	341.24397959183676	0.2525	72	209	4	5	12	0	0	-1	0	0	0	8.121115351221295	
i 1	341.24638775510203	0.2525	72	595	5	5	11	1	0	0	1	0	0	8.121115351221295	
i 1	341.2616394557823	2.2725	69	595	4	4	15	1	0	-1	1	0	0	4.010334626567461	
i 1	341.51324489795917	0.2525	74	595	2	20	8	2	0	1	2	0	0	3.092081747133257	
i 1	341.73193877551023	2.2725	71	595	6	1	3	8	0	-2	8	0	0	11.514767055251998	
i 1	341.73996598639457	10.605	60	911	5	14	3	5	0	1	5	0	0	2.605531084707703	
i 1	341.74478231292517	2.2725	69	911	6	5	13	1	0	0	1	0	0	8.121115351221295	
i 1	341.75361224489797	0.2525	74	209	1	24	2	2	0	1	2	0	0	7.092081747133257	
i 1	341.7664557823129	0.2525	72	911	4	2	16	1	0	-1	1	0	0	4.010334626567461	
i 1	341.76886394557823	0.2525	72	911	4	2	5	0	0	-1	0	0	0	4.010334626567461	
i 1	341.9883605442177	0.2525	72	209	4	9	6	2	0	-2	2	0	0	3.010334626567461	
i 1	341.99879591836736	0.505	70	209	2	24	5	2	0	-1	2	0	0	7.092081747133257	
i 1	342.23675510204083	0.2525	69	595	4	3	14	0	0	0	0	0	0	4.010334626567461	
i 1	342.24237414965984	0.2525	71	209	1	20	6	2	0	1	2	0	0	3.092081747133257	
i 1	342.25521768707483	0.505	71	911	6	1	2	8	0	-1	8	0	0	11.514767055251998	
i 1	342.2664557823129	0.2525	69	209	4	4	11	0	0	0	0	0	0	4.010334626567461	
i 1	342.26725850340137	0.2525	74	209	1	24	14	2	0	1	2	0	0	7.092081747133257	
i 1	342.4835442176871	0.2525	71	911	2	20	3	2	0	1	2	0	0	3.092081747133257	
i 1	342.51485034013604	0.7575000000000001	71	595	2	20	5	8	0	1	8	0	0	3.092081747133257	
i 1	342.7335442176871	0.2525	74	911	6	1	14	8	0	-2	8	0	0	11.514767055251998	
i 1	342.74397959183676	2.02	69	595	4	3	3	0	0	0	0	0	0	4.010334626567461	
i 1	342.74879591836736	0.2525	69	911	5	5	14	1	0	-1	1	0	0	8.121115351221295	
i 1	342.76324489795917	2.02	69	595	5	5	13	0	0	0	0	0	0	8.121115351221295	
i 1	343.01003401360543	0.505	69	209	5	1	4	1	0	-1	1	0	0	11.514767055251998	
i 1	343.01886394557823	1.2625	74	595	4	24	3	2	0	-2	2	0	0	12.514767055251998	
i 1	343.23113605442177	0.2525	72	595	5	5	2	1	0	0	1	0	0	8.121115351221295	
i 1	343.25441496598637	1.01	71	209	1	24	13	8	0	-2	8	0	0	7.092081747133257	
i 1	343.25842857142857	0.2525	69	209	4	4	1	0	0	0	0	0	0	4.010334626567461	
i 1	343.2664557823129	0.505	71	209	1	20	8	2	0	-2	2	0	0	3.092081747133257	
i 1	343.49397959183676	0.2525	72	209	4	5	2	0	0	-1	0	0	0	8.121115351221295	
i 1	343.49558503401363	0.2525	71	911	6	1	10	8	0	-1	8	0	0	11.514767055251998	
i 1	343.5020068027211	0.2525	72	209	4	9	4	2	0	-2	2	0	0	3.010334626567461	
i 1	343.5108367346939	0.505	72	911	4	2	9	1	0	-1	1	0	0	4.010334626567461	
i 1	343.73755782312924	0.2525	75	209	4	9	15	2	0	1	2	0	0	3.010334626567461	
i 1	343.73996598639457	0.2525	71	209	5	24	10	8	0	-1	8	0	0	12.514767055251998	
i 1	343.7696666666667	0.2525	69	911	5	5	5	1	0	-1	1	0	0	8.121115351221295	
i 1	343.98514965986396	0.7575000000000001	74	911	6	1	12	8	0	-2	8	0	0	11.514767055251998	
i 1	344.00762585034016	0.505	69	209	4	4	2	0	0	0	0	0	0	4.010334626567461	
i 1	344.00762585034016	1.01	70	209	2	24	9	2	0	-1	2	0	0	7.092081747133257	
i 1	344.23595238095237	0.2525	71	595	2	20	7	2	0	1	2	0	0	3.092081747133257	
i 1	344.23755782312924	0.2525	74	209	5	5	11	16	0	1	16	0	0	8.121115351221295	
i 1	344.23755782312924	0.2525	74	595	2	24	16	2	0	1	2	0	0	7.092081747133257	
i 1	344.2391632653061	1.01	71	595	6	1	8	8	0	-2	8	0	0	11.514767055251998	
i 1	344.2471904761905	1.2625	69	595	4	4	16	1	0	-1	1	0	0	4.010334626567461	
i 1	344.4979931972789	0.2525	71	209	1	24	11	2	0	1	2	0	0	7.092081747133257	
i 1	344.50361224489797	0.2525	72	209	4	5	9	0	0	-1	0	0	0	8.121115351221295	
i 1	344.50441496598637	0.2525	69	911	6	5	2	1	0	0	1	0	0	8.121115351221295	
i 1	344.51003401360543	0.2525	71	209	1	20	13	2	0	-2	2	0	0	3.092081747133257	
i 1	344.74478231292517	0.2525	72	911	4	2	9	1	0	-1	1	0	0	4.010334626567461	
i 1	344.75842857142857	1.01	69	911	6	5	3	1	0	-1	1	0	0	8.121115351221295	
i 1	344.75842857142857	0.505	74	595	2	20	8	8	0	1	8	0	0	3.092081747133257	
i 1	344.76404761904763	0.505	69	209	4	5	7	1	0	0	1	0	0	8.121115351221295	
i 1	344.7664557823129	0.2525	69	209	5	1	9	1	0	-1	1	0	0	11.514767055251998	
i 1	344.98113605442177	1.7675	72	911	6	2	14	0	0	-1	0	0	0	4.010334626567461	
i 1	344.99157142857143	2.525	74	595	4	24	2	2	0	-2	2	0	0	12.514767055251998	
i 1	345.01485034013604	0.2525	71	595	2	24	15	2	0	-2	2	0	0	7.092081747133257	
i 1	345.2303333333333	0.2525	71	209	5	24	11	8	0	-1	8	0	0	12.514767055251998	
i 1	345.23113605442177	0.2525	72	209	3	3	14	1	0	0	1	0	0	4.010334626567461	
i 1	345.2383605442177	0.2525	71	911	6	1	2	8	0	-1	8	0	0	11.514767055251998	
i 1	345.2383605442177	0.2525	74	209	1	20	11	2	0	1	2	0	0	3.092081747133257	
i 1	345.24397959183676	2.02	69	595	5	5	15	0	0	0	0	0	0	8.121115351221295	
i 1	345.26806122448977	0.2525	74	209	5	5	13	16	0	1	16	0	0	8.121115351221295	
i 1	345.26806122448977	3.0300000000000002	74	209	1	24	16	2	0	1	2	0	0	7.092081747133257	
i 1	345.4835442176871	0.2525	69	209	5	1	9	1	0	-1	1	0	0	11.514767055251998	
i 1	345.49558503401363	0.2525	69	209	3	4	5	0	0	0	0	0	0	4.010334626567461	
i 1	345.4971904761905	0.2525	69	911	6	5	15	1	0	0	1	0	0	8.121115351221295	
i 1	345.5028095238095	0.2525	69	595	4	3	16	0	0	0	0	0	0	4.010334626567461	
i 1	345.76324489795917	0.2525	71	595	6	1	11	8	0	-2	8	0	0	11.514767055251998	
i 1	345.98113605442177	0.505	72	595	5	5	3	1	0	0	1	0	0	8.121115351221295	
i 1	346.00842857142857	0.505	71	209	5	24	14	8	0	-1	8	0	0	12.514767055251998	
i 1	346.01404761904763	0.2525	73	209	2	20	3	2	0	-1	2	0	0	3.092081747133257	
i 1	346.0196666666667	0.2525	72	209	4	5	2	0	0	-1	0	0	0	8.121115351221295	
i 1	346.25120408163264	0.2525	70	209	2	24	16	2	0	-1	2	0	0	7.092081747133257	
i 1	346.48996598639457	1.7675	69	911	6	5	4	1	0	-1	1	0	0	8.121115351221295	
i 1	346.49237414965984	2.7775	71	595	6	1	3	8	0	-2	8	0	0	11.514767055251998	
i 1	346.4971904761905	0.2525	74	209	2	20	3	8	0	1	8	0	0	3.092081747133257	
i 1	346.50762585034016	2.525	70	209	1	24	2	2	0	252	2	307	0	7.092081747133257	
i 1	346.51806122448977	0.2525	69	209	5	1	8	1	0	-1	1	0	0	11.514767055251998	
i 1	346.74076870748297	0.2525	71	209	5	24	9	8	0	-1	8	0	0	12.514767055251998	
i 1	346.74237414965984	0.2525	69	911	6	5	11	1	0	0	1	0	0	8.121115351221295	
i 1	346.7696666666667	1.7675	69	595	4	4	13	1	0	-1	1	0	0	4.010334626567461	
i 1	346.9835442176871	0.2525	72	595	5	5	11	1	0	0	1	0	0	8.121115351221295	
i 1	346.98675510204083	0.505	75	209	4	9	1	2	0	1	2	0	0	3.010334626567461	
i 1	347.0068231292517	0.2525	74	911	6	1	14	8	0	-2	8	0	0	11.514767055251998	
i 1	347.24959863945577	0.2525	73	209	2	20	8	2	0	-1	2	0	0	3.092081747133257	
i 1	347.49638775510203	0.2525	71	911	6	1	5	8	0	-1	8	0	0	11.514767055251998	
i 1	347.50040136054423	0.505	72	209	4	5	8	0	0	-1	0	0	0	8.121115351221295	
i 1	347.50361224489797	0.2525	74	209	2	20	16	2	0	-2	2	0	0	3.092081747133257	
i 1	347.50521768707483	0.2525	69	209	4	5	4	1	0	0	1	0	0	8.121115351221295	
i 1	347.74076870748297	12.120000000000001	67	595	6	7	12	0	0	1	0	0	0	1.3027655423538516	
i 1	347.74638775510203	0.2525	74	911	6	1	6	8	0	-2	8	0	0	11.514767055251998	
i 1	347.74959863945577	0.505	74	209	1	20	1	2	0	1	2	0	0	3.092081747133257	
i 1	347.7520068027211	0.2525	69	209	5	1	2	1	0	-1	1	0	0	11.514767055251998	
i 1	347.7664557823129	0.505	69	595	6	5	9	0	0	0	0	0	0	8.121115351221295	
i 1	347.98274149659863	0.2525	72	209	3	3	13	1	0	0	1	0	0	4.010334626567461	
i 1	348.00602040816324	0.2525	74	209	5	5	9	17	0	2	17	0	0	8.121115351221295	
i 1	348.01404761904763	0.2525	72	209	4	9	10	2	0	-2	2	0	0	3.010334626567461	
i 1	348.23755782312924	0.2525	71	595	2	20	1	2	0	1	2	0	0	3.092081747133257	
i 1	348.2383605442177	2.525	72	911	6	2	5	0	0	-1	0	0	0	4.010334626567461	
i 1	348.24157142857143	0.2525	71	209	4	24	11	8	0	-1	8	0	0	12.514767055251998	
i 1	348.25762585034016	0.2525	74	209	5	5	7	16	0	1	16	0	0	8.121115351221295	
i 1	348.26324489795917	1.2625	72	595	5	5	13	1	0	0	1	0	0	8.121115351221295	
i 1	348.26886394557823	0.7575000000000001	69	595	4	3	2	0	0	0	0	0	0	4.010334626567461	
i 1	348.48595238095237	1.01	74	209	1	24	6	2	0	-2	2	0	0	7.092081747133257	
i 1	348.49397959183676	1.7675	74	911	6	1	16	8	0	-2	8	0	0	11.514767055251998	
i 1	348.49397959183676	0.7575000000000001	71	209	1	20	16	2	0	1	2	0	0	3.092081747133257	
i 1	348.4979931972789	0.505	69	911	6	5	2	1	0	-1	1	0	0	8.121115351221295	
i 1	348.51244217687076	0.2525	69	209	4	5	3	1	0	0	1	0	0	8.121115351221295	
i 1	348.74558503401363	0.2525	73	209	2	20	12	2	0	-1	2	0	0	3.092081747133257	
i 1	348.75040136054423	0.2525	69	209	5	1	14	1	0	-1	1	0	0	11.514767055251998	
i 1	348.7608367346939	0.2525	69	595	4	4	2	1	0	-1	1	0	0	4.010334626567461	
i 1	348.76806122448977	2.2725	69	911	4	5	12	1	0	0	1	0	0	8.121115351221295	
i 1	349.00361224489797	0.7575000000000001	74	209	5	5	1	16	0	1	16	0	0	8.121115351221295	
i 1	349.00361224489797	1.5150000000000001	70	209	2	24	1	2	0	-1	2	0	0	7.092081747133257	
i 1	349.00441496598637	0.2525	74	209	1	24	14	2	0	1	2	0	0	7.092081747133257	
i 1	349.0164557823129	0.2525	72	209	4	9	13	2	0	-2	2	0	0	3.010334626567461	
i 1	349.23274149659863	0.2525	71	595	2	24	13	2	0	1	2	0	0	7.092081747133257	
i 1	349.2383605442177	0.2525	69	209	6	1	15	1	0	-1	1	0	0	11.514767055251998	
i 1	349.2391632653061	0.2525	71	209	4	1	9	2	0	-1	2	0	0	11.514767055251998	
i 1	349.26806122448977	0.2525	74	595	2	20	5	2	0	-2	2	0	0	3.092081747133257	
i 1	349.49638775510203	0.2525	69	209	5	1	13	1	0	-1	1	0	0	11.514767055251998	
i 1	349.49959863945577	0.505	74	209	1	24	16	2	0	1	2	0	0	7.092081747133257	
i 1	349.50521768707483	1.7675	71	595	6	1	10	8	0	-2	8	0	0	11.514767055251998	
i 1	349.50923129251703	0.2525	74	209	5	5	11	17	0	2	17	0	0	8.121115351221295	
i 1	349.5164557823129	0.505	69	595	4	4	10	1	0	-1	1	0	0	4.010334626567461	
i 1	349.73274149659863	0.2525	69	209	4	5	13	1	0	0	1	0	0	8.121115351221295	
i 1	349.76244217687076	0.505	72	209	4	5	4	0	0	-1	0	0	0	8.121115351221295	
i 1	349.9803333333333	2.02	74	209	1	24	8	2	0	-2	2	0	0	7.092081747133257	
i 1	349.9835442176871	0.2525	72	911	6	2	6	1	0	-1	1	0	0	4.010334626567461	
i 1	349.98514965986396	0.7575000000000001	69	595	4	3	5	0	0	0	0	0	0	4.010334626567461	
i 1	349.9883605442177	0.2525	74	595	2	20	15	2	0	1	2	0	0	3.092081747133257	
i 1	349.99959863945577	0.505	69	911	6	5	7	1	0	-1	1	0	0	8.121115351221295	
i 1	350.00361224489797	0.2525	74	595	2	24	14	2	0	-2	2	0	0	7.092081747133257	
i 1	350.0068231292517	0.2525	71	911	6	1	13	8	0	-1	8	0	0	11.514767055251998	
i 1	350.2383605442177	1.7675	74	209	1	20	5	8	0	-2	8	0	0	3.092081747133257	
i 1	350.24076870748297	0.2525	74	209	5	5	12	16	0	1	16	0	0	8.121115351221295	
i 1	350.24237414965984	4.2925	74	595	4	24	10	2	0	-2	2	0	0	12.514767055251998	
i 1	350.25602040816324	0.505	72	209	4	9	15	2	0	-2	2	0	0	3.010334626567461	
i 1	350.25842857142857	0.2525	74	209	1	24	8	2	0	1	2	0	0	7.092081747133257	
i 1	350.26324489795917	0.505	71	209	4	24	1	8	0	-1	8	0	0	12.514767055251998	
i 1	350.5020068027211	0.2525	74	209	5	5	5	17	0	2	17	0	0	8.121115351221295	
i 1	350.50361224489797	3.2825	69	595	6	5	5	0	0	0	0	0	0	8.121115351221295	
i 1	350.73595238095237	0.505	69	911	4	5	9	1	0	-1	1	0	0	8.121115351221295	
i 1	350.73675510204083	0.2525	74	209	2	20	16	2	0	1	2	0	0	3.092081747133257	
i 1	350.74157142857143	0.2525	69	595	4	4	2	1	0	-1	1	0	0	4.010334626567461	
i 1	350.7479931972789	0.2525	69	209	6	1	6	1	0	-1	1	0	0	11.514767055251998	
i 1	350.74959863945577	1.5150000000000001	60	911	3	14	11	0	0	0	0	0	0	2.605531084707703	
i 1	350.75923129251703	0.2525	72	911	6	2	8	1	0	-1	1	0	0	4.010334626567461	
i 1	350.75923129251703	0.7575000000000001	69	595	5	3	9	0	0	0	0	0	0	4.010334626567461	
i 1	350.99237414965984	0.2525	72	209	3	3	7	1	0	0	1	0	0	4.010334626567461	
i 1	351.00040136054423	0.2525	74	911	6	1	3	8	0	-2	8	0	0	11.514767055251998	
i 1	351.00120408163264	0.2525	72	595	6	5	7	1	0	0	1	0	0	8.121115351221295	
i 1	351.00521768707483	0.2525	72	911	6	2	8	0	0	-1	0	0	0	4.010334626567461	
i 1	351.00842857142857	0.2525	70	209	2	24	6	2	0	-1	2	0	0	7.092081747133257	
i 1	351.23675510204083	2.525	69	595	4	4	15	1	0	-1	1	0	0	4.010334626567461	
i 1	351.24076870748297	0.7575000000000001	74	209	5	5	3	16	0	1	16	0	0	8.121115351221295	
i 1	351.2471904761905	0.2525	74	209	1	24	13	2	0	1	2	0	0	7.092081747133257	
i 1	351.26324489795917	0.2525	74	209	5	5	2	17	0	2	17	0	0	8.121115351221295	
i 1	351.48113605442177	0.2525	72	911	6	2	15	1	0	-1	1	0	0	4.010334626567461	
i 1	351.50040136054423	0.505	74	209	1	24	9	2	0	248	2	308	0	7.092081747133257	
i 1	351.50120408163264	0.7575000000000001	73	209	2	20	4	2	0	-1	2	0	0	3.092081747133257	
i 1	351.51806122448977	0.7575000000000001	74	209	2	20	14	2	0	-2	2	0	0	3.092081747133257	
i 1	351.73514965986396	0.2525	69	911	4	5	15	1	0	-1	1	0	0	8.121115351221295	
i 1	351.73595238095237	0.2525	72	209	3	3	8	1	0	0	1	0	0	4.010334626567461	
i 1	351.74157142857143	0.2525	71	911	6	1	14	8	0	-1	8	0	0	11.514767055251998	
i 1	351.76886394557823	0.2525	75	209	4	9	6	2	0	1	2	0	0	3.010334626567461	
i 1	351.9931768707483	0.2525	70	209	2	24	7	2	0	-1	2	0	0	7.092081747133257	
i 1	351.99959863945577	0.2525	74	209	1	24	16	2	0	1	2	0	0	7.092081747133257	
i 1	352.01324489795917	0.2525	74	209	5	5	6	17	0	2	17	0	0	8.121115351221295	
i 1	352.01886394557823	0.2525	72	595	6	5	9	1	0	0	1	0	0	8.121115351221295	
i 1	352.2335442176871	2.02	71	1093	1	24	4	2	0	1	2	0	0	7.092081747133257	
i 1	352.23755782312924	0.2525	74	1093	1	20	10	2	0	-2	2	0	0	3.092081747133257	
i 1	352.24478231292517	0.505	71	595	2	24	4	2	0	-2	2	0	0	7.092081747133257	
i 1	352.25762585034016	1.5150000000000001	60	1093	5	14	9	0	0	1	0	0	0	2.605531084707703	
i 1	352.25923129251703	0.505	74	1093	5	1	7	8	0	-1	8	0	0	11.514767055251998	
i 1	352.26324489795917	0.505	69	1093	4	5	13	1	0	-1	1	0	0	8.121115351221295	
i 1	352.26485034013604	7.575	60	1093	3	14	3	0	0	1	0	0	0	2.605531084707703	
i 1	352.26725850340137	0.2525	74	1093	2	20	9	2	0	-2	2	0	0	3.092081747133257	
i 1	352.4931768707483	0.2525	72	279	4	5	5	1	0	0	1	0	0	8.121115351221295	
i 1	352.49478231292517	0.7575000000000001	71	595	6	1	9	8	0	-2	8	0	0	11.514767055251998	
i 1	352.49638775510203	0.7575000000000001	71	279	1	24	12	8	0	1	8	0	0	7.092081747133257	
i 1	352.73113605442177	0.7575000000000001	69	279	4	5	16	0	0	0	0	0	0	8.121115351221295	
i 1	352.75040136054423	0.2525	74	279	1	24	4	8	0	-2	8	0	0	7.092081747133257	
i 1	352.7520068027211	0.2525	71	279	4	1	14	2	0	-1	2	0	0	11.514767055251998	
i 1	352.98595238095237	0.2525	71	1093	6	1	16	8	0	-2	8	0	0	11.514767055251998	
i 1	352.99157142857143	0.2525	71	595	2	24	15	2	0	-2	2	0	0	7.092081747133257	
i 1	352.9931768707483	0.2525	69	1093	3	9	2	1	0	0	1	0	0	3.010334626567461	
i 1	352.9931768707483	0.2525	69	1093	4	5	6	0	0	0	0	0	0	8.121115351221295	
i 1	352.99959863945577	0.2525	74	595	2	20	5	8	0	-2	8	0	0	3.092081747133257	
i 1	353.0068231292517	0.2525	74	1093	2	20	16	8	0	-2	8	0	0	3.092081747133257	
i 1	353.00762585034016	0.505	69	595	5	3	12	0	0	0	0	0	0	4.010334626567461	
i 1	353.24478231292517	0.2525	74	1093	1	20	6	2	0	-2	2	0	0	3.092081747133257	
i 1	353.24638775510203	0.505	74	1093	1	20	11	8	0	-2	8	0	0	3.092081747133257	
i 1	353.25762585034016	0.505	72	279	4	5	2	1	0	0	1	0	0	8.121115351221295	
i 1	353.25923129251703	0.505	72	279	3	3	16	1	0	0	1	0	0	4.010334626567461	
i 1	353.48675510204083	1.2625	69	1093	4	5	5	0	0	-1	0	0	0	8.121115351221295	
i 1	353.51324489795917	2.02	72	1093	6	2	14	0	0	-1	0	0	0	4.010334626567461	
i 1	353.73113605442177	0.2525	72	279	3	4	16	1	0	0	1	0	0	4.010334626567461	
i 1	353.73113605442177	0.2525	74	1093	1	20	15	2	0	-2	2	0	0	3.092081747133257	
i 1	353.73193877551023	0.2525	74	1093	6	1	12	8	0	-1	8	0	0	11.514767055251998	
i 1	353.73755782312924	0.505	69	595	4	4	6	1	0	-1	1	0	0	4.010334626567461	
i 1	353.73755782312924	0.2525	69	595	4	5	13	0	0	0	0	0	0	8.121115351221295	
i 1	353.7431768707483	9.09	60	1093	3	14	16	0	0	1	0	0	0	2.605531084707703	
i 1	353.74959863945577	1.7675	71	595	6	1	8	8	0	-2	8	0	0	11.514767055251998	
i 1	353.75762585034016	0.2525	72	595	6	5	4	1	0	0	1	0	0	8.121115351221295	
i 1	353.98595238095237	1.2625	74	279	1	20	11	2	0	1	2	0	0	3.092081747133257	
i 1	353.98755782312924	0.505	72	1093	4	5	7	1	0	-1	1	0	0	8.121115351221295	
i 1	353.98996598639457	0.2525	74	279	1	24	13	2	0	1	2	0	0	7.092081747133257	
i 1	353.99237414965984	0.2525	72	279	4	5	12	1	0	0	1	0	0	8.121115351221295	
i 1	354.00923129251703	1.2625	71	279	1	24	11	8	0	1	8	0	0	7.092081747133257	
i 1	354.0116394557823	0.505	74	1093	5	1	8	8	0	-1	8	0	0	11.514767055251998	
i 1	354.0116394557823	0.505	72	279	3	3	14	1	0	0	1	0	0	4.010334626567461	
i 1	354.24638775510203	2.2725	72	595	6	5	13	1	0	0	1	0	0	8.121115351221295	
i 1	354.48595238095237	0.2525	71	1093	6	1	10	8	0	-2	8	0	0	11.514767055251998	
i 1	354.48595238095237	1.7675	69	595	4	4	7	1	0	-1	1	0	0	4.010334626567461	
i 1	354.48675510204083	0.2525	74	1093	1	20	16	2	0	-2	2	0	0	3.092081747133257	
i 1	354.4931768707483	0.505	74	1093	5	1	5	8	0	-1	8	0	0	11.514767055251998	
i 1	354.50602040816324	0.505	69	279	4	5	6	0	0	0	0	0	0	8.121115351221295	
i 1	354.73274149659863	0.2525	72	279	4	5	11	1	0	0	1	0	0	8.121115351221295	
i 1	354.75602040816324	2.525	71	1093	1	24	15	2	0	1	2	0	0	7.092081747133257	
i 1	354.76244217687076	0.2525	72	1093	3	9	8	0	0	0	0	0	0	3.010334626567461	
i 1	354.76886394557823	0.505	74	1093	1	20	9	8	0	-2	8	0	0	3.092081747133257	
i 1	354.9835442176871	1.5150000000000001	71	1093	6	1	5	8	0	-2	8	0	0	11.514767055251998	
i 1	354.99237414965984	0.2525	69	1093	4	5	5	0	0	-1	0	0	0	8.121115351221295	
i 1	354.9971904761905	0.2525	71	279	5	1	3	2	0	-1	2	0	0	11.514767055251998	
i 1	355.00361224489797	0.2525	69	1093	6	2	12	1	0	0	1	0	0	4.010334626567461	
i 1	355.01244217687076	0.7575000000000001	71	279	1	20	8	2	0	1	2	0	0	3.092081747133257	
i 1	355.0196666666667	0.2525	69	1093	4	5	8	1	0	-1	1	0	0	8.121115351221295	
i 1	355.23113605442177	0.2525	71	595	2	20	7	2	0	-2	2	0	0	3.092081747133257	
i 1	355.23996598639457	0.2525	74	595	4	24	13	2	0	-2	2	0	0	12.514767055251998	
i 1	355.2431768707483	0.2525	74	1093	2	20	1	8	0	-2	8	0	0	3.092081747133257	
i 1	355.25923129251703	0.2525	69	595	4	5	10	0	0	0	0	0	0	8.121115351221295	
i 1	355.25923129251703	0.2525	69	1093	6	5	12	0	0	0	0	0	0	8.121115351221295	
i 1	355.2656530612245	1.5150000000000001	69	595	5	3	13	0	0	0	0	0	0	4.010334626567461	
i 1	355.4971904761905	1.7675	74	1093	1	20	11	8	0	-2	8	0	0	3.092081747133257	
i 1	355.49959863945577	0.2525	74	279	1	20	1	2	0	-2	2	0	0	3.092081747133257	
i 1	355.5020068027211	0.505	72	1093	3	9	6	0	0	0	0	0	0	3.010334626567461	
i 1	355.5116394557823	2.02	69	1093	4	5	8	1	0	-1	1	0	0	8.121115351221295	
i 1	355.51886394557823	0.505	72	279	4	5	5	1	0	0	1	0	0	8.121115351221295	
i 1	355.74076870748297	0.2525	71	279	4	24	1	8	0	-2	8	0	0	12.514767055251998	
i 1	355.76806122448977	0.2525	74	595	4	24	7	2	0	-2	2	0	0	12.514767055251998	
i 1	355.99076870748297	0.7575000000000001	71	279	1	24	2	2	0	252	2	307	0	7.092081747133257	
i 1	355.99959863945577	0.2525	69	595	4	5	4	0	0	0	0	0	0	8.121115351221295	
i 1	356.00842857142857	0.505	74	1093	5	1	7	8	0	-1	8	0	0	11.514767055251998	
i 1	356.01324489795917	0.2525	74	1093	1	20	14	2	0	-2	2	0	0	3.092081747133257	
i 1	356.01404761904763	2.7775	71	595	6	1	3	8	0	-2	8	0	0	11.514767055251998	
i 1	356.01886394557823	0.2525	72	279	3	4	14	1	0	0	1	0	0	4.010334626567461	
i 1	356.24397959183676	0.2525	69	1093	6	5	14	0	0	0	0	0	0	8.121115351221295	
i 1	356.2568231292517	0.505	74	1093	1	20	9	2	0	-2	2	0	0	3.092081747133257	
i 1	356.26324489795917	0.2525	69	1093	3	9	9	1	0	0	1	0	0	3.010334626567461	
i 1	356.26886394557823	0.2525	72	279	3	3	12	1	0	0	1	0	0	4.010334626567461	
i 1	356.48514965986396	0.2525	71	279	4	24	11	8	0	-2	8	0	0	12.514767055251998	
i 1	356.50120408163264	0.2525	74	595	4	24	14	2	0	-2	2	0	0	12.514767055251998	
i 1	356.73274149659863	0.505	72	279	4	5	8	1	0	0	1	0	0	8.121115351221295	
i 1	356.7391632653061	0.2525	72	279	3	4	6	1	0	0	1	0	0	4.010334626567461	
i 1	356.7431768707483	0.2525	69	1093	4	5	8	0	0	-1	0	0	0	8.121115351221295	
i 1	356.74478231292517	3.0300000000000002	71	279	1	20	12	2	0	1	2	0	0	3.092081747133257	
i 1	356.74558503401363	0.2525	71	1093	6	1	9	8	0	-2	8	0	0	11.514767055251998	
i 1	356.7471904761905	0.2525	74	1093	5	1	15	8	0	-1	8	0	0	11.514767055251998	
i 1	356.75521768707483	2.02	69	595	4	4	2	1	0	-1	1	0	0	4.010334626567461	
i 1	356.75521768707483	0.7575000000000001	71	279	1	24	7	2	0	-2	2	0	0	7.092081747133257	
i 1	356.7656530612245	0.7575000000000001	69	595	5	3	1	0	0	0	0	0	0	4.010334626567461	
i 1	356.99157142857143	5.3025	69	595	4	5	12	0	0	0	0	0	0	8.121115351221295	
i 1	357.00842857142857	0.505	72	1093	6	2	7	0	0	-1	0	0	0	4.010334626567461	
i 1	357.2343469387755	0.2525	72	595	4	5	11	1	0	0	1	0	0	8.121115351221295	
i 1	357.23996598639457	0.2525	74	279	1	20	3	2	0	-2	2	0	0	3.092081747133257	
i 1	357.25040136054423	1.2625	71	1093	6	1	6	8	0	-2	8	0	0	11.514767055251998	
i 1	357.48193877551023	0.2525	74	595	2	20	8	8	0	1	8	0	0	3.092081747133257	
i 1	357.49237414965984	0.2525	74	595	2	24	14	2	0	1	2	0	0	7.092081747133257	
i 1	357.50762585034016	0.2525	72	279	3	4	10	1	0	0	1	0	0	4.010334626567461	
i 1	357.51485034013604	0.505	72	1093	5	9	3	0	0	0	0	0	0	3.010334626567461	
i 1	357.51725850340137	0.7575000000000001	72	279	4	5	11	1	0	0	1	0	0	8.121115351221295	
i 1	357.51886394557823	0.2525	69	279	4	5	16	0	0	0	0	0	0	8.121115351221295	
i 1	357.73675510204083	0.505	74	279	1	24	5	2	0	1	2	0	0	7.092081747133257	
i 1	357.74638775510203	0.2525	74	1093	6	1	3	8	0	-1	8	0	0	11.514767055251998	
i 1	357.75120408163264	0.505	69	1093	4	5	10	0	0	-1	0	0	0	8.121115351221295	
i 1	357.7568231292517	2.02	69	595	5	3	13	0	0	0	0	0	0	4.010334626567461	
i 1	357.98514965986396	2.02	74	595	4	24	9	2	0	-2	2	0	0	12.514767055251998	
i 1	357.98514965986396	0.7575000000000001	71	279	1	24	5	8	0	1	8	0	0	7.092081747133257	
i 1	358.00521768707483	0.2525	74	1093	1	20	4	2	0	-2	2	0	0	3.092081747133257	
i 1	358.00923129251703	0.2525	69	1093	3	9	10	1	0	0	1	0	0	3.010334626567461	
i 1	358.23274149659863	0.2525	69	1093	4	5	15	1	0	-1	1	0	0	8.121115351221295	
i 1	358.24959863945577	0.2525	74	1093	2	20	11	2	0	-2	2	0	0	3.092081747133257	
i 1	358.2656530612245	0.2525	72	1093	5	9	14	0	0	0	0	0	0	3.010334626567461	
i 1	358.2664557823129	0.2525	71	595	2	24	12	2	0	1	2	0	0	7.092081747133257	
i 1	358.26725850340137	0.2525	69	279	4	5	8	0	0	0	0	0	0	8.121115351221295	
i 1	358.4883605442177	0.2525	71	279	5	24	3	8	0	-2	8	0	0	12.514767055251998	
i 1	358.50361224489797	0.2525	72	595	4	5	10	1	0	0	1	0	0	8.121115351221295	
i 1	358.50521768707483	1.01	74	279	1	24	2	2	0	1	2	0	0	7.092081747133257	
i 1	358.50602040816324	0.2525	72	279	4	5	5	1	0	0	1	0	0	8.121115351221295	
i 1	358.7431768707483	0.505	69	1093	6	5	4	0	0	0	0	0	0	8.121115351221295	
i 1	358.74478231292517	0.2525	74	1093	6	1	7	8	0	-1	8	0	0	11.514767055251998	
i 1	358.75120408163264	0.2525	72	279	3	3	12	1	0	0	1	0	0	4.010334626567461	
i 1	358.7616394557823	0.2525	72	1093	6	5	3	1	0	-1	1	0	0	8.121115351221295	
i 1	358.76725850340137	0.2525	74	1093	5	1	5	8	0	-1	8	0	0	11.514767055251998	
i 1	358.76886394557823	0.2525	69	1093	3	9	6	1	0	0	1	0	0	3.010334626567461	
i 1	358.98595238095237	0.7575000000000001	69	595	4	4	5	1	0	-1	1	0	0	4.010334626567461	
i 1	358.98595238095237	1.7675	69	1093	4	5	2	0	0	-1	0	0	0	8.121115351221295	
i 1	358.9883605442177	0.2525	71	1093	6	1	11	8	0	-2	8	0	0	11.514767055251998	
i 1	358.99397959183676	0.7575000000000001	71	279	5	1	16	2	0	-1	2	0	0	11.514767055251998	
i 1	359.00602040816324	0.505	72	279	3	4	13	1	0	0	1	0	0	4.010334626567461	
i 1	359.2343469387755	1.7675	74	1093	1	20	2	2	0	-2	2	0	0	3.092081747133257	
i 1	359.23675510204083	1.7675	71	595	6	1	14	8	0	-2	8	0	0	11.514767055251998	
i 1	359.2479931972789	0.2525	72	279	4	5	15	1	0	0	1	0	0	8.121115351221295	
i 1	359.49397959183676	0.7575000000000001	71	279	1	24	8	8	0	1	8	0	0	7.092081747133257	
i 1	359.49879591836736	0.7575000000000001	69	1093	6	2	1	1	0	0	1	0	0	4.010334626567461	
i 1	359.50842857142857	0.2525	69	279	4	5	6	0	0	0	0	0	0	8.121115351221295	
i 1	359.7431768707483	5.05	60	1093	4	14	13	0	0	1	0	0	0	2.605531084707703	
i 1	359.74558503401363	1.5150000000000001	69	595	4	4	3	1	0	-1	1	0	0	4.010334626567461	
i 1	359.7520068027211	0.505	72	1093	5	9	6	0	0	0	0	0	0	3.010334626567461	
i 1	359.75361224489797	6.0600000000000005	67	595	4	7	6	0	0	1	0	0	0	1.3027655423538516	
i 1	359.75923129251703	0.2525	74	1093	6	1	7	8	0	-1	8	0	0	11.514767055251998	
i 1	359.76404761904763	0.2525	74	1093	1	20	9	8	0	-2	8	0	0	3.092081747133257	
i 1	359.99558503401363	0.7575000000000001	71	279	1	20	10	2	0	1	2	0	0	3.092081747133257	
i 1	359.9971904761905	0.2525	74	1093	5	1	16	8	0	-1	8	0	0	11.514767055251998	
i 1	360.01725850340137	0.7575000000000001	71	1093	6	1	10	8	0	-2	8	0	0	11.514767055251998	
i 1	360.2520068027211	0.2525	69	1093	5	9	2	1	0	0	1	0	0	3.010334626567461	
i 1	360.26003401360543	0.2525	74	1093	6	1	1	8	0	-1	8	0	0	11.514767055251998	
i 1	360.2696666666667	2.2725	69	595	5	3	16	0	0	0	0	0	0	4.010334626567461	
i 1	360.49959863945577	1.2625	71	279	1	24	14	8	0	1	8	0	0	7.092081747133257	
i 1	360.5028095238095	0.2525	71	595	2	24	6	2	0	-2	2	0	0	7.092081747133257	
i 1	360.50441496598637	0.2525	69	1093	6	2	13	1	0	0	1	0	0	4.010334626567461	
i 1	360.51404761904763	0.2525	71	595	2	20	6	2	0	1	2	0	0	3.092081747133257	
i 1	360.5196666666667	1.5150000000000001	74	595	4	24	4	2	0	-2	2	0	0	12.514767055251998	
i 1	360.7343469387755	0.505	71	279	1	20	15	2	0	-2	2	0	0	3.092081747133257	
i 1	360.73755782312924	0.2525	74	1093	5	1	9	8	0	-1	8	0	0	11.514767055251998	
i 1	360.7520068027211	0.2525	69	1093	5	9	4	1	0	0	1	0	0	3.010334626567461	
i 1	360.76404761904763	0.7575000000000001	69	279	4	5	12	0	0	0	0	0	0	8.121115351221295	
i 1	361.00521768707483	0.505	72	279	3	4	15	1	0	0	1	0	0	4.010334626567461	
i 1	361.0068231292517	0.2525	71	1093	6	1	9	8	0	-2	8	0	0	11.514767055251998	
i 1	361.00762585034016	0.2525	74	1093	1	20	7	2	0	-2	2	0	0	3.092081747133257	
i 1	361.01725850340137	0.2525	71	279	5	1	3	2	0	-1	2	0	0	11.514767055251998	
i 1	361.23113605442177	0.505	69	1093	6	2	12	1	0	0	1	0	0	4.010334626567461	
i 1	361.23113605442177	0.2525	74	1093	2	20	5	2	0	-2	2	0	0	3.092081747133257	
i 1	361.23193877551023	0.2525	74	1093	2	20	9	8	0	-2	8	0	0	3.092081747133257	
i 1	361.2479931972789	1.5150000000000001	71	1093	1	24	5	2	0	1	2	0	0	7.092081747133257	
i 1	361.25521768707483	0.2525	74	595	2	20	15	2	0	-2	2	0	0	3.092081747133257	
i 1	361.25923129251703	0.7575000000000001	74	1093	5	1	13	8	0	-1	8	0	0	11.514767055251998	
i 1	361.2696666666667	0.2525	74	1093	6	1	14	8	0	-1	8	0	0	11.514767055251998	
i 1	361.4803333333333	0.505	72	1093	5	9	12	0	0	0	0	0	0	3.010334626567461	
i 1	361.48193877551023	2.7775	71	595	6	1	13	8	0	-2	8	0	0	11.514767055251998	
i 1	361.48595238095237	1.01	74	1093	1	20	9	8	0	-2	8	0	0	3.092081747133257	
i 1	361.7343469387755	0.2525	72	1093	6	2	13	0	0	-1	0	0	0	4.010334626567461	
i 1	361.73996598639457	0.7575000000000001	69	1093	4	5	6	0	0	-1	0	0	0	8.121115351221295	
i 1	361.75923129251703	0.2525	69	279	4	5	4	0	0	0	0	0	0	8.121115351221295	
i 1	361.98675510204083	0.2525	71	279	1	20	12	2	0	1	2	0	0	3.092081747133257	
i 1	361.9883605442177	1.5150000000000001	72	595	4	5	9	1	0	0	1	0	0	8.121115351221295	
i 1	362.00120408163264	0.2525	74	1093	6	1	9	8	0	-1	8	0	0	11.514767055251998	
i 1	362.01003401360543	0.2525	69	1093	5	9	11	1	0	0	1	0	0	3.010334626567461	
i 1	362.0116394557823	0.7575000000000001	69	595	4	4	3	1	0	-1	1	0	0	4.010334626567461	
i 1	362.01886394557823	0.2525	71	1093	6	1	6	8	0	-2	8	0	0	11.514767055251998	
i 1	362.23113605442177	0.2525	71	279	5	1	5	2	0	-1	2	0	0	11.514767055251998	
i 1	362.23755782312924	0.505	74	1093	1	20	5	2	0	-2	2	0	0	3.092081747133257	
i 1	362.2383605442177	2.02	72	1093	6	2	13	0	0	-1	0	0	0	4.010334626567461	
i 1	362.26725850340137	0.505	74	1093	5	1	12	8	0	-1	8	0	0	11.514767055251998	
i 1	362.26806122448977	0.2525	69	1093	6	5	2	1	0	-1	1	0	0	8.121115351221295	
i 1	362.48193877551023	0.505	69	1093	3	5	8	0	0	0	0	0	0	8.121115351221295	
i 1	362.4931768707483	0.2525	74	1093	2	20	12	8	0	-2	8	0	0	3.092081747133257	
i 1	362.49879591836736	0.2525	71	279	1	24	4	8	0	1	8	0	0	7.092081747133257	
i 1	362.50441496598637	0.2525	69	279	4	5	5	0	0	0	0	0	0	8.121115351221295	
i 1	362.51244217687076	0.2525	69	1093	6	2	8	1	0	0	1	0	0	4.010334626567461	
i 1	362.73113605442177	0.7575000000000001	71	279	1	24	4	8	0	1	8	0	0	4.999520280622774	
i 1	362.73193877551023	0.2525	74	1093	1	20	12	8	0	-2	8	0	0	0.9995202806227743	
i 1	362.7335442176871	0.7575000000000001	69	595	5	3	5	0	0	0	0	0	0	4.010334626567461	
i 1	362.73514965986396	0.2525	74	1093	6	1	9	8	0	-1	8	0	0	11.514767055251998	
i 1	362.7383605442177	0.2525	74	1093	1	20	7	2	0	-2	2	0	0	0.9995202806227743	
i 1	362.7520068027211	0.505	74	1093	6	1	16	8	0	-1	8	0	0	11.514767055251998	
i 1	362.7528095238095	0.2525	72	1093	3	5	7	1	0	-1	1	0	0	8.121115351221295	
i 1	362.75521768707483	0.2525	69	1093	6	2	16	1	0	0	1	0	0	4.010334626567461	
i 1	362.7608367346939	2.02	60	1093	4	14	13	0	0	1	0	0	0	2.605531084707703	
i 1	362.76725850340137	0.2525	74	1093	1	20	4	2	0	-2	2	0	0	0.9995202806227743	
i 1	362.99879591836736	0.505	72	279	7	5	2	1	0	0	1	0	0	8.121115351221295	
i 1	363.00120408163264	1.7675	69	1093	6	5	8	1	0	-1	1	0	0	8.121115351221295	
i 1	363.0028095238095	2.2725	71	1093	1	24	15	2	0	1	2	0	0	4.999520280622774	
i 1	363.01404761904763	1.7675	71	1093	6	1	9	8	0	-2	8	0	0	11.514767055251998	
i 1	363.23193877551023	0.505	71	279	5	24	2	8	0	-2	8	0	0	12.514767055251998	
i 1	363.26003401360543	1.5150000000000001	74	279	1	24	13	8	0	252	8	307	0	4.999520280622774	
i 1	363.26886394557823	4.04	74	1093	1	20	9	8	0	-2	8	0	0	0.9995202806227743	
i 1	363.50762585034016	0.2525	69	1093	6	5	3	0	0	-1	0	0	0	8.121115351221295	
i 1	363.50842857142857	0.2525	69	595	4	5	15	0	0	0	0	0	0	8.121115351221295	
i 1	363.73193877551023	0.2525	69	1093	6	2	8	1	0	0	1	0	0	4.010334626567461	
i 1	363.73755782312924	0.2525	74	595	4	24	16	2	0	-2	2	0	0	12.514767055251998	
i 1	363.75040136054423	0.2525	72	1093	3	5	10	1	0	-1	1	0	0	8.121115351221295	
i 1	363.75521768707483	0.505	72	595	4	5	6	1	0	0	1	0	0	8.121115351221295	
i 1	363.76806122448977	1.7675	69	595	4	4	10	1	0	-1	1	0	0	4.010334626567461	
i 1	363.9971904761905	0.2525	74	1093	6	1	2	8	0	-1	8	0	0	11.514767055251998	
i 1	364.2343469387755	0.2525	71	279	1	20	4	2	0	1	2	0	0	0.9995202806227743	
i 1	364.24076870748297	0.2525	69	1093	3	5	7	0	0	0	0	0	0	8.121115351221295	
i 1	364.2431768707483	1.5150000000000001	74	595	4	24	6	2	0	-2	2	0	0	12.514767055251998	
i 1	364.2431768707483	0.2525	69	1093	6	5	3	0	0	-1	0	0	0	8.121115351221295	
i 1	364.2520068027211	0.2525	69	595	5	3	14	0	0	0	0	0	0	4.010334626567461	
i 1	364.26404761904763	0.2525	72	1093	5	9	15	0	0	0	0	0	0	3.010334626567461	
i 1	364.4803333333333	0.2525	72	279	3	4	16	1	0	0	1	0	0	4.010334626567461	
i 1	364.4883605442177	0.2525	69	1093	5	9	8	1	0	0	1	0	0	3.010334626567461	
i 1	364.4979931972789	0.2525	72	595	4	5	13	1	0	0	1	0	0	8.121115351221295	
i 1	364.50441496598637	1.2625	69	595	4	5	16	0	0	0	0	0	0	8.121115351221295	
i 1	364.50762585034016	2.7775	74	1093	1	20	4	2	0	-2	2	0	0	0.9995202806227743	
i 1	364.73514965986396	0.505	71	707	6	1	16	8	0	-2	8	0	0	11.514767055251998	
i 1	364.74237414965984	3.0300000000000002	74	391	1	24	8	8	5002	252	8	307	0	4.999520280622774	
i 1	364.75361224489797	1.01	67	707	4	14	1	0	0	0	0	0	0	2.605531084707703	
i 1	364.75842857142857	1.01	60	707	4	14	4	0	0	0	0	0	0	2.605531084707703	
i 1	364.75923129251703	0.2525	71	707	6	1	6	2	0	-1	2	0	0	11.514767055251998	
i 1	364.76324489795917	1.01	69	595	5	3	11	0	0	0	0	0	0	4.010334626567461	
i 1	364.9883605442177	0.2525	72	1093	3	5	6	1	0	-1	1	0	0	8.121115351221295	
i 1	364.9931768707483	0.7575000000000001	71	595	6	1	2	8	0	-2	8	0	0	11.514767055251998	
i 1	365.00602040816324	0.2525	69	391	5	3	1	0	5002	-1	0	0	0	4.010334626567461	
i 1	365.01886394557823	0.7575000000000001	69	707	6	5	7	0	0	-1	0	0	0	8.121115351221295	
i 1	365.23675510204083	0.505	69	1093	3	5	8	0	0	0	0	0	0	8.121115351221295	
i 1	365.23675510204083	0.2525	74	391	1	24	1	8	0	-2	8	0	0	4.999520280622774	
i 1	365.23996598639457	0.505	69	707	6	2	16	1	0	0	1	0	0	4.010334626567461	
i 1	365.25120408163264	0.505	71	391	5	1	3	2	5002	-1	2	0	0	11.514767055251998	
i 1	365.26806122448977	2.02	71	1093	1	24	1	2	0	248	2	308	0	4.999520280622774	
i 1	365.48675510204083	0.2525	72	1093	5	9	13	0	0	0	0	0	0	3.010334626567461	
i 1	365.49879591836736	0.2525	74	391	1	20	14	2	0	1	2	0	0	0.9995202806227743	
i 1	365.7335442176871	1.7675	71	595	6	1	9	8	0	-2	8	0	0	11.177476464324647	
i 1	365.7335442176871	0.2525	72	391	6	5	13	1	5002	-1	1	0	0	5.900842882465954	
i 1	365.7343469387755	0.505	71	391	1	20	13	8	5002	-2	8	0	0	0.9995202806227743	
i 1	365.73675510204083	0.2525	74	595	4	24	3	2	0	-2	2	0	0	12.177476464324647	
i 1	365.73755782312924	3.0300000000000002	69	707	6	5	2	0	0	-1	0	0	0	5.900842882465954	
i 1	365.7383605442177	1.01	69	595	5	3	13	0	0	0	0	0	0	4.017858234708573	
i 1	365.73996598639457	11.615	67	707	4	14	8	0	0	0	0	0	0	2.605531084707703	
i 1	365.73996598639457	11.615	60	707	4	14	1	0	0	0	0	0	0	2.605531084707703	
i 1	365.74076870748297	0.2525	72	391	3	5	5	1	5002	0	1	0	0	5.900842882465954	
i 1	365.74397959183676	0.505	72	1093	5	9	7	0	0	0	0	0	0	3.0178582347085725	
i 1	365.74879591836736	0.2525	74	1093	6	1	3	8	0	-1	8	0	0	11.177476464324647	
i 1	365.75120408163264	0.2525	69	1093	5	9	11	1	0	0	1	0	0	3.0178582347085725	
i 1	365.76324489795917	3.0300000000000002	67	595	4	7	10	0	0	1	0	0	0	1.3027655423538516	
i 1	365.98113605442177	1.01	71	707	6	1	1	2	0	-1	2	0	0	11.177476464324647	
i 1	365.99638775510203	0.2525	72	1093	3	5	1	1	0	-1	1	0	0	5.900842882465954	
i 1	365.9979931972789	0.505	74	1093	6	1	2	8	0	-1	8	0	0	11.177476464324647	
i 1	365.99879591836736	0.2525	72	707	6	2	5	0	0	0	0	0	0	4.017858234708573	
i 1	366.00762585034016	0.505	69	595	6	5	9	0	0	0	0	0	0	5.900842882465954	
i 1	366.25842857142857	2.525	69	595	4	4	1	1	0	-1	1	0	0	4.017858234708573	
i 1	366.2616394557823	0.505	69	391	5	3	3	0	5002	-1	0	0	0	4.017858234708573	
i 1	366.2664557823129	0.2525	74	391	1	20	2	2	0	1	2	0	0	0.9995202806227743	
i 1	366.48193877551023	2.02	74	595	4	24	11	2	0	-2	2	0	0	12.177476464324647	
i 1	366.5020068027211	0.2525	74	1093	1	20	8	2	0	-2	2	0	0	0.9995202806227743	
i 1	366.73274149659863	0.7575000000000001	69	595	6	5	10	0	0	0	0	0	0	5.900842882465954	
i 1	366.7343469387755	0.7575000000000001	72	707	6	2	11	0	0	0	0	0	0	4.017858234708573	
i 1	366.7391632653061	1.7675	71	391	1	20	16	8	5002	-2	8	0	0	0.9995202806227743	
i 1	366.7471904761905	1.5150000000000001	74	391	1	20	16	2	0	1	2	0	0	0.9995202806227743	
i 1	366.74959863945577	0.505	72	391	4	4	10	1	5002	-1	1	0	0	4.017858234708573	
i 1	367.00120408163264	0.505	71	707	6	1	10	8	0	-2	8	0	0	11.177476464324647	
i 1	367.0156530612245	0.2525	72	1093	3	5	16	1	0	-1	1	0	0	5.900842882465954	
i 1	367.2471904761905	0.2525	71	1093	1	24	3	2	0	1	2	0	0	4.999520280622774	
i 1	367.25040136054423	0.7575000000000001	69	1093	3	5	8	0	0	0	0	0	0	5.900842882465954	
i 1	367.2608367346939	0.2525	69	1093	5	9	4	1	0	0	1	0	0	3.0178582347085725	
i 1	367.48113605442177	0.2525	72	391	4	4	14	1	5002	-1	1	0	0	4.017858234708573	
i 1	367.48996598639457	0.2525	74	1093	6	1	5	8	0	-1	8	0	0	11.177476464324647	
i 1	367.50923129251703	0.2525	71	391	6	1	9	2	5002	-1	2	0	0	11.177476464324647	
i 1	367.5108367346939	0.2525	72	391	3	5	9	1	5002	0	1	0	0	5.900842882465954	
i 1	367.51244217687076	0.2525	69	391	5	3	10	0	5002	-1	0	0	0	4.017858234708573	
i 1	367.5196666666667	2.525	74	1093	1	20	11	2	0	-2	2	0	0	0.9995202806227743	
i 1	367.7343469387755	0.505	74	1093	6	1	8	8	0	-1	8	0	0	11.177476464324647	
i 1	367.73514965986396	0.7575000000000001	69	595	5	3	8	0	0	0	0	0	0	4.017858234708573	
i 1	367.75842857142857	2.525	74	391	1	24	5	8	5002	1	8	0	0	4.999520280622774	
i 1	367.75923129251703	0.2525	71	707	6	1	1	8	0	-2	8	0	0	11.177476464324647	
i 1	367.76324489795917	0.505	72	1093	3	5	13	1	0	-1	1	0	0	5.900842882465954	
i 1	367.9931768707483	2.2725	71	595	6	1	11	8	0	-2	8	0	0	11.177476464324647	
i 1	367.99638775510203	0.7575000000000001	72	595	4	5	2	1	0	0	1	0	0	5.900842882465954	
i 1	368.0028095238095	0.2525	72	391	4	4	14	1	5002	-1	1	0	0	4.017858234708573	
i 1	368.2431768707483	0.2525	72	391	6	5	4	1	5002	-1	1	0	0	5.900842882465954	
i 1	368.24638775510203	0.505	69	707	6	2	3	1	0	0	1	0	0	4.017858234708573	
i 1	368.26324489795917	0.7575000000000001	71	707	6	1	3	2	0	-1	2	0	0	11.177476464324647	
i 1	368.49397959183676	0.505	71	1093	1	24	9	2	0	1	2	0	0	4.999520280622774	
i 1	368.4971904761905	0.2525	71	707	6	1	9	8	0	-2	8	0	0	11.177476464324647	
i 1	368.49959863945577	0.505	69	1093	3	5	13	0	0	0	0	0	0	5.900842882465954	
i 1	368.50521768707483	0.7575000000000001	72	707	6	2	10	0	0	0	0	0	0	4.017858234708573	
i 1	368.73193877551023	0.7575000000000001	72	595	6	5	3	1	0	0	1	0	0	5.900842882465954	
i 1	368.7343469387755	1.5150000000000001	67	595	4	7	10	0	0	1	0	0	0	1.3027655423538516	
i 1	368.7391632653061	1.2625	69	595	4	4	12	1	0	-1	1	0	0	4.017858234708573	
i 1	368.74157142857143	1.01	71	391	4	24	7	2	5002	-1	2	0	0	12.177476464324647	
i 1	368.75923129251703	0.2525	72	391	4	4	16	1	5002	-1	1	0	0	4.017858234708573	
i 1	368.76806122448977	0.2525	72	391	3	5	7	1	5002	0	1	0	0	5.900842882465954	
i 1	368.98193877551023	0.2525	72	1093	5	9	5	0	0	0	0	0	0	3.0178582347085725	
i 1	368.98274149659863	1.5150000000000001	69	707	6	5	1	0	0	-1	0	0	0	5.900842882465954	
i 1	368.98755782312924	0.2525	72	391	3	5	3	1	5002	-1	1	0	0	5.900842882465954	
i 1	368.9883605442177	0.2525	74	595	4	24	6	2	0	-2	2	0	0	12.177476464324647	
i 1	368.99558503401363	0.2525	74	391	1	24	14	8	0	-2	8	0	0	4.999520280622774	
i 1	369.2391632653061	0.2525	74	1093	6	1	5	8	0	-1	8	0	0	11.177476464324647	
i 1	369.25842857142857	6.3125	74	1093	1	20	14	2	0	-2	2	0	0	0.9995202806227743	
i 1	369.49478231292517	1.2625	74	1093	1	20	6	8	0	-2	8	0	0	0.9995202806227743	
i 1	369.49558503401363	0.7575000000000001	69	595	6	5	3	0	0	0	0	0	0	5.900842882465954	
i 1	369.50521768707483	0.2525	69	707	6	2	5	1	0	0	1	0	0	4.017858234708573	
i 1	369.5068231292517	1.01	72	707	6	2	15	0	0	0	0	0	0	4.017858234708573	
i 1	369.75441496598637	0.505	69	595	5	3	2	0	0	0	0	0	0	4.017858234708573	
i 1	369.76485034013604	0.2525	72	391	3	5	5	1	5002	-1	1	0	0	5.900842882465954	
i 1	369.98755782312924	0.505	69	1093	3	5	3	0	0	0	0	0	0	5.900842882465954	
i 1	369.99558503401363	0.2525	69	707	6	2	8	1	0	0	1	0	0	4.017858234708573	
i 1	370.23675510204083	7.07	60	391	4	7	5	5	0	0	5	0	0	1.3027655423538516	
i 1	370.2383605442177	2.02	72	391	4	4	12	0	0	0	0	0	0	4.017858234708573	
i 1	370.24076870748297	1.01	72	391	5	3	2	1	0	-1	1	0	0	4.017858234708573	
i 1	370.24558503401363	0.2525	74	391	1	20	3	2	0	1	2	0	0	0.9995202806227743	
i 1	370.24879591836736	3.7875	72	391	6	5	3	0	0	0	0	0	0	5.900842882465954	
i 1	370.25120408163264	1.2625	71	391	6	1	13	2	0	-1	2	0	0	11.177476464324647	
i 1	370.4835442176871	0.2525	69	707	6	5	8	0	0	-1	0	0	0	5.900842882465954	
i 1	370.4979931972789	0.505	72	391	4	4	10	1	5002	-1	1	0	0	4.017858234708573	
i 1	370.50842857142857	0.2525	74	1093	1	20	9	2	0	-2	2	0	0	0.9995202806227743	
i 1	370.51003401360543	0.505	72	391	3	5	12	1	5002	0	1	0	0	5.900842882465954	
i 1	370.73274149659863	0.7575000000000001	74	1093	6	1	1	8	0	-1	8	0	0	11.177476464324647	
i 1	370.7335442176871	0.2525	71	707	6	1	2	8	0	-2	8	0	0	11.177476464324647	
i 1	370.73514965986396	0.2525	74	707	2	20	15	2	0	-2	2	0	0	0.9995202806227743	
i 1	370.7471904761905	0.2525	74	707	2	20	2	2	0	1	2	0	0	0.9995202806227743	
i 1	370.75602040816324	0.2525	72	391	3	5	10	1	5002	-1	1	0	0	5.900842882465954	
i 1	370.98675510204083	1.5150000000000001	71	1093	1	20	14	2	0	-2	2	0	0	0.9995202806227743	
i 1	370.99237414965984	0.505	71	1093	1	20	16	2	0	1	2	0	0	0.9995202806227743	
i 1	371.01003401360543	0.2525	69	1093	5	9	12	1	0	0	1	0	0	3.0178582347085725	
i 1	371.01244217687076	1.7675	71	391	4	24	14	8	0	-2	8	0	0	12.177476464324647	
i 1	371.24157142857143	0.505	72	707	6	2	2	0	0	0	0	0	0	4.017858234708573	
i 1	371.24478231292517	0.2525	69	707	6	2	3	1	0	0	1	0	0	4.017858234708573	
i 1	371.4971904761905	0.2525	71	391	4	24	9	2	5002	-1	2	0	0	12.177476464324647	
i 1	371.4979931972789	0.2525	74	391	1	20	7	2	0	1	2	0	0	0.9995202806227743	
i 1	371.5196666666667	0.2525	71	391	6	1	5	2	5002	-1	2	0	0	11.177476464324647	
i 1	371.5196666666667	0.505	69	391	5	3	8	0	5002	-1	0	0	0	4.017858234708573	
i 1	371.75040136054423	0.2525	71	707	6	1	12	8	0	-2	8	0	0	11.177476464324647	
i 1	371.7528095238095	3.0300000000000002	71	391	6	1	5	2	0	-1	2	0	0	11.177476464324647	
i 1	371.7616394557823	3.7875	72	391	5	3	5	1	0	-1	1	0	0	4.017858234708573	
i 1	371.7664557823129	0.2525	71	1093	1	24	7	2	0	1	2	0	0	4.999520280622774	
i 1	371.99076870748297	0.2525	69	707	6	5	13	0	0	-1	0	0	0	5.900842882465954	
i 1	371.9979931972789	0.2525	72	707	6	2	6	0	0	0	0	0	0	4.017858234708573	
i 1	372.0108367346939	0.2525	72	1093	3	5	9	1	0	-1	1	0	0	5.900842882465954	
i 1	372.24157142857143	0.7575000000000001	69	707	6	5	13	0	0	-1	0	0	0	5.900842882465954	
i 1	372.24879591836736	0.2525	69	391	5	3	15	0	5002	-1	0	0	0	4.017858234708573	
i 1	372.25602040816324	0.7575000000000001	69	1093	6	5	3	0	0	0	0	0	0	5.900842882465954	
i 1	372.25762585034016	0.7575000000000001	69	707	6	2	12	1	0	0	1	0	0	4.017858234708573	
i 1	372.49638775510203	1.5150000000000001	72	707	6	2	16	0	0	0	0	0	0	4.017858234708573	
i 1	372.75120408163264	0.7575000000000001	74	391	1	24	2	8	5002	1	8	0	0	4.999520280622774	
i 1	372.7528095238095	0.505	74	1093	6	1	9	8	0	-1	8	0	0	11.177476464324647	
i 1	372.98113605442177	0.2525	72	391	6	5	10	0	0	0	0	0	0	5.900842882465954	
i 1	372.98274149659863	0.2525	72	1093	3	5	12	1	0	-1	1	0	0	5.900842882465954	
i 1	372.99157142857143	0.2525	74	391	2	20	10	2	0	1	2	0	0	0.9995202806227743	
i 1	373.00120408163264	0.2525	69	1093	5	9	10	1	0	0	1	0	0	3.0178582347085725	
i 1	373.0196666666667	0.2525	74	707	2	20	16	2	0	-2	2	0	0	0.9995202806227743	
i 1	373.2335442176871	0.2525	74	1093	6	1	16	8	0	-1	8	0	0	11.177476464324647	
i 1	373.23755782312924	0.505	69	1093	6	5	4	0	0	0	0	0	0	5.900842882465954	
i 1	373.2431768707483	1.01	74	1093	1	20	3	2	0	-2	2	0	0	0.9995202806227743	
i 1	373.24879591836736	0.2525	71	391	6	1	8	2	5002	-1	2	0	0	11.177476464324647	
i 1	373.24879591836736	0.505	74	391	1	20	13	2	0	1	2	0	0	0.9995202806227743	
i 1	373.25361224489797	0.2525	69	391	5	3	2	0	5002	-1	0	0	0	4.017858234708573	
i 1	373.26485034013604	0.2525	72	391	3	5	9	1	5002	-1	1	0	0	5.900842882465954	
i 1	373.5020068027211	1.5150000000000001	69	707	6	5	15	0	0	-1	0	0	0	5.900842882465954	
i 1	373.51806122448977	0.505	71	707	6	1	11	8	0	-2	8	0	0	11.177476464324647	
i 1	373.5196666666667	0.7575000000000001	71	391	4	24	4	8	0	-2	8	0	0	12.177476464324647	
i 1	373.7391632653061	0.505	74	1093	1	20	4	8	0	-2	8	0	0	0.9995202806227743	
i 1	373.76324489795917	0.2525	72	391	3	5	3	1	5002	0	1	0	0	5.900842882465954	
i 1	373.98193877551023	0.2525	69	707	6	5	8	0	0	-1	0	0	0	5.900842882465954	
i 1	374.00441496598637	2.02	71	707	6	1	1	2	0	-1	2	0	0	11.177476464324647	
i 1	374.01244217687076	0.7575000000000001	69	1093	6	5	14	0	0	0	0	0	0	5.900842882465954	
i 1	374.23595238095237	0.7575000000000001	74	707	2	20	7	2	0	-2	2	0	0	0.9995202806227743	
i 1	374.2383605442177	0.2525	74	707	2	20	10	2	0	-2	2	0	0	0.9995202806227743	
i 1	374.2471904761905	0.2525	72	1093	3	5	15	1	0	-1	1	0	0	5.900842882465954	
i 1	374.25361224489797	0.2525	74	1093	6	1	5	8	0	-1	8	0	0	11.177476464324647	
i 1	374.5108367346939	0.2525	71	391	4	24	5	2	5002	-1	2	0	0	12.177476464324647	
i 1	374.5116394557823	0.2525	74	391	2	20	10	2	0	1	2	0	0	0.9995202806227743	
i 1	374.5156530612245	2.02	72	391	6	5	3	0	0	0	0	0	0	5.900842882465954	
i 1	374.73514965986396	0.505	72	1093	5	9	10	0	0	0	0	0	0	3.0178582347085725	
i 1	374.75521768707483	0.2525	72	391	3	5	14	1	5002	0	1	0	0	5.900842882465954	
i 1	374.76806122448977	0.2525	69	391	5	3	1	0	5002	-1	0	0	0	4.017858234708573	
i 1	374.76886394557823	0.505	71	391	4	24	14	8	0	-2	8	0	0	12.177476464324647	
i 1	374.7696666666667	0.505	74	1093	6	1	8	8	0	-1	8	0	0	11.177476464324647	
i 1	374.98274149659863	0.2525	69	707	6	5	2	0	0	-1	0	0	0	5.900842882465954	
i 1	374.9931768707483	2.2725	72	391	4	4	14	0	0	0	0	0	0	4.017858234708573	
i 1	375.00762585034016	1.2625	74	391	1	24	5	8	5002	1	8	0	0	4.999520280622774	
i 1	375.01485034013604	0.2525	74	391	1	20	15	2	0	1	2	0	0	0.9995202806227743	
i 1	375.0156530612245	0.2525	74	1093	1	20	14	8	0	-2	8	0	0	0.9995202806227743	
i 1	375.0196666666667	0.2525	69	1093	6	5	5	0	0	0	0	0	0	5.900842882465954	
i 1	375.23113605442177	0.7575000000000001	74	391	2	20	9	2	0	1	2	0	0	0.9995202806227743	
i 1	375.25120408163264	0.2525	69	391	5	3	6	0	5002	-1	0	0	0	4.017858234708573	
i 1	375.25521768707483	0.505	72	391	3	5	14	1	5002	0	1	0	0	5.900842882465954	
i 1	375.26806122448977	0.2525	71	707	6	1	6	8	0	-2	8	0	0	11.177476464324647	
i 1	375.2696666666667	0.2525	74	1093	6	1	2	8	0	-1	8	0	0	11.177476464324647	
i 1	375.48274149659863	0.2525	71	391	1	20	5	8	5002	-2	8	0	0	0.9995202806227743	
i 1	375.4971904761905	0.2525	72	391	4	4	4	1	5002	-1	1	0	0	4.017858234708573	
i 1	375.50120408163264	1.5150000000000001	71	391	6	1	11	2	0	-1	2	0	0	11.177476464324647	
i 1	375.51485034013604	0.2525	71	391	6	1	6	2	5002	-1	2	0	0	11.177476464324647	
i 1	375.5156530612245	0.505	69	707	6	2	14	1	0	0	1	0	0	4.017858234708573	
i 1	375.73595238095237	0.505	72	391	5	3	14	1	0	-1	1	0	0	4.017858234708573	
i 1	375.73996598639457	1.5150000000000001	74	1093	1	20	4	2	0	-2	2	0	0	0.9995202806227743	
i 1	375.74558503401363	1.5150000000000001	69	707	6	5	4	0	0	-1	0	0	0	5.900842882465954	
i 1	375.74879591836736	0.2525	74	707	2	20	9	2	0	-2	2	0	0	0.9995202806227743	
i 1	375.76404761904763	0.505	71	391	4	24	10	2	5002	-1	2	0	0	12.177476464324647	
i 1	375.76806122448977	0.2525	69	1093	6	5	8	0	0	0	0	0	0	5.900842882465954	
i 1	375.98675510204083	1.2625	71	1093	1	20	11	2	0	-2	2	0	0	0.9995202806227743	
i 1	375.9883605442177	0.2525	69	1093	5	9	5	1	0	0	1	0	0	3.0178582347085725	
i 1	376.00120408163264	0.2525	71	707	6	1	9	8	0	-2	8	0	0	11.177476464324647	
i 1	376.23996598639457	0.2525	72	391	6	5	15	0	0	0	0	0	0	5.900842882465954	
i 1	376.24879591836736	0.505	74	1093	6	1	10	8	0	-1	8	0	0	11.177476464324647	
i 1	376.25923129251703	0.505	69	391	5	3	5	0	5002	-1	0	0	0	4.017858234708573	
i 1	376.2616394557823	0.2525	72	391	4	4	16	1	5002	-1	1	0	0	4.017858234708573	
i 1	376.2656530612245	0.2525	74	1093	6	1	3	8	0	-1	8	0	0	11.177476464324647	
i 1	376.48113605442177	0.2525	74	391	1	24	16	8	0	-2	8	0	0	4.999520280622774	
i 1	376.4843469387755	0.7575000000000001	72	707	6	2	8	0	0	0	0	0	0	4.017858234708573	
i 1	376.51324489795917	0.7575000000000001	71	707	6	1	1	2	0	-1	2	0	0	11.177476464324647	
i 1	376.51485034013604	0.505	69	707	6	5	1	0	0	-1	0	0	0	5.900842882465954	
i 1	376.5156530612245	0.2525	72	1093	6	5	10	1	0	-1	1	0	0	5.900842882465954	
i 1	376.76003401360543	0.505	71	391	4	24	4	8	0	-2	8	0	0	12.177476464324647	
i 1	376.76324489795917	0.2525	72	1093	5	9	8	0	0	0	0	0	0	3.0178582347085725	
i 1	376.98595238095237	0.2525	71	1093	1	20	16	2	0	1	2	0	0	0.9995202806227743	
i 1	376.98996598639457	0.2525	72	391	6	5	7	0	0	0	0	0	0	5.900842882465954	
i 1	377.0068231292517	0.2525	72	391	3	5	2	1	5002	-1	1	0	0	5.900842882465954	
i 1	377.00842857142857	0.2525	69	707	6	2	15	1	0	0	1	0	0	4.017858234708573	
i 1	377.01725850340137	0.505	71	391	6	1	3	2	5002	-1	2	0	0	11.177476464324647	
i 1	377.2335442176871	12.625	60	1193	5	14	14	5	0	1	5	0	0	2.605531084707703	
i 1	377.2343469387755	0.505	72	695	6	5	13	0	0	-1	0	0	0	5.900842882465954	
i 1	377.23595238095237	0.7575000000000001	71	379	2	20	10	2	0	-2	2	0	0	0.9995202806227743	
i 1	377.23996598639457	5.555	60	695	4	7	14	5	0	1	5	0	0	1.3027655423538516	
i 1	377.24157142857143	0.2525	71	379	2	20	12	2	0	-2	2	0	0	0.9995202806227743	
i 1	377.24558503401363	2.2725	71	695	4	24	14	8	0	-2	8	0	0	12.177476464324647	
i 1	377.2608367346939	1.7675	72	695	4	4	4	1	0	-1	1	0	0	4.017858234708573	
i 1	377.26485034013604	0.505	74	1193	6	1	2	8	0	-2	8	0	0	11.177476464324647	
i 1	377.26485034013604	4.04	74	379	2	20	10	8	0	-2	8	0	0	0.9995202806227743	
i 1	377.2656530612245	12.625	60	1193	5	14	3	0	0	1	0	0	0	2.605531084707703	
i 1	377.26806122448977	1.5150000000000001	69	1193	6	5	7	1	0	-1	1	0	0	5.900842882465954	
i 1	377.5028095238095	0.505	71	391	4	24	8	2	5002	-1	2	0	0	12.177476464324647	
i 1	377.51244217687076	0.2525	71	391	1	20	12	8	5002	-2	8	0	0	0.9995202806227743	
i 1	377.7335442176871	0.2525	69	379	6	5	7	1	0	0	1	0	0	5.900842882465954	
i 1	377.75602040816324	0.2525	71	391	6	1	13	2	5002	-1	2	0	0	11.177476464324647	
i 1	377.76886394557823	0.2525	72	391	3	5	9	1	5002	-1	1	0	0	5.900842882465954	
i 1	377.98675510204083	0.7575000000000001	71	1193	6	1	13	2	0	-1	2	0	0	11.177476464324647	
i 1	377.99558503401363	0.2525	74	1193	3	20	2	2	0	-2	2	0	0	0.9995202806227743	
i 1	377.9971904761905	0.2525	72	1193	6	5	2	0	0	0	0	0	0	5.900842882465954	
i 1	378.0020068027211	1.7675	72	695	6	5	15	0	0	-1	0	0	0	5.900842882465954	
i 1	378.00521768707483	0.2525	71	695	2	20	15	8	0	1	8	0	0	0.9995202806227743	
i 1	378.0068231292517	0.2525	74	1193	6	1	2	8	0	-2	8	0	0	11.177476464324647	
i 1	378.0068231292517	1.01	74	391	1	24	6	8	5002	1	8	0	0	4.999520280622774	
i 1	378.23274149659863	0.2525	69	391	5	3	6	0	5002	-1	0	0	0	4.017858234708573	
i 1	378.24157142857143	0.2525	72	379	6	5	9	0	0	0	0	0	0	5.900842882465954	
i 1	378.24397959183676	0.2525	71	391	1	20	4	2	0	1	2	0	0	0.9995202806227743	
i 1	378.24558503401363	0.2525	74	379	6	1	5	8	0	-2	8	0	0	11.177476464324647	
i 1	378.24879591836736	0.2525	71	379	2	20	2	2	0	-2	2	0	0	0.9995202806227743	
i 1	378.2616394557823	0.2525	72	391	4	4	2	1	5002	-1	1	0	0	4.017858234708573	
i 1	378.48274149659863	2.2725	72	1193	6	2	10	1	0	0	1	0	0	4.017858234708573	
i 1	378.49638775510203	0.505	69	695	6	5	16	0	0	0	0	0	0	5.900842882465954	
i 1	378.4971904761905	0.2525	71	695	2	20	13	2	0	-2	2	0	0	0.9995202806227743	
i 1	378.49959863945577	0.7575000000000001	72	695	5	3	10	0	0	-1	0	0	0	4.017858234708573	
i 1	378.50040136054423	0.2525	71	1193	3	20	11	2	0	1	2	0	0	0.9995202806227743	
i 1	378.51244217687076	2.7775	74	695	6	1	2	8	0	-1	8	0	0	11.177476464324647	
i 1	378.7303333333333	0.2525	74	379	6	1	14	8	0	-2	8	0	0	11.177476464324647	
i 1	378.73755782312924	2.02	74	379	2	20	12	2	0	1	2	0	0	0.9995202806227743	
i 1	378.74478231292517	0.2525	72	391	6	5	10	1	5002	0	1	0	0	5.900842882465954	
i 1	378.9971904761905	0.2525	71	391	6	1	1	2	5002	-1	2	0	0	11.177476464324647	
i 1	379.0108367346939	0.2525	69	379	5	9	15	1	0	-1	1	0	0	3.0178582347085725	
i 1	379.01485034013604	1.01	69	379	6	5	2	1	0	0	1	0	0	5.900842882465954	
i 1	379.01725850340137	0.2525	74	379	2	24	6	2	0	1	2	0	0	4.999520280622774	
i 1	379.01806122448977	0.2525	72	379	6	5	5	0	0	0	0	0	0	5.900842882465954	
i 1	379.23595238095237	0.505	69	391	5	3	2	0	5002	-1	0	0	0	4.017858234708573	
i 1	379.24478231292517	0.2525	71	391	1	20	16	2	0	1	2	0	0	0.9995202806227743	
i 1	379.25040136054423	2.02	72	1193	6	5	7	0	0	0	0	0	0	5.900842882465954	
i 1	379.26806122448977	0.2525	69	1193	6	2	4	1	0	-1	1	0	0	4.017858234708573	
i 1	379.4891632653061	0.505	71	391	1	24	1	8	0	1	8	0	0	4.999520280622774	
i 1	379.50040136054423	0.505	69	379	5	9	11	1	0	-1	1	0	0	3.0178582347085725	
i 1	379.75040136054423	0.505	69	1193	6	2	4	1	0	-1	1	0	0	4.017858234708573	
i 1	379.75120408163264	0.505	72	391	3	5	9	1	5002	-1	1	0	0	5.900842882465954	
i 1	379.9883605442177	0.2525	72	695	6	5	9	0	0	-1	0	0	0	5.900842882465954	
i 1	379.99638775510203	0.505	74	1193	6	1	4	8	0	-2	8	0	0	11.177476464324647	
i 1	380.01404761904763	0.2525	74	391	1	24	2	8	5002	1	8	0	0	4.999520280622774	
i 1	380.0164557823129	0.2525	72	695	4	4	14	1	0	-1	1	0	0	4.017858234708573	
i 1	380.2343469387755	2.02	72	695	5	3	8	0	0	-1	0	0	0	4.017858234708573	
i 1	380.24076870748297	0.2525	69	379	6	5	6	1	0	0	1	0	0	5.900842882465954	
i 1	380.2479931972789	0.2525	72	391	6	5	4	1	5002	0	1	0	0	5.900842882465954	
i 1	380.25040136054423	0.2525	69	379	5	9	15	1	0	-1	1	0	0	3.0178582347085725	
i 1	380.26806122448977	0.2525	71	391	1	24	13	8	0	1	8	0	0	4.999520280622774	
i 1	380.49638775510203	0.2525	72	695	6	5	13	0	0	-1	0	0	0	5.900842882465954	
i 1	380.50361224489797	1.7675	71	1193	6	1	10	2	0	-1	2	0	0	11.177476464324647	
i 1	380.50842857142857	0.2525	71	391	1	20	1	8	5002	-2	8	0	0	0.9995202806227743	
i 1	380.51003401360543	0.2525	72	379	6	5	1	0	0	0	0	0	0	5.900842882465954	
i 1	380.73193877551023	0.505	74	379	1	20	12	2	0	1	2	0	0	0.9995202806227743	
i 1	380.7335442176871	1.01	74	379	2	24	13	2	0	1	2	0	0	4.999520280622774	
i 1	380.73996598639457	0.7575000000000001	72	391	6	5	8	1	5002	0	1	0	0	5.900842882465954	
i 1	380.7479931972789	0.2525	74	1193	6	1	13	8	0	-2	8	0	0	11.177476464324647	
i 1	380.7616394557823	0.7575000000000001	71	379	1	20	9	2	0	-2	2	0	0	0.9995202806227743	
i 1	380.76485034013604	1.2625	69	695	6	5	6	0	0	0	0	0	0	5.900842882465954	
i 1	381.01003401360543	0.505	71	695	4	24	8	8	0	-2	8	0	0	12.177476464324647	
i 1	381.23113605442177	0.2525	71	391	1	20	9	2	0	1	2	0	0	0.9995202806227743	
i 1	381.23514965986396	0.2525	72	695	6	5	15	0	0	-1	0	0	0	5.900842882465954	
i 1	381.24237414965984	0.2525	74	379	6	1	16	8	0	-2	8	0	0	11.177476464324647	
i 1	381.26485034013604	0.7575000000000001	71	391	1	20	10	8	5002	-2	8	0	0	0.9995202806227743	
i 1	381.48193877551023	1.5150000000000001	69	1193	6	5	1	1	0	-1	1	0	0	5.900842882465954	
i 1	381.48675510204083	0.2525	74	695	2	20	7	2	0	-2	2	0	0	0.9995202806227743	
i 1	381.49157142857143	0.2525	71	391	6	1	1	2	5002	-1	2	0	0	11.177476464324647	
i 1	381.4971904761905	0.2525	74	1193	2	20	9	2	0	1	2	0	0	0.9995202806227743	
i 1	381.49959863945577	0.505	69	1193	6	2	15	1	0	-1	1	0	0	4.017858234708573	
i 1	381.50120408163264	1.2625	74	695	6	1	8	8	0	-1	8	0	0	11.177476464324647	
i 1	381.5068231292517	0.2525	72	1193	6	2	13	1	0	0	1	0	0	4.017858234708573	
i 1	381.50762585034016	1.2625	74	391	1	24	6	8	5002	1	8	0	0	4.999520280622774	
i 1	381.51003401360543	0.2525	72	391	6	5	16	1	5002	-1	1	0	0	5.900842882465954	
i 1	381.73193877551023	1.01	72	695	4	4	14	1	0	-1	1	0	0	4.017858234708573	
i 1	381.74397959183676	0.2525	74	379	6	1	15	8	0	-2	8	0	0	11.177476464324647	
i 1	381.7471904761905	1.01	74	391	1	20	14	2	0	-2	2	0	0	0.9995202806227743	
i 1	381.7471904761905	0.505	74	391	1	24	12	2	0	252	2	307	0	4.999520280622774	
i 1	381.98113605442177	0.7575000000000001	71	391	4	24	3	2	5002	-1	2	0	0	12.177476464324647	
i 1	381.98274149659863	1.01	72	1193	6	2	14	1	0	0	1	0	0	4.017858234708573	
i 1	381.9979931972789	0.2525	74	379	2	24	11	2	0	1	2	0	0	4.999520280622774	
i 1	382.23514965986396	0.2525	69	1193	6	2	15	1	0	-1	1	0	0	4.017858234708573	
i 1	382.24076870748297	0.2525	74	391	1	24	11	2	0	1	2	0	0	4.999520280622774	
i 1	382.24397959183676	0.2525	71	379	6	1	11	2	0	-2	2	0	0	11.177476464324647	
i 1	382.5068231292517	0.2525	72	695	5	3	10	0	0	-1	0	0	0	4.017858234708573	
i 1	382.51485034013604	0.2525	71	695	4	24	16	8	0	-2	8	0	0	12.177476464324647	
i 1	382.73274149659863	2.525	74	926	6	1	9	8	0	-2	8	0	0	11.177476464324647	
i 1	382.7335442176871	0.2525	69	610	6	5	11	1	0	0	1	0	0	5.900842882465954	
i 1	382.74076870748297	0.505	72	224	7	5	12	0	0	-1	0	0	0	5.900842882465954	
i 1	382.75120408163264	1.01	71	224	1	20	1	2	0	-2	2	0	0	0.9995202806227743	
i 1	382.75521768707483	0.505	71	224	7	1	12	2	0	-1	2	0	0	11.177476464324647	
i 1	382.75762585034016	3.535	69	926	5	3	1	1	0	0	1	0	0	4.017858234708573	
i 1	382.75762585034016	1.01	69	610	4	4	9	1	0	-1	1	0	0	4.017858234708573	
i 1	382.7608367346939	1.5150000000000001	69	926	6	5	2	0	0	0	0	0	0	5.900842882465954	
i 1	382.76886394557823	1.5150000000000001	71	610	1	24	2	8	0	-2	8	0	0	4.999520280622774	
i 1	382.76886394557823	12.625	67	926	4	7	15	0	0	1	0	0	0	1.3027655423538516	
i 1	383.00120408163264	0.2525	72	926	4	4	10	1	0	0	1	0	0	4.017858234708573	
i 1	383.00762585034016	0.2525	74	610	1	24	6	2	0	-2	2	0	0	4.999520280622774	
i 1	383.01003401360543	0.2525	72	610	5	3	13	0	0	0	0	0	0	4.017858234708573	
i 1	383.01244217687076	0.505	72	926	6	5	2	0	0	0	0	0	0	5.900842882465954	
i 1	383.2391632653061	0.2525	74	1193	6	1	6	8	0	-2	8	0	0	11.177476464324647	
i 1	383.2431768707483	0.505	71	224	1	20	11	2	0	-2	2	0	0	0.9995202806227743	
i 1	383.24478231292517	0.7575000000000001	71	224	2	20	4	2	0	-2	2	0	0	0.9995202806227743	
i 1	383.25040136054423	0.505	71	1193	6	1	12	2	0	-1	2	0	0	11.177476464324647	
i 1	383.25040136054423	0.2525	69	224	7	5	15	1	0	-1	1	0	0	5.900842882465954	
i 1	383.25361224489797	0.505	72	224	6	9	13	1	0	0	1	0	0	3.0178582347085725	
i 1	383.48996598639457	0.505	71	224	7	1	2	2	0	-1	2	0	0	11.177476464324647	
i 1	383.4971904761905	0.2525	69	224	6	9	14	1	0	-1	1	0	0	3.0178582347085725	
i 1	383.4979931972789	0.505	74	610	4	24	4	2	0	-1	2	0	0	12.177476464324647	
i 1	383.50361224489797	0.2525	72	610	6	5	15	1	0	0	1	0	0	5.900842882465954	
i 1	383.50441496598637	1.5150000000000001	71	610	1	20	10	2	0	1	2	0	0	0.9995202806227743	
i 1	383.5156530612245	0.2525	69	1193	6	5	16	1	0	-1	1	0	0	5.900842882465954	
i 1	383.51806122448977	0.2525	74	610	1	20	2	2	0	1	2	0	0	0.9995202806227743	
i 1	383.73514965986396	0.2525	74	926	1	20	2	2	0	1	2	0	0	0.9995202806227743	
i 1	383.73755782312924	0.2525	74	1193	2	20	4	8	0	1	8	0	0	0.9995202806227743	
i 1	383.74478231292517	1.7675	69	1193	6	5	16	1	0	-1	1	0	0	5.900842882465954	
i 1	383.75120408163264	0.7575000000000001	72	610	5	3	2	0	0	0	0	0	0	4.017858234708573	
i 1	383.75842857142857	0.2525	69	1193	6	2	2	1	0	-1	1	0	0	4.017858234708573	
i 1	383.76324489795917	1.2625	72	926	4	4	3	1	0	0	1	0	0	4.017858234708573	
i 1	383.98996598639457	2.525	74	926	4	24	6	2	0	-2	2	0	0	12.177476464324647	
i 1	384.00441496598637	0.2525	71	224	7	1	13	2	0	-1	2	0	0	11.177476464324647	
i 1	384.25120408163264	0.2525	71	224	7	1	5	2	0	-1	2	0	0	11.177476464324647	
i 1	384.26404761904763	0.505	72	1193	6	2	1	1	0	0	1	0	0	4.017858234708573	
i 1	384.48755782312924	1.7675	74	224	2	24	9	8	0	-2	8	0	0	4.999520280622774	
i 1	384.4979931972789	0.2525	74	610	1	24	5	2	0	1	2	0	0	4.999520280622774	
i 1	384.51244217687076	1.01	71	224	2	20	13	2	0	-2	2	0	0	0.9995202806227743	
i 1	384.51806122448977	2.2725	69	926	6	5	15	0	0	0	0	0	0	5.900842882465954	
i 1	384.5196666666667	0.2525	74	224	1	20	1	8	0	-2	8	0	0	0.9995202806227743	
i 1	384.73514965986396	0.2525	74	926	2	24	10	2	0	1	2	0	0	4.999520280622774	
i 1	384.73675510204083	0.2525	72	224	6	9	9	1	0	0	1	0	0	3.0178582347085725	
i 1	384.74237414965984	0.2525	74	926	1	20	5	2	0	1	2	0	0	0.9995202806227743	
i 1	384.7479931972789	0.2525	72	610	6	5	10	1	0	0	1	0	0	5.900842882465954	
i 1	384.75040136054423	0.2525	71	224	7	1	16	2	0	-1	2	0	0	11.177476464324647	
i 1	384.75040136054423	0.2525	71	1193	2	20	4	2	0	-2	2	0	0	0.9995202806227743	
i 1	384.9979931972789	0.7575000000000001	72	926	6	5	5	0	0	0	0	0	0	5.900842882465954	
i 1	384.9979931972789	1.01	74	610	1	24	7	2	0	-2	2	0	0	4.999520280622774	
i 1	385.00361224489797	0.505	71	224	7	1	15	2	0	-1	2	0	0	11.177476464324647	
i 1	385.00361224489797	0.2525	72	610	5	3	10	0	0	0	0	0	0	4.017858234708573	
i 1	385.00521768707483	0.7575000000000001	69	610	4	4	6	1	0	-1	1	0	0	4.017858234708573	
i 1	385.01485034013604	0.505	74	224	1	20	1	2	0	-2	2	0	0	0.9995202806227743	
i 1	385.01806122448977	0.2525	69	224	6	9	13	1	0	-1	1	0	0	3.0178582347085725	
i 1	385.23595238095237	0.2525	72	1193	6	5	13	0	0	0	0	0	0	5.900842882465954	
i 1	385.24397959183676	0.505	69	1193	6	2	6	1	0	-1	1	0	0	4.017858234708573	
i 1	385.48193877551023	0.2525	71	610	1	20	2	2	0	1	2	0	0	0.9995202806227743	
i 1	385.48675510204083	0.2525	72	926	4	4	3	1	0	0	1	0	0	4.017858234708573	
i 1	385.5028095238095	0.2525	71	1193	6	1	2	2	0	-1	2	0	0	11.177476464324647	
i 1	385.51003401360543	0.505	72	610	6	5	4	1	0	0	1	0	0	5.900842882465954	
i 1	385.51404761904763	0.2525	74	926	6	1	1	8	0	-2	8	0	0	11.177476464324647	
i 1	385.73675510204083	1.01	72	1193	6	2	9	1	0	0	1	0	0	4.017858234708573	
i 1	385.74397959183676	0.2525	71	610	6	1	14	2	0	-1	2	0	0	11.177476464324647	
i 1	385.7479931972789	1.2625	71	610	1	24	8	8	0	-2	8	0	0	4.999520280622774	
i 1	385.76003401360543	0.2525	72	224	6	9	16	1	0	0	1	0	0	3.0178582347085725	
i 1	385.9803333333333	0.505	69	1193	6	5	13	1	0	-1	1	0	0	5.900842882465954	
i 1	385.98514965986396	0.7575000000000001	74	926	6	1	10	8	0	-2	8	0	0	11.177476464324647	
i 1	386.01003401360543	0.505	74	926	1	20	8	2	0	-2	2	0	0	0.9995202806227743	
i 1	386.01003401360543	0.2525	74	926	2	24	7	2	0	-2	2	0	0	4.999520280622774	
i 1	386.0156530612245	0.2525	69	224	7	5	10	1	0	-1	1	0	0	5.900842882465954	
i 1	386.23274149659863	0.2525	72	610	6	5	7	1	0	0	1	0	0	5.900842882465954	
i 1	386.24397959183676	2.525	71	610	1	20	8	2	0	1	2	0	0	0.9995202806227743	
i 1	386.24959863945577	0.505	72	1193	6	5	5	0	0	0	0	0	0	5.900842882465954	
i 1	386.25521768707483	0.505	71	224	2	20	2	2	0	-2	2	0	0	0.9995202806227743	
i 1	386.51324489795917	2.02	71	610	1	24	7	2	0	248	2	308	0	4.999520280622774	
i 1	386.51404761904763	0.505	69	224	7	5	16	1	0	-1	1	0	0	5.900842882465954	
i 1	386.7335442176871	1.2625	72	1193	5	2	12	1	0	0	1	0	0	4.017858234708573	
i 1	386.73755782312924	1.01	74	926	6	1	5	8	0	-2	8	0	0	11.177476464324647	
i 1	386.7383605442177	0.2525	69	1193	6	5	6	1	0	-1	1	0	0	5.900842882465954	
i 1	386.74157142857143	2.2725	71	1193	6	1	6	2	0	-1	2	0	0	11.177476464324647	
i 1	386.7568231292517	0.2525	74	926	4	24	9	2	0	-2	2	0	0	12.177476464324647	
i 1	386.75923129251703	1.2625	72	1193	6	5	16	0	0	0	0	0	0	5.900842882465954	
i 1	386.99076870748297	0.505	71	224	7	1	10	2	0	-1	2	0	0	11.177476464324647	
i 1	386.99076870748297	0.2525	69	610	6	5	8	1	0	0	1	0	0	5.900842882465954	
i 1	387.0028095238095	2.525	72	926	6	5	3	0	0	0	0	0	0	5.900842882465954	
i 1	387.00361224489797	0.505	74	224	2	24	12	8	0	-2	8	0	0	4.999520280622774	
i 1	387.2568231292517	1.01	69	926	5	3	8	1	0	0	1	0	0	4.017858234708573	
i 1	387.26003401360543	0.2525	71	610	1	24	11	8	0	-2	8	0	0	4.999520280622774	
i 1	387.4803333333333	0.7575000000000001	74	1193	6	1	9	8	0	-2	8	0	0	11.177476464324647	
i 1	387.4891632653061	0.2525	72	610	5	3	2	0	0	0	0	0	0	4.017858234708573	
i 1	387.4931768707483	0.2525	74	224	1	20	10	2	0	1	2	0	0	0.9995202806227743	
i 1	387.49959863945577	0.2525	69	610	6	5	1	1	0	0	1	0	0	5.900842882465954	
i 1	387.50602040816324	0.2525	74	926	4	24	5	2	0	-2	2	0	0	12.177476464324647	
i 1	387.51003401360543	2.02	72	926	4	4	15	1	0	0	1	0	0	4.017858234708573	
i 1	387.7343469387755	0.505	69	224	7	5	16	1	0	-1	1	0	0	5.900842882465954	
i 1	387.75441496598637	0.2525	74	610	4	24	9	2	0	-1	2	0	0	12.177476464324647	
i 1	387.75842857142857	0.2525	71	610	1	24	11	8	0	-2	8	0	0	4.999520280622774	
i 1	387.76886394557823	0.7575000000000001	71	610	6	1	11	2	0	-1	2	0	0	11.177476464324647	
i 1	387.98755782312924	0.505	69	1193	6	5	10	1	0	-1	1	0	0	5.900842882465954	
i 1	387.99397959183676	0.505	69	224	6	9	6	1	0	-1	1	0	0	3.0178582347085725	
i 1	388.0020068027211	6.8175	74	926	6	1	6	8	0	-2	8	0	0	11.177476464324647	
i 1	388.0068231292517	0.2525	69	1193	6	2	8	1	0	-1	1	0	0	4.017858234708573	
i 1	388.2335442176871	0.505	72	610	6	5	8	1	0	0	1	0	0	5.900842882465954	
i 1	388.2343469387755	0.2525	74	224	1	20	14	2	0	1	2	0	0	0.9995202806227743	
i 1	388.23755782312924	0.2525	71	224	7	1	12	2	0	-1	2	0	0	11.177476464324647	
i 1	388.23755782312924	0.2525	72	224	7	5	2	0	0	-1	0	0	0	5.900842882465954	
i 1	388.24638775510203	1.01	71	224	2	20	15	2	0	-2	2	0	0	0.9995202806227743	
i 1	388.25120408163264	0.2525	72	610	5	3	14	0	0	0	0	0	0	4.017858234708573	
i 1	388.4891632653061	0.2525	69	224	7	5	3	1	0	-1	1	0	0	5.900842882465954	
i 1	388.51003401360543	1.2625	71	610	1	24	16	8	0	-2	8	0	0	4.999520280622774	
i 1	388.51244217687076	0.2525	74	1193	2	20	14	8	0	-2	8	0	0	0.9995202806227743	
i 1	388.5156530612245	1.2625	72	1193	5	2	11	1	0	0	1	0	0	4.017858234708573	
i 1	388.5164557823129	0.2525	74	926	4	24	7	2	0	-2	2	0	0	12.177476464324647	
i 1	388.5196666666667	0.2525	74	926	1	20	4	8	0	-2	8	0	0	0.9995202806227743	
i 1	388.74157142857143	1.01	69	1193	6	5	4	1	0	-1	1	0	0	5.900842882465954	
i 1	388.7656530612245	0.2525	72	224	6	9	15	1	0	0	1	0	0	3.0178582347085725	
i 1	388.76886394557823	0.2525	69	224	6	9	16	1	0	-1	1	0	0	3.0178582347085725	
i 1	388.9803333333333	0.2525	71	1193	2	20	10	2	0	-2	2	0	0	0.9995202806227743	
i 1	388.98113605442177	0.7575000000000001	74	926	1	20	7	2	0	-2	2	0	0	0.9995202806227743	
i 1	388.9843469387755	0.2525	72	224	7	5	15	0	0	-1	0	0	0	5.900842882465954	
i 1	388.99397959183676	1.2625	69	926	5	3	8	1	0	0	1	0	0	4.017858234708573	
i 1	389.01404761904763	0.7575000000000001	74	1193	6	1	15	8	0	-2	8	0	0	11.177476464324647	
i 1	389.2303333333333	0.505	72	1193	6	5	9	0	0	0	0	0	0	5.900842882465954	
i 1	389.25040136054423	0.505	69	926	6	5	11	0	0	0	0	0	0	5.900842882465954	
i 1	389.48755782312924	0.2525	71	610	1	20	11	2	0	1	2	0	0	0.9995202806227743	
i 1	389.49478231292517	0.2525	74	224	2	24	10	8	0	-2	8	0	0	4.999520280622774	
i 1	389.50361224489797	0.2525	69	610	4	4	2	1	0	-1	1	0	0	4.017858234708573	
i 1	389.73193877551023	0.7575000000000001	74	722	1	20	11	2	0	-2	2	0	0	0.9995202806227743	
i 1	389.7343469387755	0.2525	72	926	6	5	16	0	0	0	0	0	0	5.900842882465954	
i 1	389.73514965986396	0.2525	74	1108	6	1	7	8	0	-1	8	0	0	11.177476464324647	
i 1	389.73514965986396	0.2525	69	1108	4	2	16	0	0	-1	0	0	0	4.017858234708573	
i 1	389.74076870748297	1.01	74	926	4	24	11	2	0	-2	2	0	0	12.177476464324647	
i 1	389.74478231292517	1.7675	71	224	2	20	11	2	0	-2	2	0	0	0.9995202806227743	
i 1	389.74638775510203	1.2625	69	926	6	5	15	0	0	0	0	0	0	5.900842882465954	
i 1	389.74879591836736	0.2525	72	722	5	3	11	1	0	-1	1	0	0	4.017858234708573	
i 1	389.7520068027211	0.2525	74	722	1	24	2	8	0	1	8	0	0	4.999520280622774	
i 1	389.7568231292517	0.505	71	722	1	24	11	2	0	252	2	307	0	4.999520280622774	
i 1	389.76003401360543	0.505	69	1108	6	5	3	0	0	-1	0	0	0	5.900842882465954	
i 1	389.76003401360543	3.0300000000000002	60	1108	3	14	10	5	0	0	5	0	0	2.605531084707703	
i 1	389.76485034013604	2.2725	72	926	4	4	10	1	0	0	1	0	0	4.017858234708573	
i 1	389.76485034013604	3.0300000000000002	60	1108	4	14	16	0	0	0	0	0	0	2.605531084707703	
i 1	389.7656530612245	0.505	74	224	1	20	5	2	0	-2	2	0	0	0.9995202806227743	
i 1	389.9803333333333	1.5150000000000001	72	1108	4	2	13	0	0	0	0	0	0	4.017858234708573	
i 1	389.9931768707483	1.2625	69	722	6	5	7	1	0	0	1	0	0	5.900842882465954	
i 1	389.99397959183676	0.505	69	224	6	9	9	1	0	-1	1	0	0	3.0178582347085725	
i 1	389.99959863945577	0.505	71	224	7	1	9	2	0	-1	2	0	0	11.177476464324647	
i 1	390.00602040816324	0.2525	72	224	7	5	12	0	0	-1	0	0	0	5.900842882465954	
i 1	390.2303333333333	0.2525	69	224	7	5	11	1	0	-1	1	0	0	5.900842882465954	
i 1	390.2479931972789	0.2525	74	926	1	20	6	2	0	1	2	0	0	0.9995202806227743	
i 1	390.24959863945577	0.505	74	1108	6	1	6	8	0	-1	8	0	0	11.177476464324647	
i 1	390.25040136054423	0.2525	72	926	6	5	10	0	0	0	0	0	0	5.900842882465954	
i 1	390.25762585034016	0.2525	71	1108	1	20	13	2	0	1	2	0	0	0.9995202806227743	
i 1	390.25923129251703	0.2525	74	1108	1	20	9	8	0	1	8	0	0	0.9995202806227743	
i 1	390.4835442176871	0.2525	69	926	5	3	2	1	0	0	1	0	0	4.017858234708573	
i 1	390.48996598639457	0.2525	71	224	1	20	7	2	0	1	2	0	0	0.9995202806227743	
i 1	390.49558503401363	0.505	72	722	4	4	4	0	0	0	0	0	0	4.017858234708573	
i 1	390.50120408163264	0.2525	71	224	1	20	8	2	0	1	2	0	0	0.9995202806227743	
i 1	390.5156530612245	2.2725	69	1108	6	5	7	0	0	-1	0	0	0	5.900842882465954	
i 1	390.51886394557823	1.01	74	722	4	24	9	8	0	-2	8	0	0	12.177476464324647	
i 1	390.73113605442177	0.2525	74	1108	1	20	6	8	0	1	8	0	0	0.9995202806227743	
i 1	390.7431768707483	3.0300000000000002	74	722	1	20	14	2	0	-2	2	0	0	0.9995202806227743	
i 1	390.74558503401363	0.2525	74	1108	1	20	1	2	0	1	2	0	0	0.9995202806227743	
i 1	390.74638775510203	0.2525	74	722	6	1	2	2	0	-1	2	0	0	11.177476464324647	
i 1	390.75361224489797	0.2525	72	224	6	9	10	1	0	0	1	0	0	3.0178582347085725	
i 1	390.76404761904763	0.2525	74	926	1	20	10	2	0	-2	2	0	0	0.9995202806227743	
i 1	390.98595238095237	0.2525	71	224	7	1	1	2	0	-1	2	0	0	11.177476464324647	
i 1	390.98755782312924	0.505	74	1108	6	1	15	2	0	-2	2	0	0	11.177476464324647	
i 1	390.99478231292517	0.2525	72	926	6	5	1	0	0	0	0	0	0	5.900842882465954	
i 1	390.99638775510203	1.5150000000000001	74	224	1	20	2	8	0	-2	8	0	0	0.9995202806227743	
i 1	390.99879591836736	0.2525	69	224	7	5	4	1	0	-1	1	0	0	5.900842882465954	
i 1	391.00842857142857	0.505	72	722	5	3	13	1	0	-1	1	0	0	4.017858234708573	
i 1	391.2391632653061	0.505	69	926	6	5	4	0	0	0	0	0	0	5.900842882465954	
i 1	391.24076870748297	0.2525	69	1108	6	5	6	0	0	0	0	0	0	5.900842882465954	
i 1	391.24638775510203	2.02	74	926	4	24	3	2	0	-2	2	0	0	12.177476464324647	
i 1	391.2471904761905	1.5150000000000001	69	926	5	3	6	1	0	0	1	0	0	4.017858234708573	
i 1	391.25923129251703	3.2825	74	722	1	24	12	8	0	1	8	0	0	4.999520280622774	
i 1	391.26886394557823	0.2525	72	224	7	5	1	0	0	-1	0	0	0	5.900842882465954	
i 1	391.4883605442177	0.505	69	722	6	5	11	1	0	0	1	0	0	5.900842882465954	
i 1	391.48996598639457	0.2525	72	722	4	4	16	0	0	0	0	0	0	4.017858234708573	
i 1	391.50040136054423	0.2525	69	1108	4	2	13	0	0	-1	0	0	0	4.017858234708573	
i 1	391.51886394557823	0.2525	71	224	7	1	10	2	0	-1	2	0	0	11.177476464324647	
i 1	391.73996598639457	0.2525	71	224	7	1	1	2	0	-1	2	0	0	11.177476464324647	
i 1	391.76806122448977	0.7575000000000001	69	224	6	9	12	1	0	-1	1	0	0	3.0178582347085725	
i 1	391.9835442176871	0.505	74	1108	6	1	12	2	0	-2	2	0	0	11.177476464324647	
i 1	391.99076870748297	1.5150000000000001	69	926	6	5	1	0	0	0	0	0	0	5.900842882465954	
i 1	391.99558503401363	0.2525	74	224	1	24	13	8	0	-2	8	0	0	4.999520280622774	
i 1	392.00441496598637	0.2525	74	722	4	24	3	8	0	-2	8	0	0	12.177476464324647	
i 1	392.01886394557823	0.2525	72	722	4	4	15	0	0	0	0	0	0	4.017858234708573	
i 1	392.23113605442177	1.2625	74	224	1	24	1	8	0	252	8	307	0	4.999520280622774	
i 1	392.23595238095237	0.505	74	722	6	1	10	2	0	-1	2	0	0	11.177476464324647	
i 1	392.23996598639457	0.2525	72	926	4	4	13	1	0	0	1	0	0	4.017858234708573	
i 1	392.24959863945577	0.2525	69	722	6	5	15	1	0	0	1	0	0	5.900842882465954	
i 1	392.25842857142857	0.2525	72	224	6	9	9	1	0	0	1	0	0	3.0178582347085725	
i 1	392.2608367346939	0.2525	72	926	6	5	1	0	0	0	0	0	0	5.900842882465954	
i 1	392.48193877551023	1.5150000000000001	69	1108	4	2	14	0	0	-1	0	0	0	4.017858234708573	
i 1	392.49558503401363	0.7575000000000001	69	224	7	5	12	1	0	-1	1	0	0	5.900842882465954	
i 1	392.50521768707483	0.2525	74	926	1	20	13	2	0	1	2	0	0	0.9995202806227743	
i 1	392.50842857142857	0.2525	74	1108	1	20	9	8	0	1	8	0	0	0.9995202806227743	
i 1	392.50923129251703	0.2525	74	1108	6	1	16	8	0	-1	8	0	0	11.177476464324647	
i 1	392.7343469387755	6.0600000000000005	60	1108	5	14	14	5	0	0	5	0	0	2.605531084707703	
i 1	392.74879591836736	3.0300000000000002	60	1108	3	14	9	0	0	0	0	0	0	2.605531084707703	
i 1	392.75120408163264	0.2525	74	1108	6	1	1	2	0	-2	2	0	0	11.177476464324647	
i 1	392.7528095238095	2.525	69	926	4	3	9	1	0	0	1	0	0	4.017858234708573	
i 1	392.75923129251703	0.2525	69	224	6	9	14	1	0	-1	1	0	0	3.0178582347085725	
i 1	392.7656530612245	2.2725	69	1108	6	5	2	0	0	0	0	0	0	5.900842882465954	
i 1	392.7696666666667	0.505	71	224	1	20	3	2	0	1	2	0	0	0.9995202806227743	
i 1	392.9891632653061	0.505	72	722	4	4	6	0	0	0	0	0	0	4.017858234708573	
i 1	392.99558503401363	0.505	74	1108	6	1	4	8	0	-1	8	0	0	11.177476464324647	
i 1	393.0108367346939	0.505	74	722	4	24	3	8	0	-2	8	0	0	12.177476464324647	
i 1	393.0108367346939	0.2525	69	722	6	5	11	0	0	0	0	0	0	5.900842882465954	
i 1	393.23996598639457	1.01	69	1108	5	5	9	0	0	-1	0	0	0	5.900842882465954	
i 1	393.2431768707483	0.505	71	224	7	1	12	2	0	-1	2	0	0	11.177476464324647	
i 1	393.2528095238095	0.2525	71	926	1	20	12	8	0	-2	8	0	0	0.9995202806227743	
i 1	393.25842857142857	0.2525	71	1108	1	20	2	2	0	1	2	0	0	0.9995202806227743	
i 1	393.4803333333333	0.2525	74	224	1	20	14	2	0	1	2	0	0	0.9995202806227743	
i 1	393.49558503401363	0.2525	74	926	4	24	11	2	0	-2	2	0	0	12.177476464324647	
i 1	393.5068231292517	0.2525	72	224	6	9	14	1	0	0	1	0	0	3.0178582347085725	
i 1	393.51485034013604	1.5150000000000001	74	224	1	24	8	8	0	-2	8	0	0	4.999520280622774	
i 1	393.73113605442177	0.2525	72	926	6	5	11	0	0	0	0	0	0	5.900842882465954	
i 1	393.73193877551023	0.2525	74	926	1	20	6	2	0	1	2	0	0	0.9995202806227743	
i 1	393.73595238095237	0.2525	74	926	1	24	15	2	0	1	2	0	0	4.999520280622774	
i 1	393.73755782312924	1.5150000000000001	72	926	4	4	3	1	0	0	1	0	0	4.017858234708573	
i 1	393.74478231292517	2.2725	74	1108	6	1	13	8	0	-1	8	0	0	11.177476464324647	
i 1	393.74638775510203	0.505	72	224	7	5	14	0	0	-1	0	0	0	5.900842882465954	
i 1	393.74959863945577	0.2525	74	722	6	1	12	2	0	-1	2	0	0	11.177476464324647	
i 1	393.75842857142857	0.2525	74	722	4	24	2	8	0	-2	8	0	0	12.177476464324647	
i 1	393.76324489795917	0.2525	69	224	6	9	7	1	0	-1	1	0	0	3.0178582347085725	
i 1	393.76485034013604	0.2525	74	1108	1	20	8	2	0	1	2	0	0	0.9995202806227743	
i 1	393.98675510204083	0.2525	69	722	6	5	2	0	0	0	0	0	0	5.900842882465954	
i 1	393.99237414965984	0.505	74	224	1	20	1	2	0	-2	2	0	0	0.9995202806227743	
i 1	393.99397959183676	0.505	72	722	5	3	5	1	0	-1	1	0	0	4.017858234708573	
i 1	394.0116394557823	1.7675	71	224	1	20	11	2	0	-2	2	0	0	0.9995202806227743	
i 1	394.24558503401363	0.2525	69	722	6	5	2	1	0	0	1	0	0	5.900842882465954	
i 1	394.2479931972789	0.2525	71	224	7	1	15	2	0	-1	2	0	0	11.177476464324647	
i 1	394.2608367346939	0.505	69	224	7	5	10	1	0	-1	1	0	0	5.900842882465954	
i 1	394.26244217687076	0.2525	72	722	4	4	16	0	0	0	0	0	0	4.017858234708573	
i 1	394.26886394557823	0.2525	74	722	6	1	1	2	0	-1	2	0	0	11.177476464324647	
i 1	394.48113605442177	1.7675	74	1108	6	1	13	2	0	-2	2	0	0	11.177476464324647	
i 1	394.48113605442177	0.2525	71	926	1	24	13	2	0	-2	2	0	0	4.999520280622774	
i 1	394.49157142857143	0.505	74	926	4	24	16	2	0	-2	2	0	0	12.177476464324647	
i 1	394.5020068027211	1.2625	69	1108	5	5	11	0	0	-1	0	0	0	5.900842882465954	
i 1	394.5020068027211	0.7575000000000001	71	1108	1	20	3	2	0	-2	2	0	0	0.9995202806227743	
i 1	394.50842857142857	0.505	69	1108	4	2	1	0	0	-1	0	0	0	4.017858234708573	
i 1	394.51806122448977	0.7575000000000001	72	926	6	5	15	0	0	0	0	0	0	5.900842882465954	
i 1	394.7303333333333	0.2525	72	722	5	3	6	1	0	-1	1	0	0	4.017858234708573	
i 1	394.74157142857143	0.2525	69	722	6	5	5	0	0	0	0	0	0	5.900842882465954	
i 1	394.75521768707483	1.01	74	722	1	24	12	8	0	1	8	0	0	4.999520280622774	
i 1	394.7608367346939	0.505	74	722	4	24	16	8	0	-2	8	0	0	12.177476464324647	
i 1	394.7608367346939	0.505	71	926	1	24	9	2	0	248	2	308	0	4.999520280622774	
i 1	395.0028095238095	0.2525	72	224	6	9	15	1	0	0	1	0	0	3.0178582347085725	
i 1	395.01485034013604	0.2525	71	224	7	1	14	2	0	-1	2	0	0	11.177476464324647	
i 1	395.01725850340137	0.2525	74	1108	1	20	12	2	0	-2	2	0	0	0.9995202806227743	
i 1	395.01886394557823	0.2525	69	926	6	5	3	0	0	0	0	0	0	5.900842882465954	
i 1	395.01886394557823	0.505	69	224	7	5	10	1	0	-1	1	0	0	5.900842882465954	
i 1	395.23595238095237	0.505	69	722	4	4	14	0	0	0	0	0	0	4.017858234708573	
i 1	395.2391632653061	1.2625	74	224	1	20	6	2	0	-2	2	0	0	0.9995202806227743	
i 1	395.2431768707483	4.04	69	722	4	3	15	1	0	0	1	0	0	4.017858234708573	
i 1	395.24478231292517	5.3025	71	722	4	24	11	2	0	-1	2	0	0	12.177476464324647	
i 1	395.26003401360543	0.2525	72	722	4	4	14	0	0	0	0	0	0	4.017858234708573	
i 1	395.26404761904763	0.2525	74	722	6	1	5	2	0	-1	2	0	0	11.177476464324647	
i 1	395.26485034013604	0.505	69	722	6	5	12	0	0	0	0	0	0	5.900842882465954	
i 1	395.26485034013604	3.535	60	722	4	7	2	0	0	0	0	0	0	1.3027655423538516	
i 1	395.26806122448977	3.535	69	722	6	5	6	0	0	0	0	0	0	5.900842882465954	
i 1	395.48193877551023	0.2525	74	722	1	20	1	2	0	-2	2	0	0	0.9995202806227743	
i 1	395.50762585034016	0.7575000000000001	72	722	5	3	2	1	0	-1	1	0	0	4.017858234708573	
i 1	395.51725850340137	0.2525	69	1108	6	5	14	0	0	0	0	0	0	5.900842882465954	
i 1	395.7383605442177	0.2525	71	224	7	1	11	2	0	-1	2	0	0	11.177476464324647	
i 1	395.7431768707483	0.7575000000000001	69	722	6	5	15	1	0	0	1	0	0	5.900842882465954	
i 1	395.7479931972789	5.05	60	1108	5	14	8	0	0	0	0	0	0	2.605531084707703	
i 1	395.74879591836736	0.2525	74	224	1	24	14	8	0	-2	8	0	0	4.999520280622774	
i 1	395.75120408163264	0.2525	72	224	7	5	7	0	0	-1	0	0	0	5.900842882465954	
i 1	395.76324489795917	0.2525	72	224	6	9	1	1	0	0	1	0	0	3.0178582347085725	
i 1	395.76485034013604	1.01	69	224	6	5	7	1	0	-1	1	0	0	5.900842882465954	
i 1	395.7664557823129	0.2525	69	224	6	9	6	1	0	-1	1	0	0	3.0178582347085725	
i 1	395.9843469387755	0.7575000000000001	71	224	7	1	16	2	0	-1	2	0	0	11.177476464324647	
i 1	395.9891632653061	0.2525	74	722	1	20	7	2	0	-2	2	0	0	0.9995202806227743	
i 1	395.99879591836736	1.01	72	722	4	4	4	0	0	0	0	0	0	4.017858234708573	
i 1	396.00762585034016	0.2525	72	1108	4	2	1	0	0	0	0	0	0	4.017858234708573	
i 1	396.2335442176871	2.525	74	224	1	24	1	8	0	-2	8	0	0	4.999520280622774	
i 1	396.2343469387755	2.525	69	722	4	4	16	0	0	0	0	0	0	4.017858234708573	
i 1	396.24237414965984	0.2525	74	1108	6	1	13	8	0	-1	8	0	0	11.177476464324647	
i 1	396.2616394557823	0.2525	74	722	6	1	6	2	0	-1	2	0	0	11.177476464324647	
i 1	396.48113605442177	0.2525	71	722	1	20	13	2	0	1	2	0	0	0.9995202806227743	
i 1	396.48755782312924	0.2525	71	1108	1	20	9	2	0	-2	2	0	0	0.9995202806227743	
i 1	396.4883605442177	0.2525	72	1108	4	2	10	0	0	0	0	0	0	4.017858234708573	
i 1	396.49879591836736	0.2525	71	722	1	24	4	2	0	1	2	0	0	4.999520280622774	
i 1	396.5068231292517	2.2725	74	722	6	1	6	2	0	-1	2	0	0	11.177476464324647	
i 1	396.51806122448977	0.2525	74	1108	6	1	3	2	0	-2	2	0	0	11.177476464324647	
i 1	396.76324489795917	0.505	69	722	6	5	4	1	0	0	1	0	0	5.900842882465954	
i 1	396.7664557823129	0.2525	72	224	6	9	16	1	0	0	1	0	0	3.0178582347085725	
i 1	396.9835442176871	0.505	69	722	6	5	14	0	0	0	0	0	0	5.900842882465954	
i 1	397.0116394557823	0.2525	72	224	7	5	13	0	0	-1	0	0	0	5.900842882465954	
i 1	397.23514965986396	0.2525	69	1108	4	2	1	0	0	-1	0	0	0	4.017858234708573	
i 1	397.23675510204083	0.505	69	224	6	5	10	1	0	-1	1	0	0	5.900842882465954	
i 1	397.2383605442177	2.02	69	1108	6	5	16	0	0	-1	0	0	0	5.900842882465954	
i 1	397.24478231292517	0.2525	74	722	1	20	12	2	0	-2	2	0	0	0.9995202806227743	
i 1	397.25040136054423	1.01	74	1108	6	1	2	2	0	-2	2	0	0	11.177476464324647	
i 1	397.26003401360543	0.505	69	224	6	9	13	1	0	-1	1	0	0	3.0178582347085725	
i 1	397.50040136054423	0.2525	69	722	6	5	9	0	0	0	0	0	0	5.900842882465954	
i 1	397.50441496598637	0.2525	74	722	6	1	9	2	0	-1	2	0	0	11.177476464324647	
i 1	397.51404761904763	0.7575000000000001	72	722	4	4	15	0	0	0	0	0	0	4.017858234708573	
i 1	397.7303333333333	0.2525	72	224	7	5	4	0	0	-1	0	0	0	5.900842882465954	
i 1	397.7391632653061	0.2525	69	1108	4	2	5	0	0	-1	0	0	0	4.017858234708573	
i 1	397.75120408163264	0.505	69	722	6	5	6	1	0	0	1	0	0	5.900842882465954	
i 1	397.75120408163264	1.5150000000000001	71	224	1	20	6	2	0	1	2	0	0	0.9995202806227743	
i 1	398.01485034013604	0.505	69	224	6	9	11	1	0	-1	1	0	0	3.0178582347085725	
i 1	398.23675510204083	0.2525	74	722	6	1	15	2	0	-1	2	0	0	11.177476464324647	
i 1	398.25361224489797	1.5150000000000001	74	722	4	24	10	8	0	-2	8	0	0	12.177476464324647	
i 1	398.2664557823129	0.505	72	224	7	5	9	0	0	-1	0	0	0	5.900842882465954	
i 1	398.49397959183676	0.2525	74	1108	6	1	1	8	0	-1	8	0	0	11.177476464324647	
i 1	398.49397959183676	0.2525	72	224	6	9	8	1	0	0	1	0	0	3.0178582347085725	
i 1	398.49478231292517	0.2525	69	722	6	5	5	1	0	0	1	0	0	5.900842882465954	
i 1	398.51485034013604	2.2725	69	1108	4	2	7	0	0	-1	0	0	0	4.017858234708573	
i 1	398.73113605442177	1.01	69	722	6	5	10	0	0	0	0	0	0	5.900842882465954	
i 1	398.7343469387755	2.02	69	722	5	5	5	0	0	0	0	0	0	5.900842882465954	
i 1	398.73675510204083	2.02	60	1108	4	14	9	5	0	0	5	0	0	2.605531084707703	
i 1	398.7479931972789	0.505	69	1108	6	5	1	0	0	0	0	0	0	5.900842882465954	
i 1	398.75521768707483	3.0300000000000002	60	722	4	7	6	0	0	0	0	0	0	1.3027655423538516	
i 1	398.75762585034016	0.2525	71	224	1	20	5	2	0	-2	2	0	0	0.9995202806227743	
i 1	398.76725850340137	0.2525	72	224	4	9	16	1	0	0	1	0	0	3.0178582347085725	
i 1	398.9835442176871	0.505	72	1108	4	2	7	0	0	0	0	0	0	4.017858234708573	
i 1	398.9931768707483	0.2525	72	722	4	4	4	0	0	0	0	0	0	4.017858234708573	
i 1	398.99397959183676	0.2525	74	722	6	1	13	2	0	-1	2	0	0	11.177476464324647	
i 1	399.0020068027211	2.525	74	722	6	1	2	2	0	-1	2	0	0	11.177476464324647	
i 1	399.24397959183676	0.2525	71	722	1	20	12	2	0	1	2	0	0	0.9995202806227743	
i 1	399.24558503401363	0.505	69	224	6	9	4	1	0	-1	1	0	0	3.0178582347085725	
i 1	399.2528095238095	0.2525	69	224	6	5	7	1	0	-1	1	0	0	5.900842882465954	
i 1	399.25923129251703	0.2525	74	1108	1	20	11	2	0	-2	2	0	0	0.9995202806227743	
i 1	399.26003401360543	0.2525	69	722	6	5	5	1	0	0	1	0	0	5.900842882465954	
i 1	399.2664557823129	0.505	69	722	4	4	3	0	0	0	0	0	0	4.017858234708573	
i 1	399.48274149659863	0.505	71	224	1	20	2	2	0	-2	2	0	0	0.9995202806227743	
i 1	399.4835442176871	0.2525	72	224	6	5	10	0	0	-1	0	0	0	5.900842882465954	
i 1	399.5068231292517	0.505	69	722	6	5	7	0	0	0	0	0	0	5.900842882465954	
i 1	399.51725850340137	0.505	72	722	5	3	12	1	0	-1	1	0	0	4.017858234708573	
i 1	399.5196666666667	0.505	71	224	7	1	8	2	0	-1	2	0	0	11.177476464324647	
i 1	399.73274149659863	2.02	69	722	4	3	2	1	0	0	1	0	0	4.017858234708573	
i 1	399.74076870748297	1.01	69	1108	6	5	6	0	0	-1	0	0	0	5.900842882465954	
i 1	399.74638775510203	0.2525	69	1108	6	5	10	0	0	0	0	0	0	5.900842882465954	
i 1	399.7656530612245	0.505	72	224	4	9	8	1	0	0	1	0	0	3.0178582347085725	
i 1	399.76886394557823	0.2525	74	1108	6	1	1	8	0	-1	8	0	0	11.177476464324647	
i 1	399.98675510204083	0.2525	74	1108	1	20	6	2	0	1	2	0	0	0.9995202806227743	
i 1	399.9883605442177	0.2525	69	224	6	9	13	1	0	-1	1	0	0	3.0178582347085725	
i 1	399.9891632653061	0.2525	71	722	1	24	2	2	0	1	2	0	0	4.999520280622774	
i 1	400.00762585034016	0.2525	74	722	6	1	11	2	0	-1	2	0	0	11.177476464324647	
i 1	400.01404761904763	0.2525	74	722	4	24	8	8	0	-2	8	0	0	12.177476464324647	
i 1	400.0164557823129	1.2625	69	722	6	5	13	0	0	0	0	0	0	5.900842882465954	
i 1	400.2471904761905	1.5150000000000001	71	224	1	20	8	2	0	-2	2	0	0	0.9995202806227743	
i 1	400.2528095238095	0.505	72	722	5	3	11	1	0	-1	1	0	0	4.017858234708573	
i 1	400.2568231292517	1.2625	71	224	1	20	6	2	0	-2	2	0	0	0.9995202806227743	
i 1	400.26404761904763	3.0300000000000002	69	722	4	4	2	0	0	0	0	0	0	4.017858234708573	
i 1	400.4891632653061	0.2525	69	722	6	5	11	1	0	0	1	0	0	5.900842882465954	
i 1	400.49959863945577	0.2525	71	224	7	1	2	2	0	-1	2	0	0	11.177476464324647	
i 1	400.50361224489797	0.2525	71	224	7	1	16	2	0	-1	2	0	0	11.177476464324647	
i 1	400.50441496598637	0.2525	74	1108	6	1	12	2	0	-2	2	0	0	11.177476464324647	
i 1	400.73274149659863	0.2525	69	926	4	2	16	0	0	-1	0	0	0	4.017858234708573	
i 1	400.73274149659863	1.7675	72	926	6	5	11	1	0	-1	1	0	0	5.900842882465954	
i 1	400.7383605442177	2.525	74	926	6	1	12	2	0	-1	2	0	0	11.177476464324647	
i 1	400.74157142857143	10.1	60	926	4	14	2	5	0	1	5	0	0	2.605531084707703	
i 1	400.74237414965984	1.01	67	926	5	14	7	5	0	0	5	0	0	2.605531084707703	
i 1	400.75602040816324	0.2525	69	224	6	5	8	1	0	-1	1	0	0	5.900842882465954	
i 1	400.76003401360543	0.7575000000000001	71	224	1	24	9	2	0	252	2	307	0	4.999520280622774	
i 1	400.7608367346939	0.2525	69	224	6	9	13	1	0	-1	1	0	0	3.0178582347085725	
i 1	400.7616394557823	1.01	74	926	6	1	3	8	0	-2	8	0	0	11.177476464324647	
i 1	400.7616394557823	0.2525	69	224	6	5	11	0	0	-1	0	0	0	5.900842882465954	
i 1	400.76806122448977	0.2525	71	722	4	24	11	2	0	-1	2	0	0	12.177476464324647	
i 1	400.9891632653061	0.7575000000000001	69	722	5	5	6	0	0	0	0	0	0	5.900842882465954	
i 1	401.01003401360543	0.2525	71	224	5	24	10	8	0	-2	8	0	0	12.177476464324647	
i 1	401.01324489795917	0.505	72	224	4	9	4	1	0	0	1	0	0	3.0178582347085725	
i 1	401.01725850340137	0.2525	72	224	5	4	9	1	0	-1	1	0	0	4.017858234708573	
i 1	401.2479931972789	0.2525	72	224	6	5	12	0	0	0	0	0	0	5.900842882465954	
i 1	401.26244217687076	0.505	71	224	7	1	5	2	0	-1	2	0	0	11.177476464324647	
i 1	401.2696666666667	0.505	72	224	6	3	13	1	0	-1	1	0	0	4.017858234708573	
i 1	401.48755782312924	0.2525	71	722	4	24	4	2	0	-1	2	0	0	12.177476464324647	
i 1	401.50842857142857	0.2525	72	224	6	5	16	0	0	-1	0	0	0	5.900842882465954	
i 1	401.5108367346939	0.2525	71	722	1	24	8	8	0	-2	8	0	0	4.999520280622774	
i 1	401.51886394557823	0.2525	69	926	4	2	14	0	0	-1	0	0	0	4.017858234708573	
i 1	401.51886394557823	0.2525	71	926	1	20	2	2	0	-2	2	0	0	0.9995202806227743	
i 1	401.7335442176871	0.2525	69	926	5	2	9	0	0	-1	0	0	0	4.017858234708573	
i 1	401.73675510204083	0.2525	71	224	7	1	9	2	0	-1	2	0	0	11.177476464324647	
i 1	401.7431768707483	0.505	69	224	6	5	2	1	0	-1	1	0	0	5.900842882465954	
i 1	401.74397959183676	0.2525	72	224	5	5	1	0	0	0	0	0	0	5.900842882465954	
i 1	401.74638775510203	9.09	67	926	4	14	11	5	0	0	5	0	0	2.605531084707703	
i 1	401.75040136054423	0.2525	72	224	5	4	3	1	0	-1	1	0	0	4.017858234708573	
i 1	401.75040136054423	3.2825	69	722	6	5	1	0	0	0	0	0	0	5.900842882465954	
i 1	401.75120408163264	6.0600000000000005	60	722	5	7	13	0	0	0	0	0	0	1.3027655423538516	
i 1	401.7520068027211	0.2525	71	224	5	24	7	8	0	-2	8	0	0	12.177476464324647	
i 1	401.75441496598637	0.2525	74	926	6	1	15	8	0	-2	8	0	0	11.177476464324647	
i 1	401.7568231292517	0.505	72	926	4	2	2	0	0	0	0	0	0	4.017858234708573	
i 1	401.98675510204083	0.505	74	722	6	1	1	2	0	-1	2	0	0	11.177476464324647	
i 1	401.99157142857143	4.2925	69	722	4	3	12	1	0	0	1	0	0	4.017858234708573	
i 1	401.99638775510203	0.7575000000000001	72	926	6	5	5	1	0	-1	1	0	0	5.900842882465954	
i 1	402.00602040816324	0.505	69	224	4	9	11	1	0	-1	1	0	0	3.0178582347085725	
i 1	402.0116394557823	2.2725	71	722	4	24	13	2	0	-1	2	0	0	12.177476464324647	
i 1	402.26324489795917	0.7575000000000001	69	722	5	5	1	0	0	0	0	0	0	5.900842882465954	
i 1	402.48996598639457	0.505	72	224	5	4	16	1	0	-1	1	0	0	4.017858234708573	
i 1	402.50120408163264	0.2525	72	224	4	9	6	1	0	0	1	0	0	3.0178582347085725	
i 1	402.50923129251703	0.505	69	224	6	5	4	0	0	-1	0	0	0	5.900842882465954	
i 1	402.51244217687076	0.7575000000000001	74	926	6	1	12	8	0	-2	8	0	0	11.177476464324647	
i 1	402.73193877551023	0.2525	74	224	6	1	1	2	0	-2	2	0	0	11.177476464324647	
i 1	402.74879591836736	0.505	69	926	5	2	14	0	0	-1	0	0	0	4.017858234708573	
i 1	402.75923129251703	0.2525	71	722	1	24	11	2	0	1	2	0	0	4.0	
i 1	402.7616394557823	0.2525	72	224	5	5	8	0	0	0	0	0	0	5.900842882465954	
i 1	402.99237414965984	0.2525	72	224	6	5	6	0	0	-1	0	0	0	5.900842882465954	
i 1	403.0108367346939	0.505	69	224	4	9	4	1	0	-1	1	0	0	3.0178582347085725	
i 1	403.0156530612245	1.2625	72	926	6	5	8	1	0	-1	1	0	0	5.900842882465954	
i 1	403.0164557823129	6.8175	72	926	6	5	4	1	0	-1	1	0	0	5.900842882465954	
i 1	403.01886394557823	0.505	71	224	5	24	2	8	0	-2	8	0	0	12.177476464324647	
i 1	403.2391632653061	4.545	74	722	6	1	7	2	0	-1	2	0	0	11.177476464324647	
i 1	403.24397959183676	0.2525	72	224	4	9	3	1	0	0	1	0	0	3.0178582347085725	
i 1	403.25762585034016	0.505	71	224	7	1	4	2	0	-1	2	0	0	11.177476464324647	
i 1	403.25842857142857	0.2525	72	224	6	3	2	1	0	-1	1	0	0	4.017858234708573	
i 1	403.48514965986396	0.505	72	926	4	2	14	0	0	0	0	0	0	4.017858234708573	
i 1	403.48595238095237	0.2525	74	926	6	1	9	2	0	-1	2	0	0	11.177476464324647	
i 1	403.4971904761905	0.2525	72	224	5	4	3	1	0	-1	1	0	0	4.017858234708573	
i 1	403.5020068027211	0.505	74	224	1	24	9	8	0	-2	8	0	0	4.0	
i 1	403.51485034013604	1.2625	69	722	4	4	1	0	0	0	0	0	0	4.017858234708573	
i 1	403.74237414965984	0.7575000000000001	71	224	7	1	15	2	0	-1	2	0	0	11.177476464324647	
i 1	403.7528095238095	0.2525	71	224	5	24	14	8	0	-2	8	0	0	12.177476464324647	
i 1	403.75521768707483	0.2525	69	224	6	5	6	1	0	-1	1	0	0	5.900842882465954	
i 1	403.99076870748297	0.505	72	224	4	9	5	1	0	0	1	0	0	3.0178582347085725	
i 1	404.00602040816324	0.505	71	224	7	1	15	2	0	-1	2	0	0	11.177476464324647	
i 1	404.00923129251703	0.505	69	722	5	5	2	0	0	0	0	0	0	5.900842882465954	
i 1	404.24638775510203	0.505	71	224	5	24	10	8	0	-2	8	0	0	12.177476464324647	
i 1	404.25521768707483	0.2525	72	224	6	5	5	0	0	-1	0	0	0	5.900842882465954	
i 1	404.4891632653061	0.505	69	926	5	2	2	0	0	-1	0	0	0	4.017858234708573	
i 1	404.49397959183676	0.2525	72	926	6	5	8	1	0	-1	1	0	0	5.900842882465954	
i 1	404.49397959183676	0.2525	72	224	5	5	6	0	0	0	0	0	0	5.900842882465954	
i 1	404.5028095238095	0.2525	74	224	6	1	16	2	0	-2	2	0	0	11.177476464324647	
i 1	404.50521768707483	2.7775	71	722	4	24	5	2	0	-1	2	0	0	12.177476464324647	
i 1	404.7335442176871	0.505	72	224	3	3	5	1	0	-1	1	0	0	4.017858234708573	
i 1	404.75521768707483	0.505	72	224	6	5	12	0	0	-1	0	0	0	5.900842882465954	
i 1	404.76003401360543	0.2525	74	926	6	1	8	2	0	-1	2	0	0	11.177476464324647	
i 1	404.76404761904763	0.505	71	224	7	1	12	2	0	-1	2	0	0	11.177476464324647	
i 1	404.98113605442177	0.7575000000000001	69	224	4	9	14	1	0	-1	1	0	0	3.0178582347085725	
i 1	405.0116394557823	0.505	74	224	6	1	13	2	0	-2	2	0	0	11.177476464324647	
i 1	405.23274149659863	2.7775	69	926	5	2	5	0	0	-1	0	0	0	4.017858234708573	
i 1	405.23514965986396	0.2525	74	926	6	1	14	8	0	-2	8	0	0	11.177476464324647	
i 1	405.24237414965984	1.2625	69	722	6	5	11	0	0	0	0	0	0	5.900842882465954	
i 1	405.2656530612245	0.2525	71	722	1	24	15	2	0	-2	2	0	0	4.0	
i 1	405.26725850340137	0.2525	72	224	4	9	4	1	0	0	1	0	0	3.0178582347085725	
i 1	405.4803333333333	0.505	69	722	4	4	2	0	0	0	0	0	0	4.017858234708573	
i 1	405.48996598639457	0.2525	69	224	5	5	7	1	0	-1	1	0	0	5.900842882465954	
i 1	405.49076870748297	0.2525	74	926	6	1	11	2	0	-1	2	0	0	11.177476464324647	
i 1	405.5020068027211	0.2525	71	224	7	1	10	2	0	-1	2	0	0	11.177476464324647	
i 1	405.75441496598637	0.2525	72	224	5	4	6	1	0	-1	1	0	0	4.017858234708573	
i 1	405.98274149659863	0.505	69	224	4	9	3	1	0	-1	1	0	0	3.0178582347085725	
i 1	405.99076870748297	0.2525	69	224	5	5	4	0	0	-1	0	0	0	5.900842882465954	
i 1	405.99959863945577	0.2525	72	224	4	9	3	1	0	0	1	0	0	3.0178582347085725	
i 1	406.00521768707483	0.2525	72	224	6	5	14	0	0	-1	0	0	0	5.900842882465954	
i 1	406.23274149659863	0.505	71	224	5	24	9	8	0	-2	8	0	0	12.177476464324647	
i 1	406.24157142857143	0.2525	71	224	7	1	4	2	0	-1	2	0	0	11.177476464324647	
i 1	406.2616394557823	0.505	72	224	3	3	9	1	0	-1	1	0	0	4.017858234708573	
i 1	406.26404761904763	0.7575000000000001	72	224	5	5	14	0	0	0	0	0	0	5.900842882465954	
i 1	406.26806122448977	1.5150000000000001	69	722	6	5	12	0	0	0	0	0	0	5.900842882465954	
i 1	406.4931768707483	2.7775	74	926	6	1	10	2	0	-1	2	0	0	11.177476464324647	
i 1	406.49959863945577	0.2525	72	224	6	5	16	0	0	-1	0	0	0	5.900842882465954	
i 1	406.51244217687076	1.2625	69	722	4	3	7	1	0	0	1	0	0	4.017858234708573	
i 1	406.73514965986396	0.2525	69	224	5	5	14	1	0	-1	1	0	0	5.900842882465954	
i 1	406.76244217687076	0.2525	74	926	6	1	6	8	0	-2	8	0	0	11.177476464324647	
i 1	406.9843469387755	0.2525	71	224	5	24	14	8	0	-2	8	0	0	12.177476464324647	
i 1	407.01886394557823	0.7575000000000001	69	722	4	4	5	0	0	0	0	0	0	4.017858234708573	
i 1	407.24879591836736	0.505	69	224	5	5	1	1	0	-1	1	0	0	5.900842882465954	
i 1	407.2616394557823	0.2525	72	224	6	5	9	0	0	-1	0	0	0	5.900842882465954	
i 1	407.73193877551023	0.505	72	610	6	5	4	1	0	-1	1	0	0	5.900842882465954	
i 1	407.7528095238095	3.0300000000000002	60	610	4	7	11	5	0	1	5	0	0	1.3027655423538516	
i 1	407.75842857142857	3.0300000000000002	72	610	4	4	8	1	0	-1	1	0	0	4.017858234708573	
i 1	407.75923129251703	0.2525	69	610	6	5	3	1	0	0	1	0	0	5.900842882465954	
i 1	407.7608367346939	0.505	74	610	6	1	15	8	0	-1	8	0	0	11.177476464324647	
i 1	407.7616394557823	0.505	72	224	5	5	11	0	0	-1	0	0	0	5.900842882465954	
i 1	407.7664557823129	0.7575000000000001	69	610	5	3	7	0	0	0	0	0	0	4.017858234708573	
i 1	407.9971904761905	0.7575000000000001	71	224	7	1	1	2	0	-1	2	0	0	11.177476464324647	
i 1	407.99959863945577	0.2525	72	926	6	5	9	1	0	-1	1	0	0	5.900842882465954	
i 1	408.00521768707483	0.505	72	224	4	9	9	1	0	0	1	0	0	3.0178582347085725	
i 1	408.24879591836736	2.525	69	610	6	5	16	1	0	0	1	0	0	5.900842882465954	
i 1	408.26404761904763	2.525	74	610	4	24	2	2	0	-1	2	0	0	12.177476464324647	
i 1	408.26404761904763	0.505	72	224	5	5	10	0	0	0	0	0	0	5.900842882465954	
i 1	408.73113605442177	1.5150000000000001	69	610	5	3	13	0	0	0	0	0	0	4.017858234708573	
i 1	408.73193877551023	0.505	72	224	5	5	16	0	0	-1	0	0	0	5.900842882465954	
i 1	408.73755782312924	0.2525	74	610	6	1	10	8	0	-1	8	0	0	11.177476464324647	
i 1	408.74157142857143	0.2525	72	224	4	9	7	1	0	0	1	0	0	3.0178582347085725	
i 1	408.75842857142857	0.505	71	224	5	24	8	8	0	-2	8	0	0	12.177476464324647	
i 1	408.76404761904763	0.505	72	926	5	2	14	0	0	0	0	0	0	4.017858234708573	
i 1	409.00441496598637	0.7575000000000001	71	224	7	1	2	2	0	-1	2	0	0	11.177476464324647	
i 1	409.0196666666667	0.505	72	224	3	4	11	1	0	-1	1	0	0	4.017858234708573	
i 1	409.24959863945577	1.5150000000000001	74	610	6	1	14	8	0	-1	8	0	0	11.177476464324647	
i 1	409.25120408163264	0.505	74	224	6	1	16	2	0	-2	2	0	0	11.177476464324647	
i 1	409.25602040816324	0.2525	72	224	3	3	15	1	0	-1	1	0	0	4.017858234708573	
i 1	409.26404761904763	0.505	72	610	6	5	6	1	0	-1	1	0	0	5.900842882465954	
i 1	409.51003401360543	0.505	69	926	5	2	5	0	0	-1	0	0	0	4.017858234708573	
i 1	409.5108367346939	0.2525	72	224	4	9	9	1	0	0	1	0	0	3.0178582347085725	
i 1	409.75602040816324	1.01	72	926	6	5	4	1	0	-1	1	0	0	5.900842882465954	
i 1	409.76324489795917	0.505	74	926	6	1	12	2	0	-1	2	0	0	11.177476464324647	
i 1	409.7664557823129	0.2525	71	224	7	1	5	2	0	-1	2	0	0	11.177476464324647	
i 1	409.9803333333333	0.2525	74	224	6	1	3	2	0	-2	2	0	0	11.177476464324647	
i 1	410.24638775510203	0.505	72	926	5	2	4	0	0	0	0	0	0	4.017858234708573	
i 1	410.4803333333333	2.02	74	223	1	24	12	2	0	252	2	307	0	4.0	
i 1	410.7303333333333	2.525	69	610	5	3	3	0	0	0	0	0	0	4.017196818608255	
i 1	410.73595238095237	2.02	74	610	6	1	6	8	0	-1	8	0	0	8.838315102588476	
i 1	410.73675510204083	2.525	67	223	5	12	9	0	0	1	0	0	0	2.7613567006634407	
i 1	410.7383605442177	2.525	60	610	5	15	5	0	0	0	0	0	0	1.9653769895285376	
i 1	410.7383605442177	0.505	72	610	6	5	13	1	0	-1	1	0	0	4.032251993814951	
i 1	410.7391632653061	0.7575000000000001	72	223	4	5	12	1	0	0	1	0	0	4.032251993814951	
i 1	410.74076870748297	2.525	67	926	5	14	15	5	0	0	5	0	0	3.5573364117983446	
i 1	410.74478231292517	2.525	69	610	6	5	12	1	0	0	1	0	0	4.032251993814951	
i 1	410.74959863945577	0.7575000000000001	74	926	6	1	7	2	0	-1	2	0	0	8.838315102588476	
i 1	410.75441496598637	2.525	67	926	5	13	6	0	0	0	0	0	0	1.1693972783936342	
i 1	410.76003401360543	2.525	60	223	5	12	16	5	0	1	5	0	0	2.7613567006634407	
i 1	410.7608367346939	2.525	60	1192	4	16	13	5	0	1	5	0	0	2.7613567006634407	
i 1	410.76244217687076	1.01	74	1192	6	1	1	8	0	-1	8	0	0	8.838315102588476	
i 1	410.76324489795917	2.525	60	1192	4	16	13	5	0	1	5	0	0	2.7613567006634407	
i 1	410.76725850340137	2.525	60	610	5	15	16	0	0	0	0	0	0	1.9653769895285376	
i 1	410.76806122448977	1.01	72	610	4	4	7	1	0	-1	1	0	0	4.017196818608255	
i 1	410.99478231292517	0.2525	69	1192	4	9	10	1	0	0	1	0	0	3.017196818608255	
i 1	411.0020068027211	0.2525	74	926	6	1	1	8	0	-2	8	0	0	8.838315102588476	
i 1	411.0068231292517	0.505	69	223	3	3	6	1	0	-1	1	0	0	4.017196818608255	
i 1	411.2303333333333	2.02	72	926	6	5	1	1	0	-1	1	0	0	4.032251993814951	
i 1	411.23193877551023	1.7675	74	610	4	24	16	2	0	-1	2	0	0	9.838315102588476	
i 1	411.26806122448977	2.02	71	1192	1	24	12	2	0	-2	2	0	0	4.0	
i 1	411.49478231292517	0.2525	72	223	3	4	7	0	0	-1	0	0	0	4.017196818608255	
i 1	411.50361224489797	0.7575000000000001	74	223	6	1	1	8	0	-2	8	0	0	8.838315102588476	
i 1	411.51244217687076	1.7675	69	926	5	2	13	0	0	-1	0	0	0	4.017196818608255	
i 1	411.74076870748297	1.5150000000000001	74	926	6	1	9	2	0	-1	2	0	0	8.838315102588476	
i 1	411.74237414965984	0.505	72	926	6	5	5	1	0	-1	1	0	0	4.032251993814951	
i 1	411.76404761904763	0.505	72	1192	4	9	15	0	0	0	0	0	0	3.017196818608255	
i 1	411.7664557823129	0.2525	72	926	5	2	11	0	0	0	0	0	0	4.017196818608255	
i 1	411.9971904761905	0.505	69	1192	4	9	3	1	0	0	1	0	0	3.017196818608255	
i 1	412.25762585034016	0.2525	72	223	3	4	16	0	0	-1	0	0	0	4.017196818608255	
i 1	412.2616394557823	0.2525	71	1192	6	1	3	2	0	-2	2	0	0	8.838315102588476	
i 1	412.48595238095237	0.505	72	926	5	2	8	0	0	0	0	0	0	4.017196818608255	
i 1	412.49237414965984	0.2525	74	1192	6	1	9	8	0	-1	8	0	0	8.838315102588476	
i 1	412.49879591836736	0.2525	74	610	1	24	2	8	0	1	8	0	0	4.0	
i 1	412.50120408163264	0.2525	72	223	5	5	16	0	0	0	0	0	0	4.032251993814951	
i 1	412.51244217687076	0.7575000000000001	72	610	4	4	5	1	0	-1	1	0	0	4.017196818608255	
i 1	412.73514965986396	0.505	74	223	1	24	9	2	0	252	2	307	0	4.0	
i 1	412.74237414965984	0.505	74	926	6	1	5	8	0	-2	8	0	0	8.838315102588476	
i 1	412.98193877551023	0.2525	69	223	3	3	7	1	0	-1	1	0	0	4.017196818608255	
i 1	413.00923129251703	0.2525	72	926	6	5	8	1	0	-1	1	0	0	4.032251993814951	
i 1	413.0156530612245	0.2525	69	1192	6	5	1	1	0	0	1	0	0	4.032251993814951	
i 1	413.2303333333333	0.505	67	1093	4	16	7	5	0	0	5	0	0	2.7613567006634407	
i 1	413.23675510204083	3.7875	69	707	5	3	12	0	0	-1	0	0	0	4.017196818608255	
i 1	413.23755782312924	25.25	60	707	5	14	8	5	5000	1	5	0	0	3.5573364117983446	
i 1	413.24397959183676	18.18	60	707	5	15	5	0	0	1	0	0	0	1.9653769895285376	
i 1	413.24638775510203	3.2825	74	707	6	1	11	2	5000	-1	2	0	0	8.838315102588476	
i 1	413.2471904761905	2.02	74	391	1	24	14	2	0	252	2	307	0	4.0	
i 1	413.2520068027211	0.505	69	707	6	5	3	1	0	0	1	0	0	4.032251993814951	
i 1	413.25842857142857	0.2525	69	707	5	2	4	1	5000	0	1	0	0	4.017196818608255	
i 1	413.25842857142857	2.2725	72	707	4	4	15	0	0	0	0	0	0	4.017196818608255	
i 1	413.25923129251703	9.595	60	391	5	12	14	0	5000	1	0	0	0	2.7613567006634407	
i 1	413.25923129251703	3.0300000000000002	72	707	6	5	11	0	5000	0	0	0	0	4.032251993814951	
i 1	413.26003401360543	1.5150000000000001	71	707	6	1	11	8	5000	-2	8	0	0	8.838315102588476	
i 1	413.26003401360543	0.2525	69	1093	6	5	3	0	0	-1	0	0	0	4.032251993814951	
i 1	413.2608367346939	6.565	60	391	5	12	12	5	5000	0	5	0	0	2.7613567006634407	
i 1	413.2608367346939	0.2525	69	707	6	5	15	1	5000	-1	1	0	0	4.032251993814951	
i 1	413.26404761904763	25.25	67	707	5	13	9	0	5000	1	0	0	0	1.1693972783936342	
i 1	413.26404761904763	0.2525	72	391	3	3	13	1	5000	-1	1	0	0	4.017196818608255	
i 1	413.26485034013604	18.18	67	707	5	15	16	0	0	1	0	0	0	1.9653769895285376	
i 1	413.2664557823129	3.535	67	1093	4	16	9	5	0	1	5	0	0	2.7613567006634407	
i 1	413.7303333333333	0.7575000000000001	72	707	6	5	15	1	0	0	1	0	0	4.032251993814951	
i 1	413.73996598639457	0.2525	74	1093	6	1	1	8	0	-1	8	0	0	8.838315102588476	
i 1	413.76003401360543	6.565	67	1093	4	16	1	5	0	0	5	0	0	2.7613567006634407	
i 1	413.7664557823129	1.01	74	707	4	24	5	2	0	-2	2	0	0	9.838315102588476	
i 1	413.98113605442177	0.2525	69	707	5	2	1	0	5000	0	0	0	0	4.017196818608255	
i 1	413.98996598639457	0.505	69	707	6	5	8	1	0	0	1	0	0	4.032251993814951	
i 1	413.98996598639457	0.2525	69	1093	6	5	5	0	0	0	0	0	0	4.032251993814951	
i 1	413.99157142857143	0.505	72	391	3	4	15	0	5000	0	0	0	0	4.017196818608255	
i 1	414.01404761904763	0.505	74	391	6	1	16	2	5000	-2	2	0	0	8.838315102588476	
i 1	414.24638775510203	0.7575000000000001	72	1093	4	9	8	1	0	0	1	0	0	3.017196818608255	
i 1	414.2528095238095	0.7575000000000001	69	1093	6	5	4	0	0	-1	0	0	0	4.032251993814951	
i 1	414.48274149659863	0.505	69	707	6	5	8	1	5000	-1	1	0	0	4.032251993814951	
i 1	414.48595238095237	0.505	69	391	6	5	7	0	5000	-1	0	0	0	4.032251993814951	
i 1	414.49879591836736	0.2525	72	391	3	3	15	1	5000	-1	1	0	0	4.017196818608255	
i 1	414.5116394557823	0.7575000000000001	74	1093	6	1	8	8	0	-1	8	0	0	8.838315102588476	
i 1	414.73274149659863	1.5150000000000001	69	707	5	2	7	0	5000	0	0	0	0	4.017196818608255	
i 1	414.73755782312924	0.2525	71	391	4	24	11	8	5000	-2	8	0	0	9.838315102588476	
i 1	414.75923129251703	0.7575000000000001	74	707	6	1	9	2	0	-2	2	0	0	8.838315102588476	
i 1	414.98274149659863	0.2525	72	391	4	5	15	1	5000	0	1	0	0	4.032251993814951	
i 1	414.9843469387755	0.505	72	707	6	5	3	1	0	0	1	0	0	4.032251993814951	
i 1	414.9931768707483	5.3025	69	707	6	5	14	1	0	0	1	0	0	4.032251993814951	
i 1	415.00120408163264	0.2525	71	707	6	1	4	8	5000	-2	8	0	0	8.838315102588476	
i 1	415.01485034013604	0.2525	72	391	3	3	11	1	5000	-1	1	0	0	4.017196818608255	
i 1	415.23595238095237	3.0300000000000002	74	707	4	24	3	2	0	-2	2	0	0	9.838315102588476	
i 1	415.2471904761905	0.505	71	707	1	24	3	8	0	1	8	0	0	4.0	
i 1	415.25361224489797	0.505	72	391	3	4	11	0	5000	0	0	0	0	4.017196818608255	
i 1	415.25923129251703	0.7575000000000001	69	391	6	5	3	0	5000	-1	0	0	0	4.032251993814951	
i 1	415.4891632653061	0.2525	69	707	5	2	1	1	5000	0	1	0	0	4.017196818608255	
i 1	415.51003401360543	0.2525	69	707	6	5	9	1	5000	-1	1	0	0	4.032251993814951	
i 1	415.51324489795917	0.7575000000000001	74	1093	5	1	7	8	0	-1	8	0	0	8.838315102588476	
i 1	415.73996598639457	0.2525	74	707	6	1	1	2	0	-2	2	0	0	8.838315102588476	
i 1	415.74558503401363	0.2525	69	1093	6	5	15	0	0	0	0	0	0	4.032251993814951	
i 1	415.75842857142857	3.0300000000000002	72	707	4	4	10	0	0	0	0	0	0	4.017196818608255	
i 1	415.76806122448977	0.2525	72	1093	4	9	3	1	0	0	1	0	0	3.017196818608255	
i 1	415.9891632653061	1.2625	69	1093	6	5	5	0	0	-1	0	0	0	4.032251993814951	
i 1	416.23996598639457	3.0300000000000002	74	707	6	1	4	2	0	-2	2	0	0	8.838315102588476	
i 1	416.2431768707483	0.2525	72	391	3	4	13	0	5000	0	0	0	0	4.017196818608255	
i 1	416.26404761904763	0.2525	71	391	4	24	10	8	5000	-2	8	0	0	9.838315102588476	
i 1	416.26886394557823	0.2525	72	1093	3	9	16	0	0	-1	0	0	0	3.017196818608255	
i 1	416.48514965986396	0.2525	74	391	6	1	2	2	5000	-2	2	0	0	8.838315102588476	
i 1	416.49397959183676	0.505	69	707	5	2	11	1	5000	0	1	0	0	4.017196818608255	
i 1	416.50120408163264	0.2525	74	1093	6	1	7	8	0	-1	8	0	0	8.838315102588476	
i 1	416.50361224489797	0.2525	69	707	5	2	16	0	5000	0	0	0	0	4.017196818608255	
i 1	416.5196666666667	0.2525	69	391	6	5	9	0	5000	-1	0	0	0	4.032251993814951	
i 1	416.7391632653061	0.505	74	1093	5	1	1	8	0	-1	8	0	0	8.838315102588476	
i 1	416.7528095238095	0.2525	72	391	3	4	16	0	5000	0	0	0	0	4.017196818608255	
i 1	416.75762585034016	4.7975	72	707	4	5	2	0	5000	0	0	0	0	4.032251993814951	
i 1	416.76003401360543	3.535	67	1093	4	16	13	5	0	1	5	0	0	2.7613567006634407	
i 1	416.98113605442177	0.7575000000000001	72	391	3	3	11	1	5000	-1	1	0	0	4.017196818608255	
i 1	417.00842857142857	0.2525	72	391	6	5	12	1	5000	0	1	0	0	4.032251993814951	
i 1	417.01725850340137	0.505	72	1093	4	9	12	1	0	0	1	0	0	3.017196818608255	
i 1	417.01886394557823	0.505	72	1093	4	9	9	0	0	-1	0	0	0	3.017196818608255	
i 1	417.23193877551023	0.505	71	707	6	1	1	8	5000	-2	8	0	0	8.838315102588476	
i 1	417.23193877551023	0.2525	69	1093	6	5	10	0	0	0	0	0	0	4.032251993814951	
i 1	417.26806122448977	0.2525	72	707	6	5	5	1	0	0	1	0	0	4.032251993814951	
i 1	417.49076870748297	0.505	69	1093	6	5	4	0	0	-1	0	0	0	4.032251993814951	
i 1	417.4931768707483	2.7775	69	707	5	2	6	1	5000	0	1	0	0	4.017196818608255	
i 1	417.50842857142857	1.01	69	707	5	3	11	0	0	-1	0	0	0	4.017196818608255	
i 1	417.73274149659863	0.505	72	391	3	4	8	0	5000	0	0	0	0	4.017196818608255	
i 1	417.74638775510203	2.7775	74	707	6	1	16	2	5000	-1	2	0	0	8.838315102588476	
i 1	417.7479931972789	0.2525	74	1093	5	1	4	8	0	-1	8	0	0	8.838315102588476	
i 1	417.98274149659863	0.505	74	391	6	1	14	2	5000	-2	2	0	0	8.838315102588476	
i 1	418.0164557823129	0.7575000000000001	69	1093	6	5	9	0	0	0	0	0	0	4.032251993814951	
i 1	418.23755782312924	0.2525	72	1093	4	9	11	1	0	0	1	0	0	3.017196818608255	
i 1	418.25120408163264	0.7575000000000001	71	391	4	24	16	8	5000	-2	8	0	0	9.838315102588476	
i 1	418.48595238095237	0.2525	72	391	3	4	8	0	5000	0	0	0	0	4.017196818608255	
i 1	418.49237414965984	0.2525	74	707	4	24	16	2	0	-2	2	0	0	9.838315102588476	
i 1	418.7528095238095	0.2525	74	1093	5	1	10	8	0	-1	8	0	0	8.838315102588476	
i 1	418.76003401360543	3.0300000000000002	69	707	5	3	11	0	0	-1	0	0	0	4.017196818608255	
i 1	418.9803333333333	0.505	72	707	4	4	14	0	0	0	0	0	0	4.017196818608255	
i 1	419.00842857142857	0.2525	72	1093	4	9	7	1	0	0	1	0	0	3.017196818608255	
i 1	419.01324489795917	1.01	74	1093	5	1	12	8	0	-1	8	0	0	8.838315102588476	
i 1	419.01886394557823	0.505	71	707	6	1	1	8	5000	-2	8	0	0	8.838315102588476	
i 1	419.24959863945577	0.2525	74	1093	5	1	1	8	0	-1	8	0	0	8.838315102588476	
i 1	419.25923129251703	0.505	69	707	6	5	12	1	5000	-1	1	0	0	4.032251993814951	
i 1	419.48193877551023	0.2525	74	391	6	1	9	2	5000	-2	2	0	0	8.838315102588476	
i 1	419.49558503401363	0.2525	72	391	3	4	13	0	5000	0	0	0	0	4.017196818608255	
i 1	419.5156530612245	2.7775	74	707	6	1	11	2	0	-2	2	0	0	8.838315102588476	
i 1	419.5156530612245	0.2525	72	1093	4	9	13	1	0	0	1	0	0	3.017196818608255	
i 1	419.7303333333333	18.685	60	391	4	12	4	5	5000	0	5	0	0	2.7613567006634407	
i 1	419.73595238095237	7.07	72	707	4	4	16	0	0	0	0	0	0	4.017196818608255	
i 1	419.74478231292517	0.2525	69	391	6	5	5	0	5000	-1	0	0	0	4.032251993814951	
i 1	419.75120408163264	0.505	69	1093	6	5	1	0	0	-1	0	0	0	4.032251993814951	
i 1	419.99237414965984	1.2625	72	391	6	5	12	1	5000	0	1	0	0	4.032251993814951	
i 1	420.00441496598637	0.2525	74	1093	5	1	14	8	0	-1	8	0	0	8.838315102588476	
i 1	420.00923129251703	0.2525	72	391	4	3	7	1	5000	-1	1	0	0	4.017196818608255	
i 1	420.01725850340137	0.505	71	391	4	24	3	8	5000	-2	8	0	0	9.838315102588476	
i 1	420.23113605442177	0.505	72	889	4	9	10	0	0	0	0	0	0	3.017196818608255	
i 1	420.24397959183676	5.555	71	889	1	24	16	2	0	248	2	308	0	4.0	
i 1	420.2479931972789	0.2525	69	707	4	5	16	1	5000	-1	1	0	0	4.032251993814951	
i 1	420.2520068027211	5.555	60	889	4	16	8	0	0	0	0	0	0	2.7613567006634407	
i 1	420.26244217687076	5.555	60	889	4	16	15	5	0	0	5	0	0	2.7613567006634407	
i 1	420.48193877551023	0.505	72	391	4	3	14	1	5000	-1	1	0	0	4.017196818608255	
i 1	420.4835442176871	2.7775	71	707	6	1	14	8	5000	-2	8	0	0	8.838315102588476	
i 1	420.48675510204083	0.2525	71	889	5	1	1	8	0	-2	8	0	0	8.838315102588476	
i 1	420.4971904761905	0.2525	72	889	6	5	9	0	0	0	0	0	0	4.032251993814951	
i 1	420.51725850340137	0.2525	69	391	6	5	16	0	5000	-1	0	0	0	4.032251993814951	
i 1	420.74076870748297	0.2525	74	889	5	1	13	2	0	-2	2	0	0	8.838315102588476	
i 1	420.74157142857143	0.505	69	889	4	9	4	0	0	0	0	0	0	3.017196818608255	
i 1	420.74879591836736	0.2525	74	391	5	1	16	2	5000	-2	2	0	0	8.838315102588476	
i 1	420.7568231292517	1.7675	72	707	6	5	5	1	0	0	1	0	0	4.032251993814951	
i 1	421.01003401360543	0.2525	72	889	6	5	10	0	0	-1	0	0	0	4.032251993814951	
i 1	421.0156530612245	1.2625	71	391	4	24	7	8	5000	-2	8	0	0	9.838315102588476	
i 1	421.0196666666667	0.2525	72	889	4	9	16	0	0	0	0	0	0	3.017196818608255	
i 1	421.23675510204083	0.2525	69	707	5	2	3	0	5000	0	0	0	0	4.017196818608255	
i 1	421.24879591836736	0.2525	69	707	4	5	4	1	5000	-1	1	0	0	4.032251993814951	
i 1	421.25842857142857	0.7575000000000001	72	391	3	4	7	0	5000	0	0	0	0	4.017196818608255	
i 1	421.4803333333333	0.2525	74	707	6	1	5	2	5000	-1	2	0	0	8.838315102588476	
i 1	421.4835442176871	0.2525	72	889	6	5	9	0	0	0	0	0	0	4.032251993814951	
i 1	421.50040136054423	0.505	69	707	6	5	3	1	0	0	1	0	0	4.032251993814951	
i 1	421.50521768707483	0.505	69	707	5	2	6	1	5000	0	1	0	0	4.017196818608255	
i 1	421.51485034013604	0.505	72	391	6	5	12	1	5000	0	1	0	0	4.032251993814951	
i 1	421.73996598639457	1.2625	72	889	4	9	13	0	0	0	0	0	0	3.017196818608255	
i 1	421.74076870748297	2.2725	72	707	4	5	2	0	5000	0	0	0	0	4.032251993814951	
i 1	421.74157142857143	0.2525	74	707	4	24	4	2	0	-2	2	0	0	9.838315102588476	
i 1	421.9843469387755	0.2525	69	889	4	9	10	0	0	0	0	0	0	3.017196818608255	
i 1	421.98675510204083	0.2525	72	889	6	5	12	0	0	-1	0	0	0	4.032251993814951	
i 1	422.23193877551023	0.2525	69	707	5	2	4	0	5000	0	0	0	0	4.017196818608255	
i 1	422.23675510204083	0.2525	69	391	6	5	8	0	5000	-1	0	0	0	4.032251993814951	
i 1	422.25040136054423	0.2525	69	707	5	3	16	0	0	-1	0	0	0	4.017196818608255	
i 1	422.25923129251703	1.2625	74	707	6	1	7	2	5000	-1	2	0	0	8.838315102588476	
i 1	422.48755782312924	0.2525	71	391	4	24	14	8	5000	-2	8	0	0	9.838315102588476	
i 1	422.5020068027211	0.2525	72	391	4	3	4	1	5000	-1	1	0	0	4.017196818608255	
i 1	422.7383605442177	15.655	60	391	4	12	4	0	5000	1	0	0	0	2.7613567006634407	
i 1	422.7391632653061	0.7575000000000001	69	707	5	3	8	0	0	-1	0	0	0	4.017196818608255	
i 1	422.75923129251703	1.7675	74	707	6	1	8	2	0	-2	2	0	0	8.838315102588476	
i 1	422.76806122448977	1.01	74	707	4	24	6	2	0	-2	2	0	0	9.838315102588476	
i 1	422.76806122448977	0.505	69	707	4	5	2	1	5000	-1	1	0	0	4.032251993814951	
i 1	422.76886394557823	0.505	69	707	4	5	11	1	0	0	1	0	0	4.032251993814951	
i 1	422.9891632653061	0.7575000000000001	69	889	4	9	6	0	0	0	0	0	0	3.017196818608255	
i 1	423.23193877551023	0.2525	72	391	6	5	12	1	5000	0	1	0	0	4.032251993814951	
i 1	423.26485034013604	0.505	72	889	6	5	6	0	0	0	0	0	0	4.032251993814951	
i 1	423.2656530612245	0.2525	74	391	5	1	8	2	5000	-2	2	0	0	8.838315102588476	
i 1	423.49879591836736	0.2525	71	707	6	1	8	8	5000	-2	8	0	0	8.838315102588476	
i 1	423.5108367346939	2.7775	69	707	4	5	8	1	0	0	1	0	0	4.032251993814951	
i 1	423.51324489795917	0.2525	72	391	4	4	4	0	5000	0	0	0	0	4.017196818608255	
i 1	423.73755782312924	1.2625	69	707	5	3	3	0	0	-1	0	0	0	4.017196818608255	
i 1	423.7528095238095	0.2525	72	707	6	5	1	1	0	0	1	0	0	4.032251993814951	
i 1	423.7616394557823	0.2525	69	707	5	2	8	0	5000	0	0	0	0	4.017196818608255	
i 1	423.98755782312924	1.5150000000000001	74	707	4	24	4	2	0	-2	2	0	0	9.838315102588476	
i 1	423.98996598639457	0.2525	69	391	6	5	2	0	5000	-1	0	0	0	4.032251993814951	
i 1	423.99076870748297	0.2525	71	889	5	1	15	8	0	-2	8	0	0	8.838315102588476	
i 1	424.00842857142857	0.505	72	889	6	5	2	0	0	-1	0	0	0	4.032251993814951	
i 1	424.00923129251703	0.2525	71	391	4	24	4	8	5000	-2	8	0	0	9.838315102588476	
i 1	424.0116394557823	0.2525	69	707	6	2	16	1	5000	0	1	0	0	4.017196818608255	
i 1	424.01485034013604	0.2525	72	391	6	5	8	1	5000	0	1	0	0	4.032251993814951	
i 1	424.23595238095237	0.505	69	707	5	2	9	0	5000	0	0	0	0	4.017196818608255	
i 1	424.4835442176871	0.505	71	889	5	1	11	8	0	-2	8	0	0	8.838315102588476	
i 1	424.4979931972789	0.505	69	391	6	5	15	0	5000	-1	0	0	0	4.032251993814951	
i 1	424.5108367346939	0.2525	71	707	6	1	2	8	5000	-2	8	0	0	8.838315102588476	
i 1	424.7471904761905	0.2525	69	889	4	9	10	0	0	0	0	0	0	3.017196818608255	
i 1	424.75361224489797	0.2525	74	707	6	1	1	2	5000	-1	2	0	0	8.838315102588476	
i 1	424.98193877551023	0.2525	74	889	5	1	8	2	0	-2	2	0	0	8.838315102588476	
i 1	424.98595238095237	0.2525	72	889	4	9	14	0	0	0	0	0	0	3.017196818608255	
i 1	424.9971904761905	2.2725	74	707	6	1	11	2	0	-2	2	0	0	8.838315102588476	
i 1	425.00441496598637	0.2525	69	707	5	2	2	0	5000	0	0	0	0	4.017196818608255	
i 1	425.23113605442177	0.505	71	707	6	1	5	8	5000	-2	8	0	0	8.838315102588476	
i 1	425.24879591836736	2.2725	72	707	4	5	6	0	5000	0	0	0	0	4.032251993814951	
i 1	425.7335442176871	5.555	67	1093	4	16	14	5	0	0	5	0	0	2.7613567006634407	
i 1	425.73996598639457	3.0300000000000002	69	707	5	3	8	0	0	-1	0	0	0	4.017196818608255	
i 1	425.7471904761905	0.2525	74	707	4	24	9	2	0	-2	2	0	0	9.838315102588476	
i 1	425.74879591836736	0.2525	72	707	4	5	1	1	0	0	1	0	0	4.032251993814951	
i 1	425.75521768707483	0.2525	74	707	6	1	10	2	5000	-1	2	0	0	8.838315102588476	
i 1	425.76244217687076	0.505	69	391	6	5	11	0	5000	-1	0	0	0	4.032251993814951	
i 1	425.7664557823129	5.555	67	1093	4	16	14	0	0	1	0	0	0	2.7613567006634407	
i 1	425.99879591836736	0.2525	74	1093	5	1	6	2	0	-2	2	0	0	8.838315102588476	
i 1	426.01404761904763	0.505	71	1093	5	1	3	8	0	-1	8	0	0	8.838315102588476	
i 1	426.23113605442177	0.2525	72	1093	6	5	13	1	0	0	1	0	0	4.032251993814951	
i 1	426.2528095238095	0.2525	69	707	4	5	13	1	5000	-1	1	0	0	4.032251993814951	
i 1	426.49237414965984	0.505	69	1093	6	5	16	0	0	0	0	0	0	4.032251993814951	
i 1	426.49959863945577	0.2525	72	391	6	5	6	1	5000	0	1	0	0	4.032251993814951	
i 1	426.51404761904763	3.535	74	707	6	1	11	2	5000	-1	2	0	0	8.838315102588476	
i 1	426.74237414965984	0.2525	74	1093	5	1	1	2	0	-2	2	0	0	8.838315102588476	
i 1	426.98514965986396	0.505	71	391	4	24	12	8	5000	-2	8	0	0	9.838315102588476	
i 1	426.9931768707483	0.505	72	707	4	4	3	0	0	0	0	0	0	4.017196818608255	
i 1	427.0028095238095	1.5150000000000001	69	707	4	5	2	1	0	0	1	0	0	4.032251993814951	
i 1	427.2383605442177	0.2525	74	1093	5	1	10	2	0	-2	2	0	0	8.838315102588476	
i 1	427.48113605442177	1.5150000000000001	69	707	5	2	4	1	5000	0	1	0	0	4.017196818608255	
i 1	427.48193877551023	0.2525	74	391	5	1	9	2	5000	-2	2	0	0	8.838315102588476	
i 1	427.50602040816324	0.2525	71	1093	5	1	14	8	0	-1	8	0	0	8.838315102588476	
i 1	427.74879591836736	1.01	74	391	1	24	3	2	0	248	2	308	0	4.0	
i 1	427.76324489795917	3.7875	72	707	4	5	14	0	5000	0	0	0	0	4.032251993814951	
i 1	427.76886394557823	0.2525	72	1093	6	5	16	1	0	0	1	0	0	4.032251993814951	
i 1	428.0020068027211	0.2525	69	707	6	2	10	0	5000	0	0	0	0	4.017196818608255	
i 1	428.00441496598637	0.2525	74	391	5	1	3	2	5000	-2	2	0	0	8.838315102588476	
i 1	428.00842857142857	0.7575000000000001	74	707	6	1	11	2	0	-2	2	0	0	8.838315102588476	
i 1	428.24076870748297	0.7575000000000001	71	707	6	1	4	8	5000	-2	8	0	0	8.838315102588476	
i 1	428.25120408163264	3.0300000000000002	72	707	4	4	12	0	0	0	0	0	0	4.017196818608255	
i 1	428.25361224489797	0.505	69	707	4	5	16	1	5000	-1	1	0	0	4.032251993814951	
i 1	428.50842857142857	0.2525	72	707	4	5	15	1	0	0	1	0	0	4.032251993814951	
i 1	428.73595238095237	0.2525	72	391	6	5	11	1	5000	0	1	0	0	4.032251993814951	
i 1	428.73755782312924	1.01	69	707	5	3	4	0	0	-1	0	0	0	4.017196818608255	
i 1	428.74638775510203	0.2525	72	1093	6	5	10	1	0	0	1	0	0	4.032251993814951	
i 1	428.7528095238095	0.2525	71	391	4	24	11	8	5000	-2	8	0	0	9.838315102588476	
i 1	428.7528095238095	0.2525	74	391	2	24	2	2	0	1	2	0	0	4.0	
i 1	428.9891632653061	0.2525	74	1093	5	1	12	2	0	-2	2	0	0	8.838315102588476	
i 1	429.00040136054423	0.2525	69	707	4	5	5	1	5000	-1	1	0	0	4.032251993814951	
i 1	429.00923129251703	0.2525	69	391	6	5	12	0	5000	-1	0	0	0	4.032251993814951	
i 1	429.01324489795917	0.2525	72	391	4	3	11	1	5000	-1	1	0	0	4.017196818608255	
i 1	429.01886394557823	0.2525	71	1093	5	1	7	8	0	-1	8	0	0	8.838315102588476	
i 1	429.23113605442177	0.505	72	391	4	4	10	0	5000	0	0	0	0	4.017196818608255	
i 1	429.23755782312924	0.505	72	391	6	5	2	1	5000	0	1	0	0	4.032251993814951	
i 1	429.26244217687076	1.7675	74	707	4	24	1	2	0	-2	2	0	0	9.838315102588476	
i 1	429.26886394557823	0.2525	71	707	6	1	11	8	5000	-2	8	0	0	8.838315102588476	
i 1	429.51404761904763	0.7575000000000001	72	707	4	5	9	1	0	0	1	0	0	4.032251993814951	
i 1	429.51725850340137	0.505	74	707	6	1	13	2	0	-2	2	0	0	8.838315102588476	
i 1	429.7471904761905	0.7575000000000001	69	1093	4	9	4	1	0	-1	1	0	0	3.017196818608255	
i 1	429.76244217687076	0.2525	69	1093	4	9	11	0	0	0	0	0	0	3.017196818608255	
i 1	429.7664557823129	0.505	72	1093	6	5	5	1	0	0	1	0	0	4.032251993814951	
i 1	430.0028095238095	0.2525	69	707	5	2	3	0	5000	0	0	0	0	4.017196818608255	
i 1	430.0068231292517	0.2525	71	1093	5	1	13	8	0	-1	8	0	0	8.838315102588476	
i 1	430.0156530612245	0.2525	71	391	4	24	6	8	5000	-2	8	0	0	9.838315102588476	
i 1	430.24478231292517	0.2525	71	707	6	1	4	8	5000	-2	8	0	0	8.838315102588476	
i 1	430.25521768707483	0.2525	72	391	6	5	15	1	5000	0	1	0	0	4.032251993814951	
i 1	430.25842857142857	0.2525	74	391	5	1	11	2	5000	-2	2	0	0	8.838315102588476	
i 1	430.2616394557823	0.2525	69	1093	3	5	15	0	0	0	0	0	0	4.032251993814951	
i 1	430.48113605442177	0.7575000000000001	74	707	6	1	3	2	0	-2	2	0	0	8.838315102588476	
i 1	430.4843469387755	0.505	71	391	4	24	1	8	5000	-2	8	0	0	9.838315102588476	
i 1	430.4971904761905	0.505	72	1093	6	5	16	1	0	0	1	0	0	4.032251993814951	
i 1	430.51244217687076	0.7575000000000001	74	1093	2	24	9	2	0	-2	2	0	0	4.0	
i 1	430.51806122448977	0.2525	69	391	6	5	4	0	5000	-1	0	0	0	4.032251993814951	
i 1	430.51806122448977	0.2525	74	707	3	24	16	2	0	-2	2	0	0	4.0	
i 1	430.75040136054423	0.7575000000000001	74	391	2	24	11	2	0	1	2	0	0	4.0	
i 1	430.99638775510203	0.2525	69	707	4	5	1	1	0	0	1	0	0	4.032251993814951	
i 1	431.00762585034016	0.2525	74	391	5	1	11	2	5000	-2	2	0	0	8.838315102588476	
i 1	431.01003401360543	0.2525	71	707	6	1	11	8	5000	-2	8	0	0	8.838315102588476	
i 1	431.0196666666667	0.2525	72	707	4	5	9	1	0	0	1	0	0	4.032251993814951	
i 1	431.2303333333333	2.02	71	58	3	24	10	2	5004	1	2	0	0	4.0	
i 1	431.23193877551023	2.525	71	556	6	1	3	8	0	-1	8	0	0	8.838315102588476	
i 1	431.23675510204083	7.07	67	58	5	16	4	0	5004	0	0	0	0	2.7613567006634407	
i 1	431.24076870748297	0.505	69	556	4	4	3	0	0	0	0	0	0	4.017196818608255	
i 1	431.24237414965984	0.505	72	556	5	3	5	0	0	-1	0	0	0	4.017196818608255	
i 1	431.2431768707483	4.2925	60	556	5	15	8	0	0	1	0	0	0	1.9653769895285376	
i 1	431.24638775510203	0.2525	71	391	4	24	4	8	5000	-2	8	0	0	9.838315102588476	
i 1	431.2471904761905	7.07	60	58	5	16	5	5	5004	1	5	0	0	2.7613567006634407	
i 1	431.24959863945577	1.7675	69	556	4	5	8	0	0	-1	0	0	0	4.032251993814951	
i 1	431.25120408163264	0.7575000000000001	72	556	4	5	11	1	0	-1	1	0	0	4.032251993814951	
i 1	431.2616394557823	4.2925	67	556	5	15	3	0	0	0	0	0	0	1.9653769895285376	
i 1	431.2656530612245	0.2525	71	58	6	1	14	2	5004	-2	2	0	0	8.838315102588476	
i 1	431.49076870748297	0.2525	69	58	7	5	16	0	5004	-1	0	0	0	4.032251993814951	
i 1	431.5028095238095	0.2525	69	707	5	2	12	0	5000	0	0	0	0	4.017196818608255	
i 1	431.73274149659863	0.7575000000000001	69	391	6	5	14	0	5000	-1	0	0	0	4.032251993814951	
i 1	431.7391632653061	0.7575000000000001	71	556	4	24	7	2	0	-2	2	0	0	9.838315102588476	
i 1	431.74558503401363	0.505	72	391	4	4	14	0	5000	0	0	0	0	4.017196818608255	
i 1	431.75842857142857	1.2625	72	556	5	3	6	0	0	-1	0	0	0	4.017196818608255	
i 1	431.7608367346939	0.7575000000000001	69	707	5	2	9	1	5000	0	1	0	0	4.017196818608255	
i 1	431.99397959183676	0.2525	74	391	2	24	12	2	0	1	2	0	0	4.0	
i 1	431.99558503401363	0.2525	72	58	4	5	14	0	5004	-1	0	0	0	4.032251993814951	
i 1	432.2303333333333	0.2525	69	707	4	5	16	1	5000	-1	1	0	0	4.032251993814951	
i 1	432.24558503401363	2.525	69	556	4	4	16	0	0	0	0	0	0	4.017196818608255	
i 1	432.48193877551023	0.505	72	58	4	5	11	0	5004	-1	0	0	0	4.032251993814951	
i 1	432.4843469387755	0.7575000000000001	74	707	6	1	16	2	5000	-1	2	0	0	8.838315102588476	
i 1	432.48514965986396	0.2525	69	58	5	9	5	1	5004	-1	1	0	0	3.017196818608255	
i 1	432.51324489795917	0.2525	74	58	6	1	10	2	5004	-1	2	0	0	8.838315102588476	
i 1	432.51806122448977	1.5150000000000001	72	707	4	5	3	0	5000	0	0	0	0	4.032251993814951	
i 1	432.73755782312924	1.7675	71	707	6	1	8	8	5000	-2	8	0	0	8.838315102588476	
i 1	432.74157142857143	0.2525	69	707	5	2	7	0	5000	0	0	0	0	4.017196818608255	
i 1	433.00521768707483	0.505	69	707	4	5	3	1	5000	-1	1	0	0	4.032251993814951	
i 1	433.0068231292517	0.7575000000000001	69	58	4	5	16	0	5004	-1	0	0	0	4.032251993814951	
i 1	433.01485034013604	0.7575000000000001	72	391	4	4	12	0	5000	0	0	0	0	4.017196818608255	
i 1	433.24237414965984	1.01	71	58	1	24	15	2	5004	252	2	307	0	4.0	
i 1	433.2568231292517	0.2525	74	391	5	1	16	2	5000	-2	2	0	0	8.838315102588476	
i 1	433.4979931972789	2.02	69	556	4	5	14	0	0	-1	0	0	0	4.032251993814951	
i 1	433.50441496598637	2.02	74	707	6	1	15	2	5000	-1	2	0	0	8.838315102588476	
i 1	433.73274149659863	1.01	72	556	5	3	1	0	0	-1	0	0	0	4.017196818608255	
i 1	433.7520068027211	0.2525	71	391	4	24	8	8	5000	-2	8	0	0	9.838315102588476	
i 1	433.7528095238095	0.7575000000000001	72	556	4	5	13	1	0	-1	1	0	0	4.032251993814951	
i 1	433.75361224489797	0.2525	69	58	5	9	7	0	5004	-1	0	0	0	3.017196818608255	
i 1	433.9843469387755	1.7675	69	707	5	2	4	1	5000	0	1	0	0	4.017196818608255	
i 1	434.0028095238095	0.2525	74	58	6	1	2	2	5004	-1	2	0	0	8.838315102588476	
i 1	434.00521768707483	0.2525	69	707	4	5	1	1	5000	-1	1	0	0	4.032251993814951	
i 1	434.26404761904763	0.505	71	58	3	24	11	2	5004	1	2	0	0	4.0	
i 1	434.26485034013604	0.2525	69	58	4	5	13	0	5004	-1	0	0	0	4.032251993814951	
i 1	434.49558503401363	0.505	74	58	6	1	2	2	5004	-1	2	0	0	8.838315102588476	
i 1	434.51485034013604	0.2525	71	391	4	24	8	8	5000	-2	8	0	0	9.838315102588476	
i 1	434.74157142857143	0.7575000000000001	72	391	4	4	8	0	5000	0	0	0	0	4.017196818608255	
i 1	434.74959863945577	0.2525	69	58	4	5	2	0	5004	-1	0	0	0	4.032251993814951	
i 1	434.76324489795917	0.7575000000000001	71	556	6	1	4	8	0	-1	8	0	0	8.838315102588476	
i 1	434.76404761904763	0.7575000000000001	72	556	4	5	10	1	0	-1	1	0	0	4.032251993814951	
i 1	434.76806122448977	0.2525	69	556	4	4	8	0	0	0	0	0	0	4.017196818608255	
i 1	434.76806122448977	0.7575000000000001	74	391	2	24	3	8	5000	-2	8	0	0	4.0	
i 1	434.9803333333333	0.505	71	556	4	24	10	2	0	-2	2	0	0	9.838315102588476	
i 1	434.9835442176871	0.7575000000000001	72	707	6	5	1	0	5000	0	0	0	0	4.032251993814951	
i 1	435.01244217687076	0.7575000000000001	71	58	3	24	3	2	5004	1	2	0	0	4.0	
i 1	435.0164557823129	0.2525	72	556	5	3	13	0	0	-1	0	0	0	4.017196818608255	
i 1	435.01806122448977	0.2525	74	391	2	24	12	2	0	-2	2	0	0	4.0	
i 1	435.2568231292517	0.2525	71	556	3	24	16	0	0	-1	0	0	0	4.0	
i 1	435.48193877551023	2.7775	77	399	6	1	5	17	0	2	17	0	0	8.838315102588476	
i 1	435.48193877551023	0.2525	68	391	2	24	8	0	0	-1	0	0	0	4.0	
i 1	435.48675510204083	2.7775	61	399	5	15	13	9	0	1	9	0	0	1.9653769895285376	
i 1	435.5020068027211	2.02	71	399	4	4	5	8	0	-2	8	0	0	4.017196818608255	
i 1	435.50762585034016	1.2625	72	399	4	5	14	2	0	1	2	0	0	4.032251993814951	
i 1	435.51003401360543	0.2525	72	399	4	5	14	2	0	1	2	0	0	4.032251993814951	
i 1	435.5116394557823	0.2525	71	707	6	1	9	8	5000	-2	8	0	0	8.838315102588476	
i 1	435.51404761904763	0.2525	74	399	4	24	9	16	0	2	16	0	0	9.838315102588476	
i 1	435.51886394557823	2.7775	61	399	5	15	14	6	0	0	6	0	0	1.9653769895285376	
i 1	435.74478231292517	0.2525	69	391	3	5	13	0	5000	-1	0	0	0	4.032251993814951	
i 1	435.75441496598637	0.2525	71	58	6	1	5	2	5004	-2	2	0	0	8.838315102588476	
i 1	435.7608367346939	1.5150000000000001	69	58	5	9	16	1	5004	-1	1	0	0	3.017196818608255	
i 1	435.76485034013604	0.2525	72	58	4	5	14	0	5004	-1	0	0	0	4.032251993814951	
i 1	435.76725850340137	0.2525	71	391	4	24	4	8	5000	-2	8	0	0	9.838315102588476	
i 1	435.9803333333333	1.5150000000000001	74	391	2	24	1	8	5000	-2	8	0	0	4.0	
i 1	435.98274149659863	0.2525	69	58	4	5	16	0	5004	-1	0	0	0	4.032251993814951	
i 1	436.00120408163264	0.2525	74	707	6	1	8	2	5000	-1	2	0	0	8.838315102588476	
i 1	436.00521768707483	0.505	71	707	6	1	14	8	5000	-2	8	0	0	8.838315102588476	
i 1	436.0164557823129	0.505	69	707	4	5	1	1	5000	-1	1	0	0	4.032251993814951	
i 1	436.2303333333333	0.505	74	391	5	1	8	2	5000	-2	2	0	0	8.838315102588476	
i 1	436.2471904761905	1.5150000000000001	72	707	6	5	12	0	5000	0	0	0	0	4.032251993814951	
i 1	436.2608367346939	0.2525	69	58	6	9	8	0	5004	-1	0	0	0	3.017196818608255	
i 1	436.49478231292517	1.2625	74	707	6	1	1	2	5000	-1	2	0	0	8.838315102588476	
i 1	436.49478231292517	0.2525	69	58	4	5	15	0	5004	-1	0	0	0	4.032251993814951	
i 1	436.50361224489797	0.505	69	707	5	2	14	0	5000	0	0	0	0	4.017196818608255	
i 1	436.7335442176871	1.5150000000000001	71	58	3	24	16	2	5004	1	2	0	0	4.0	
i 1	436.7343469387755	1.5150000000000001	72	399	4	5	14	2	0	1	2	0	0	4.032251993814951	
i 1	436.7391632653061	0.2525	74	58	6	1	9	2	5004	-1	2	0	0	8.838315102588476	
i 1	436.75040136054423	0.2525	72	58	4	5	4	0	5004	-1	0	0	0	4.032251993814951	
i 1	436.99157142857143	0.2525	71	391	2	24	9	0	0	-1	0	0	0	4.0	
i 1	437.0028095238095	0.2525	71	58	6	1	15	2	5004	-2	2	0	0	8.838315102588476	
i 1	437.00521768707483	1.2625	69	707	5	2	11	1	5000	0	1	0	0	4.017196818608255	
i 1	437.01886394557823	0.2525	72	399	4	5	1	2	0	1	2	0	0	4.032251993814951	
i 1	437.2520068027211	0.505	71	399	3	24	6	1	0	-1	1	0	0	4.0	
i 1	437.25762585034016	0.2525	71	399	5	3	11	8	0	-2	8	0	0	4.017196818608255	
i 1	437.48595238095237	0.2525	74	391	5	1	4	2	5000	-2	2	0	0	8.838315102588476	
i 1	437.4931768707483	0.505	69	707	5	2	9	0	5000	0	0	0	0	4.017196818608255	
i 1	437.50441496598637	0.2525	69	58	6	9	2	0	5004	-1	0	0	0	3.017196818608255	
i 1	437.51806122448977	0.2525	69	391	3	5	14	0	5000	-1	0	0	0	4.032251993814951	
i 1	437.7303333333333	0.505	72	58	4	5	11	0	5004	-1	0	0	0	4.032251993814951	
i 1	437.73514965986396	0.2525	72	391	3	5	5	1	5000	0	1	0	0	4.032251993814951	
i 1	437.73675510204083	0.2525	74	399	4	24	1	16	0	2	16	0	0	9.838315102588476	
i 1	438.23274149659863	17.675	61	589	5	15	5	6	0	0	6	0	0	1.9653769895285376	
i 1	438.23514965986396	17.675	61	203	5	16	7	9	0	0	9	0	0	2.7613567006634407	
i 1	438.23675510204083	2.525	74	589	4	24	10	17	0	1	17	0	0	9.838315102588476	
i 1	438.2431768707483	0.505	74	905	5	2	13	8	0	-2	8	0	0	4.017196818608255	
i 1	438.24397959183676	17.675	66	203	5	16	5	9	0	1	9	0	0	2.7613567006634407	
i 1	438.24558503401363	17.675	66	203	4	12	14	9	0	0	9	0	0	2.7613567006634407	
i 1	438.24638775510203	1.2625	71	203	2	24	5	1	0	0	1	0	0	4.0	
i 1	438.2471904761905	1.01	74	905	6	1	5	16	0	1	16	0	0	8.838315102588476	
i 1	438.2471904761905	17.675	66	589	5	15	12	6	0	1	6	0	0	1.9653769895285376	
i 1	438.24879591836736	1.2625	75	905	6	5	8	2	0	1	2	0	0	4.032251993814951	
i 1	438.2568231292517	17.675	61	905	5	13	16	9	0	0	9	0	0	1.1693972783936342	
i 1	438.25762585034016	0.2525	71	905	5	2	11	2	0	-2	2	0	0	4.017196818608255	
i 1	438.25842857142857	0.2525	68	203	3	24	15	0	0	-1	0	0	0	4.0	
i 1	438.2608367346939	1.7675	74	589	4	4	8	8	0	-2	8	0	0	4.017196818608255	
i 1	438.26725850340137	17.675	61	203	4	12	7	9	0	1	9	0	0	2.7613567006634407	
i 1	438.26886394557823	17.675	61	905	5	14	4	9	0	0	9	0	0	3.5573364117983446	
i 1	438.73996598639457	0.2525	72	203	4	5	11	2	0	1	2	0	0	4.032251993814951	
i 1	438.7479931972789	0.2525	71	203	4	4	6	2	0	-1	2	0	0	4.017196818608255	
i 1	438.7520068027211	0.505	72	905	6	5	4	2	0	1	2	0	0	4.032251993814951	
i 1	438.76806122448977	0.2525	74	203	5	24	7	16	0	1	16	0	0	9.838315102588476	
i 1	438.7696666666667	0.2525	71	203	5	9	7	2	0	-2	2	0	0	3.017196818608255	
i 1	438.98595238095237	0.2525	74	203	6	9	11	2	0	-2	2	0	0	3.017196818608255	
i 1	438.99237414965984	0.2525	71	589	4	24	14	1	0	-1	1	0	0	4.0	
i 1	438.9931768707483	1.7675	71	589	5	3	16	2	0	-2	2	0	0	4.017196818608255	
i 1	438.99879591836736	1.7675	72	589	4	5	11	2	0	-2	2	0	0	4.032251993814951	
i 1	439.00923129251703	1.5150000000000001	68	203	3	24	3	0	0	-1	0	0	0	4.0	
i 1	439.23514965986396	0.2525	77	203	6	1	14	16	0	1	16	0	0	8.838315102588476	
i 1	439.24959863945577	0.2525	77	589	6	1	16	17	0	2	17	0	0	8.838315102588476	
i 1	439.25762585034016	0.2525	75	203	4	5	4	2	0	1	2	0	0	4.032251993814951	
i 1	439.2696666666667	0.2525	68	203	3	24	7	0	0	0	0	0	0	4.0	
i 1	439.48274149659863	0.2525	75	203	3	5	2	2	0	1	2	0	0	4.032251993814951	
i 1	439.48675510204083	0.505	72	589	4	5	7	2	0	-2	2	0	0	4.032251993814951	
i 1	439.48755782312924	0.2525	74	203	5	1	13	17	0	1	17	0	0	8.838315102588476	
i 1	439.48996598639457	0.2525	74	905	6	1	10	16	0	1	16	0	0	8.838315102588476	
i 1	439.4971904761905	0.2525	74	905	5	2	4	8	0	-2	8	0	0	4.017196818608255	
i 1	439.73193877551023	1.01	71	203	2	24	3	1	0	0	1	0	0	4.0	
i 1	439.74478231292517	0.505	74	203	6	1	10	17	0	1	17	0	0	8.838315102588476	
i 1	439.75923129251703	1.01	71	905	5	2	11	2	0	-2	2	0	0	4.017196818608255	
i 1	439.76324489795917	0.2525	75	203	4	5	3	2	0	1	2	0	0	4.032251993814951	
i 1	439.99076870748297	0.505	72	203	4	5	5	2	0	1	2	0	0	4.032251993814951	
i 1	439.9979931972789	0.505	72	203	3	5	3	2	0	-2	2	0	0	4.032251993814951	
i 1	440.00120408163264	0.2525	71	203	4	4	3	2	0	-1	2	0	0	4.017196818608255	
i 1	440.0196666666667	0.2525	74	905	6	1	6	16	0	1	16	0	0	8.838315102588476	
i 1	440.2335442176871	0.2525	77	203	6	1	10	16	0	1	16	0	0	8.838315102588476	
i 1	440.24397959183676	0.2525	74	203	6	9	5	2	0	-2	2	0	0	3.017196818608255	
i 1	440.2479931972789	4.2925	77	589	6	1	3	17	0	2	17	0	0	8.838315102588476	
i 1	440.48675510204083	0.2525	72	905	6	5	4	2	0	1	2	0	0	4.032251993814951	
i 1	440.51886394557823	0.2525	75	905	6	5	4	2	0	1	2	0	0	4.032251993814951	
i 1	440.7303333333333	2.525	72	589	4	5	15	2	0	-2	2	0	0	4.032251993814951	
i 1	440.73274149659863	0.2525	71	203	4	20	2	0	0	0	0	0	0	0.6150260291335998	
i 1	440.73514965986396	1.2625	71	203	4	20	6	0	0	0	0	0	0	0.6150260291335998	
i 1	440.73595238095237	0.505	75	905	6	5	15	2	0	1	2	0	0	4.032251993814951	
i 1	440.73996598639457	0.505	72	589	6	5	6	2	0	-2	2	0	0	4.032251993814951	
i 1	440.7471904761905	1.7675	71	203	2	24	5	1	0	0	1	0	0	4.6150260291336	
i 1	440.75441496598637	1.2625	71	905	6	2	8	2	0	-2	2	0	0	4.017196818608255	
i 1	440.76806122448977	0.505	77	203	6	1	8	16	0	1	16	0	0	8.838315102588476	
i 1	441.0028095238095	0.2525	68	203	3	24	8	1	0	0	1	0	0	4.6150260291336	
i 1	441.00521768707483	2.2725	71	589	5	3	14	2	0	-2	2	0	0	4.017196818608255	
i 1	441.24076870748297	0.505	71	203	3	20	12	1	0	0	1	0	0	0.6150260291335998	
i 1	441.2431768707483	0.2525	75	203	3	5	8	2	0	1	2	0	0	4.032251993814951	
i 1	441.24638775510203	0.505	74	203	5	24	3	16	0	1	16	0	0	9.838315102588476	
i 1	441.2479931972789	0.2525	75	203	4	5	10	2	0	1	2	0	0	4.032251993814951	
i 1	441.26003401360543	0.2525	71	203	5	9	16	2	0	-2	2	0	0	3.017196818608255	
i 1	441.51244217687076	0.505	75	905	6	5	3	2	0	1	2	0	0	4.032251993814951	
i 1	441.5164557823129	0.2525	72	203	3	5	4	2	0	-2	2	0	0	4.032251993814951	
i 1	441.7383605442177	0.2525	74	589	4	24	11	17	0	1	17	0	0	9.838315102588476	
i 1	441.7391632653061	2.02	74	905	6	1	2	16	0	1	16	0	0	8.838315102588476	
i 1	441.74237414965984	0.2525	71	203	3	20	10	1	0	0	1	0	0	0.6150260291335998	
i 1	441.7616394557823	0.2525	74	905	5	2	15	8	0	-2	8	0	0	4.017196818608255	
i 1	441.9803333333333	0.2525	68	589	4	20	9	0	0	-1	0	0	0	0.6150260291335998	
i 1	441.98755782312924	0.505	74	203	6	1	10	17	0	1	17	0	0	8.838315102588476	
i 1	441.99237414965984	1.01	68	203	4	24	7	0	0	-1	0	0	0	4.6150260291336	
i 1	441.99879591836736	0.2525	71	905	4	20	11	0	0	0	0	0	0	0.6150260291335998	
i 1	442.00521768707483	0.2525	68	589	4	24	10	1	0	0	1	0	0	4.6150260291336	
i 1	442.00842857142857	3.0300000000000002	74	589	4	4	3	8	0	-2	8	0	0	4.017196818608255	
i 1	442.01324489795917	0.505	72	203	4	5	4	2	0	1	2	0	0	4.032251993814951	
i 1	442.01806122448977	0.2525	74	203	5	9	6	2	0	-2	2	0	0	3.017196818608255	
i 1	442.23113605442177	0.505	71	203	3	24	13	1	0	0	1	0	0	4.6150260291336	
i 1	442.51003401360543	1.01	74	905	6	1	11	16	0	1	16	0	0	8.838315102588476	
i 1	442.5116394557823	0.7575000000000001	71	203	3	20	11	1	0	0	1	0	0	0.6150260291335998	
i 1	442.7391632653061	0.2525	71	589	4	24	15	0	0	-1	0	0	0	4.6150260291336	
i 1	442.76003401360543	0.2525	71	905	4	20	15	0	0	-1	0	0	0	0.6150260291335998	
i 1	442.7608367346939	1.5150000000000001	71	203	2	24	8	1	0	0	1	0	0	4.6150260291336	
i 1	442.76485034013604	2.02	75	905	6	5	14	2	0	1	2	0	0	4.032251993814951	
i 1	442.98595238095237	0.505	71	203	4	20	7	1	0	0	1	0	0	0.6150260291335998	
i 1	442.9979931972789	0.2525	72	203	3	5	11	2	0	-2	2	0	0	4.032251993814951	
i 1	443.24478231292517	0.505	75	203	4	5	6	2	0	1	2	0	0	4.032251993814951	
i 1	443.24558503401363	0.505	74	905	5	2	9	8	0	-2	8	0	0	4.017196818608255	
i 1	443.26886394557823	0.2525	68	203	3	20	15	1	0	-1	1	0	0	0.6150260291335998	
i 1	443.4971904761905	0.505	68	589	4	20	11	0	0	-1	0	0	0	0.6150260291335998	
i 1	443.50762585034016	0.2525	72	203	4	5	3	2	0	1	2	0	0	4.032251993814951	
i 1	443.5116394557823	0.505	74	203	6	1	6	17	0	1	17	0	0	8.838315102588476	
i 1	443.5196666666667	0.2525	68	905	4	20	7	1	0	-1	1	0	0	0.6150260291335998	
i 1	443.73274149659863	0.505	72	203	3	5	6	2	0	-2	2	0	0	4.032251993814951	
i 1	443.73755782312924	0.505	71	203	5	4	14	2	0	-1	2	0	0	4.017196818608255	
i 1	443.75361224489797	0.505	74	203	5	1	3	17	0	1	17	0	0	8.838315102588476	
i 1	443.75602040816324	0.2525	68	589	4	24	5	0	0	0	0	0	0	4.6150260291336	
i 1	443.7568231292517	0.2525	71	589	5	3	10	2	0	-2	2	0	0	4.017196818608255	
i 1	443.76485034013604	1.7675	68	203	4	24	11	0	0	-1	0	0	0	4.6150260291336	
i 1	443.98193877551023	2.2725	74	589	4	24	8	17	0	1	17	0	0	9.838315102588476	
i 1	443.9891632653061	0.505	71	203	3	20	16	1	0	0	1	0	0	0.6150260291335998	
i 1	443.98996598639457	2.525	71	905	6	2	8	2	0	-2	2	0	0	4.017196818608255	
i 1	444.01324489795917	0.2525	75	203	3	5	12	2	0	1	2	0	0	4.032251993814951	
i 1	444.01725850340137	1.2625	68	203	3	24	12	1	0	-1	1	0	0	4.6150260291336	
i 1	444.23193877551023	0.2525	72	589	6	5	9	2	0	-2	2	0	0	4.032251993814951	
i 1	444.23274149659863	2.525	72	589	6	5	13	2	0	-2	2	0	0	4.032251993814951	
i 1	444.23514965986396	1.01	71	203	1	24	9	1	0	252	1	307	0	4.6150260291336	
i 1	444.2479931972789	0.2525	71	203	5	9	16	2	0	-2	2	0	0	3.017196818608255	
i 1	444.26725850340137	0.2525	74	905	6	1	4	16	0	1	16	0	0	8.838315102588476	
i 1	444.48274149659863	0.2525	68	203	4	20	13	1	0	0	1	0	0	0.6150260291335998	
i 1	444.4979931972789	0.2525	74	203	5	24	2	16	0	1	16	0	0	9.838315102588476	
i 1	444.5108367346939	0.2525	74	905	6	1	10	16	0	1	16	0	0	8.838315102588476	
i 1	444.51806122448977	0.505	74	203	5	9	7	2	0	-2	2	0	0	3.017196818608255	
i 1	444.73755782312924	0.505	72	905	6	5	11	2	0	1	2	0	0	4.032251993814951	
i 1	444.7528095238095	0.505	74	905	6	1	13	16	0	1	16	0	0	8.838315102588476	
i 1	444.7528095238095	1.01	71	203	4	20	3	1	0	0	1	0	0	0.6150260291335998	
i 1	444.9883605442177	0.2525	71	203	4	20	12	1	0	0	1	0	0	0.6150260291335998	
i 1	444.9971904761905	0.505	74	905	6	2	15	8	0	-2	8	0	0	4.017196818608255	
i 1	445.0108367346939	0.7575000000000001	74	203	4	3	2	2	0	-1	2	0	0	4.017196818608255	
i 1	445.2431768707483	0.505	72	203	4	5	10	2	0	1	2	0	0	4.032251993814951	
i 1	445.24397959183676	0.2525	75	203	4	5	3	2	0	1	2	0	0	4.032251993814951	
i 1	445.25602040816324	0.2525	71	905	4	20	5	1	0	-1	1	0	0	0.6150260291335998	
i 1	445.2568231292517	0.2525	68	589	4	24	15	0	0	0	0	0	0	4.6150260291336	
i 1	445.26806122448977	1.5150000000000001	71	203	2	24	13	1	0	0	1	0	0	4.6150260291336	
i 1	445.49558503401363	0.505	75	905	6	5	1	2	0	1	2	0	0	4.032251993814951	
i 1	445.5020068027211	0.7575000000000001	71	203	4	20	5	1	0	-1	1	0	0	0.6150260291335998	
i 1	445.50602040816324	0.2525	71	203	5	9	16	2	0	-2	2	0	0	3.017196818608255	
i 1	445.51725850340137	2.02	74	905	6	1	14	16	0	1	16	0	0	8.838315102588476	
i 1	445.73595238095237	0.2525	74	203	6	1	7	17	0	1	17	0	0	8.838315102588476	
i 1	445.73755782312924	0.2525	72	589	6	5	1	2	0	-2	2	0	0	4.032251993814951	
i 1	445.74157142857143	0.2525	71	203	2	20	16	0	0	-1	0	0	0	0.6150260291335998	
i 1	445.76003401360543	0.2525	71	589	5	3	4	2	0	-2	2	0	0	4.017196818608255	
i 1	445.7696666666667	0.505	71	203	5	4	6	2	0	-1	2	0	0	4.017196818608255	
i 1	445.9979931972789	0.2525	72	203	4	5	4	2	0	1	2	0	0	4.032251993814951	
i 1	446.0020068027211	2.7775	74	589	4	4	10	8	0	-2	8	0	0	4.017196818608255	
i 1	446.0020068027211	0.2525	68	203	3	20	11	0	0	0	0	0	0	0.6150260291335998	
i 1	446.01806122448977	0.505	77	203	6	1	11	16	0	1	16	0	0	8.838315102588476	
i 1	446.01806122448977	0.2525	75	203	3	5	14	2	0	1	2	0	0	4.032251993814951	
i 1	446.2431768707483	0.505	74	203	5	24	14	16	0	1	16	0	0	9.838315102588476	
i 1	446.24638775510203	0.505	71	589	5	3	6	2	0	-2	2	0	0	4.017196818608255	
i 1	446.2520068027211	2.02	68	203	4	24	5	0	0	-1	0	0	0	4.6150260291336	
i 1	446.48514965986396	0.505	77	589	6	1	16	17	0	2	17	0	0	8.838315102588476	
i 1	446.49076870748297	0.2525	71	203	5	4	2	2	0	-1	2	0	0	4.017196818608255	
i 1	446.4931768707483	1.5150000000000001	71	203	3	24	3	1	0	0	1	0	0	4.6150260291336	
i 1	446.50120408163264	0.505	72	203	4	5	6	2	0	1	2	0	0	4.032251993814951	
i 1	446.50923129251703	0.2525	75	203	4	5	7	2	0	1	2	0	0	4.032251993814951	
i 1	446.7343469387755	0.2525	74	203	6	1	14	17	0	1	17	0	0	8.838315102588476	
i 1	446.73996598639457	0.2525	71	905	6	2	3	2	0	-2	2	0	0	4.017196818608255	
i 1	446.75521768707483	1.7675	72	589	6	5	5	2	0	-2	2	0	0	4.032251993814951	
i 1	446.76244217687076	0.2525	74	203	5	9	8	2	0	-2	2	0	0	3.017196818608255	
i 1	446.76806122448977	3.0300000000000002	75	905	6	5	14	2	0	1	2	0	0	4.032251993814951	
i 1	446.98514965986396	0.505	71	589	5	3	3	2	0	-2	2	0	0	4.017196818608255	
i 1	446.9971904761905	0.505	72	203	3	5	12	2	0	-2	2	0	0	4.032251993814951	
i 1	447.00361224489797	0.505	71	203	4	4	4	2	0	-1	2	0	0	4.017196818608255	
i 1	447.00521768707483	0.7575000000000001	74	589	4	24	14	17	0	1	17	0	0	9.838315102588476	
i 1	447.01806122448977	0.2525	74	203	5	24	13	16	0	1	16	0	0	9.838315102588476	
i 1	447.2520068027211	0.2525	68	203	4	20	14	0	0	-1	0	0	0	0.6150260291335998	
i 1	447.25361224489797	3.0300000000000002	77	589	6	1	5	17	0	2	17	0	0	8.838315102588476	
i 1	447.48113605442177	0.2525	74	905	6	2	2	8	0	-2	8	0	0	4.017196818608255	
i 1	447.48996598639457	0.2525	74	203	5	24	2	16	0	1	16	0	0	9.838315102588476	
i 1	447.49558503401363	0.2525	72	203	4	5	4	2	0	1	2	0	0	4.032251993814951	
i 1	447.50762585034016	0.2525	71	203	5	9	6	2	0	-2	2	0	0	3.017196818608255	
i 1	447.50842857142857	0.505	71	203	3	20	4	0	0	-1	0	0	0	0.6150260291335998	
i 1	447.73113605442177	3.7875	71	589	5	3	12	2	0	-2	2	0	0	4.017196818608255	
i 1	447.73996598639457	0.2525	71	203	4	4	1	2	0	-1	2	0	0	4.017196818608255	
i 1	447.75361224489797	0.2525	74	905	6	1	1	16	0	1	16	0	0	8.838315102588476	
i 1	447.75361224489797	1.7675	71	203	3	24	12	1	0	0	1	0	0	4.6150260291336	
i 1	447.7568231292517	0.505	75	203	7	5	13	2	0	1	2	0	0	4.032251993814951	
i 1	447.7656530612245	0.505	74	203	6	1	10	17	0	1	17	0	0	8.838315102588476	
i 1	447.99397959183676	0.2525	71	589	4	20	2	0	0	-1	0	0	0	0.6150260291335998	
i 1	448.00602040816324	0.505	74	203	5	9	14	2	0	-2	2	0	0	3.017196818608255	
i 1	448.01485034013604	0.2525	68	905	4	20	6	0	0	0	0	0	0	0.6150260291335998	
i 1	448.01886394557823	0.2525	68	589	4	24	12	1	0	-1	1	0	0	4.6150260291336	
i 1	448.2391632653061	0.2525	72	589	6	5	11	2	0	-2	2	0	0	4.032251993814951	
i 1	448.25120408163264	0.2525	68	203	3	20	14	1	0	-1	1	0	0	0.6150260291335998	
i 1	448.26404761904763	1.01	71	203	4	20	8	1	0	0	1	0	0	0.6150260291335998	
i 1	448.4843469387755	0.505	74	905	6	2	14	8	0	-2	8	0	0	4.017196818608255	
i 1	448.48514965986396	0.2525	75	203	3	5	9	2	0	1	2	0	0	4.032251993814951	
i 1	448.48675510204083	0.2525	71	203	4	20	9	0	0	-1	0	0	0	0.6150260291335998	
i 1	448.49237414965984	0.7575000000000001	74	589	4	24	14	17	0	1	17	0	0	9.838315102588476	
i 1	448.4971904761905	0.2525	74	203	5	1	13	17	0	1	17	0	0	8.838315102588476	
i 1	448.51806122448977	0.505	75	203	7	5	3	2	0	1	2	0	0	4.032251993814951	
i 1	448.74157142857143	2.02	68	203	3	20	9	1	0	-1	1	0	0	0.6150260291335998	
i 1	448.74478231292517	0.505	74	203	5	24	16	16	0	1	16	0	0	9.838315102588476	
i 1	448.76003401360543	0.2525	74	203	4	3	10	2	0	-1	2	0	0	4.017196818608255	
i 1	448.7696666666667	1.01	71	203	2	20	4	0	0	-1	0	0	0	0.6150260291335998	
i 1	448.98193877551023	0.2525	71	203	5	9	7	2	0	-2	2	0	0	3.017196818608255	
i 1	449.00602040816324	0.7575000000000001	72	589	6	5	6	2	0	-2	2	0	0	4.032251993814951	
i 1	449.0196666666667	0.2525	74	203	5	9	3	2	0	-2	2	0	0	3.017196818608255	
i 1	449.2343469387755	0.2525	74	203	6	1	4	17	0	1	17	0	0	8.838315102588476	
i 1	449.2343469387755	0.7575000000000001	71	905	6	2	13	2	0	-2	2	0	0	4.017196818608255	
i 1	449.23514965986396	0.2525	72	203	3	5	14	2	0	-2	2	0	0	4.032251993814951	
i 1	449.26725850340137	2.02	74	905	6	1	10	16	0	1	16	0	0	8.838315102588476	
i 1	449.48113605442177	0.2525	74	203	5	1	14	17	0	1	17	0	0	8.838315102588476	
i 1	449.4835442176871	0.2525	71	203	4	20	9	1	0	0	1	0	0	0.6150260291335998	
i 1	449.5164557823129	0.505	75	203	7	5	16	2	0	1	2	0	0	4.032251993814951	
i 1	449.73113605442177	2.2725	72	589	6	5	11	2	0	-2	2	0	0	4.032251993814951	
i 1	449.73514965986396	0.2525	68	203	4	24	7	0	0	-1	0	0	0	4.6150260291336	
i 1	449.75842857142857	1.01	71	203	3	20	10	0	0	-1	0	0	0	0.6150260291335998	
i 1	449.7656530612245	0.2525	75	203	3	5	3	2	0	1	2	0	0	4.032251993814951	
i 1	449.98755782312924	0.2525	71	203	3	24	11	1	0	0	1	0	0	4.6150260291336	
i 1	449.99237414965984	0.2525	72	203	7	5	8	2	0	1	2	0	0	4.032251993814951	
i 1	450.00602040816324	0.2525	72	905	6	5	6	2	0	1	2	0	0	4.032251993814951	
i 1	450.24076870748297	0.2525	71	203	5	9	14	2	0	-2	2	0	0	3.017196818608255	
i 1	450.24237414965984	0.7575000000000001	74	203	4	3	12	2	0	-1	2	0	0	4.017196818608255	
i 1	450.24638775510203	1.7675	68	203	4	24	5	0	0	-1	0	0	0	4.6150260291336	
i 1	450.2471904761905	1.5150000000000001	71	203	3	24	15	0	0	0	0	0	0	4.6150260291336	
i 1	450.4891632653061	0.7575000000000001	74	905	6	2	6	8	0	-2	8	0	0	4.017196818608255	
i 1	450.5020068027211	0.505	75	203	3	5	4	2	0	1	2	0	0	4.032251993814951	
i 1	450.50361224489797	2.2725	77	589	6	1	3	17	0	2	17	0	0	8.838315102588476	
i 1	450.50923129251703	0.2525	75	905	6	5	13	2	0	1	2	0	0	4.032251993814951	
i 1	450.74478231292517	0.2525	74	203	6	1	9	17	0	1	17	0	0	8.838315102588476	
i 1	450.7528095238095	0.2525	71	203	4	20	12	0	0	-1	0	0	0	0.6150260291335998	
i 1	450.98274149659863	0.7575000000000001	74	905	5	1	6	16	0	1	16	0	0	8.838315102588476	
i 1	450.99076870748297	2.2725	74	589	4	4	16	8	0	-2	8	0	0	4.017196818608255	
i 1	450.99397959183676	0.2525	72	905	6	5	7	2	0	1	2	0	0	4.032251993814951	
i 1	451.00602040816324	0.2525	72	203	3	5	4	2	0	-2	2	0	0	4.032251993814951	
i 1	451.0164557823129	0.2525	71	203	3	24	15	1	0	0	1	0	0	4.6150260291336	
i 1	451.2303333333333	0.505	75	203	3	5	14	2	0	1	2	0	0	4.032251993814951	
i 1	451.23755782312924	0.2525	75	203	7	5	4	2	0	1	2	0	0	4.032251993814951	
i 1	451.25842857142857	0.2525	74	203	5	1	2	17	0	1	17	0	0	8.838315102588476	
i 1	451.26244217687076	0.505	71	905	6	2	4	2	0	-2	2	0	0	4.017196818608255	
i 1	451.48193877551023	2.2725	75	905	6	5	16	2	0	1	2	0	0	4.032251993814951	
i 1	451.49959863945577	0.2525	74	203	4	3	7	2	0	-1	2	0	0	4.017196818608255	
i 1	451.51244217687076	0.7575000000000001	71	203	4	20	12	1	0	0	1	0	0	0.6150260291335998	
i 1	451.51725850340137	0.2525	74	589	4	24	2	17	0	1	17	0	0	9.838315102588476	
i 1	451.73595238095237	0.2525	71	203	5	9	14	2	0	-2	2	0	0	3.017196818608255	
i 1	451.7520068027211	0.505	71	905	4	20	11	0	0	0	0	0	0	0.6150260291335998	
i 1	451.75521768707483	0.2525	68	589	4	24	3	0	0	0	0	0	0	4.6150260291336	
i 1	451.75602040816324	2.525	71	203	3	24	9	1	0	0	1	0	0	4.6150260291336	
i 1	451.7664557823129	0.505	74	905	6	2	7	8	0	-2	8	0	0	4.017196818608255	
i 1	451.76725850340137	0.2525	72	203	3	5	10	2	0	-2	2	0	0	4.032251993814951	
i 1	451.7696666666667	0.505	68	589	4	20	1	1	0	0	1	0	0	0.6150260291335998	
i 1	451.9891632653061	0.2525	72	203	7	5	16	2	0	1	2	0	0	4.032251993814951	
i 1	451.99558503401363	0.2525	72	589	6	5	16	2	0	-2	2	0	0	4.032251993814951	
i 1	452.0020068027211	0.505	74	203	5	9	15	2	0	-2	2	0	0	3.017196818608255	
i 1	452.23514965986396	0.2525	68	203	3	20	9	1	0	-1	1	0	0	0.6150260291335998	
i 1	452.25521768707483	2.02	74	589	4	24	13	17	0	1	17	0	0	9.838315102588476	
i 1	452.2568231292517	0.7575000000000001	71	203	4	20	7	0	0	0	0	0	0	0.6150260291335998	
i 1	452.25842857142857	0.505	71	203	4	4	12	2	0	-1	2	0	0	4.017196818608255	
i 1	452.2616394557823	0.505	72	203	3	5	14	2	0	-2	2	0	0	4.032251993814951	
i 1	452.4835442176871	0.2525	74	905	6	1	16	16	0	1	16	0	0	8.838315102588476	
i 1	452.48675510204083	0.2525	68	203	4	24	1	0	0	-1	0	0	0	4.6150260291336	
i 1	452.49478231292517	0.2525	71	589	5	3	7	2	0	-2	2	0	0	4.017196818608255	
i 1	452.7303333333333	0.2525	72	203	7	5	10	2	0	-2	2	0	0	4.032251993814951	
i 1	452.73113605442177	0.505	74	203	5	9	14	2	0	-2	2	0	0	3.017196818608255	
i 1	452.74478231292517	0.7575000000000001	74	905	5	1	8	16	0	1	16	0	0	8.838315102588476	
i 1	452.74478231292517	0.2525	72	905	6	5	14	2	0	1	2	0	0	4.032251993814951	
i 1	452.74959863945577	0.7575000000000001	74	203	6	1	10	17	0	1	17	0	0	8.838315102588476	
i 1	452.75040136054423	2.2725	71	905	6	2	6	2	0	-2	2	0	0	4.017196818608255	
i 1	452.75602040816324	2.02	71	203	3	20	8	0	0	-1	0	0	0	0.6150260291335998	
i 1	452.99478231292517	0.505	75	203	7	5	12	2	0	1	2	0	0	4.032251993814951	
i 1	452.9971904761905	1.7675	72	589	6	5	14	2	0	-2	2	0	0	4.032251993814951	
i 1	453.24076870748297	0.2525	71	203	4	4	2	2	0	-1	2	0	0	4.017196818608255	
i 1	453.24076870748297	0.2525	71	203	3	20	9	1	0	-1	1	0	0	0.6150260291335998	
i 1	453.26404761904763	0.505	71	589	5	3	11	2	0	-2	2	0	0	4.017196818608255	
i 1	453.4843469387755	2.2725	77	589	6	1	7	17	0	2	17	0	0	8.838315102588476	
i 1	453.49076870748297	1.01	74	905	6	2	16	8	0	-2	8	0	0	4.017196818608255	
i 1	453.51485034013604	0.505	74	905	5	1	15	16	0	1	16	0	0	8.838315102588476	
i 1	453.5196666666667	0.2525	72	203	7	5	10	2	0	-2	2	0	0	4.032251993814951	
i 1	453.74959863945577	0.2525	71	203	6	9	9	2	0	-2	2	0	0	3.017196818608255	
i 1	453.75120408163264	0.2525	75	203	7	5	13	2	0	1	2	0	0	4.032251993814951	
i 1	453.76244217687076	0.2525	68	203	3	24	8	0	0	0	0	0	0	4.6150260291336	
i 1	453.76806122448977	0.2525	68	203	3	20	13	1	0	0	1	0	0	0.6150260291335998	
i 1	453.7696666666667	0.2525	72	589	6	5	12	2	0	-2	2	0	0	4.032251993814951	
i 1	453.9883605442177	0.2525	71	589	5	3	8	2	0	-2	2	0	0	4.017196818608255	
i 1	453.99959863945577	1.7675	75	905	6	5	8	2	0	1	2	0	0	4.032251993814951	
i 1	454.0164557823129	0.2525	74	203	5	1	12	17	0	1	17	0	0	8.838315102588476	
i 1	454.01725850340137	0.505	71	589	4	24	11	1	0	-1	1	0	0	4.6150260291336	
i 1	454.23193877551023	0.2525	72	905	6	5	12	2	0	1	2	0	0	4.032251993814951	
i 1	454.23675510204083	0.7575000000000001	74	905	5	1	3	16	0	1	16	0	0	8.838315102588476	
i 1	454.23675510204083	1.5150000000000001	74	589	4	4	11	8	0	-2	8	0	0	4.017196818608255	
i 1	454.24959863945577	0.2525	77	203	6	1	1	16	0	1	16	0	0	8.838315102588476	
i 1	454.2616394557823	1.2625	68	203	4	24	6	0	0	-1	0	0	0	4.6150260291336	
i 1	454.48193877551023	1.01	71	203	3	24	2	1	0	-1	1	0	0	4.6150260291336	
i 1	454.48274149659863	0.2525	72	203	7	5	2	2	0	-2	2	0	0	4.032251993814951	
i 1	454.50842857142857	0.2525	74	905	5	1	5	16	0	1	16	0	0	8.838315102588476	
i 1	454.51324489795917	0.7575000000000001	71	203	6	9	2	2	0	-2	2	0	0	3.017196818608255	
i 1	454.7608367346939	2.525	71	203	3	20	13	0	0	-1	0	0	0	0.6150260291335998	
i 1	454.9883605442177	0.2525	75	203	3	5	13	2	0	1	2	0	0	4.032251993814951	
i 1	454.99478231292517	0.7575000000000001	71	203	4	4	7	2	0	-1	2	0	0	4.017196818608255	
i 1	455.0028095238095	0.7575000000000001	74	203	5	1	10	17	0	1	17	0	0	8.838315102588476	
i 1	455.00441496598637	2.2725	71	203	3	20	3	0	0	-1	0	0	0	0.6150260291335998	
i 1	455.00521768707483	0.2525	74	589	4	24	6	17	0	1	17	0	0	9.838315102588476	
i 1	455.01485034013604	0.7575000000000001	72	589	6	5	12	2	0	-2	2	0	0	4.032251993814951	
i 1	455.25040136054423	0.2525	74	905	6	2	16	8	0	-2	8	0	0	4.017196818608255	
i 1	455.4891632653061	0.2525	71	203	3	24	16	1	0	0	1	0	0	4.6150260291336	
i 1	455.49638775510203	0.2525	74	203	6	1	7	17	0	1	17	0	0	8.838315102588476	
i 1	455.50361224489797	0.2525	71	905	6	2	10	2	0	-2	2	0	0	4.017196818608255	
i 1	455.5108367346939	0.2525	75	203	7	5	4	2	0	1	2	0	0	4.032251993814951	
i 1	455.73274149659863	18.685	61	203	5	18	4	6	0	1	6	0	0	2.5046176726734664	
i 1	455.7335442176871	6.0600000000000005	66	589	5	15	12	6	0	1	6	0	0	4.4217487894931224	
i 1	455.7343469387755	6.0600000000000005	61	905	5	14	5	9	0	0	9	0	0	6.013708211762929	
i 1	455.7343469387755	3.0300000000000002	61	905	5	13	8	9	0	0	9	0	0	3.625769078358219	
i 1	455.7343469387755	0.2525	74	905	6	2	12	8	0	-2	8	0	0	4.004062984616236	
i 1	455.73595238095237	18.685	61	203	5	18	10	6	0	0	6	0	0	2.5046176726734664	
i 1	455.74237414965984	0.7575000000000001	74	905	5	1	8	16	0	1	16	0	0	5.419419833319788	
i 1	455.7431768707483	0.2525	71	203	6	9	15	2	0	-2	2	0	0	3.004062984616236	
i 1	455.74397959183676	6.0600000000000005	61	905	6	17	15	6	0	0	6	0	0	2.5046176726734664	
i 1	455.74638775510203	6.0600000000000005	66	203	4	12	3	9	0	0	9	0	0	5.217728500628025	
i 1	455.74638775510203	0.2525	71	203	4	20	14	1	0	-1	1	0	0	0.6150260291335998	
i 1	455.7471904761905	0.7575000000000001	74	589	4	4	11	8	0	-2	8	0	0	4.004062984616236	
i 1	455.7471904761905	6.0600000000000005	61	589	6	17	13	9	0	0	9	0	0	2.5046176726734664	
i 1	455.75040136054423	6.0600000000000005	61	589	5	15	13	6	0	0	6	0	0	4.4217487894931224	
i 1	455.75040136054423	6.0600000000000005	61	203	5	19	8	6	0	0	6	0	0	2.5046176726734664	
i 1	455.7520068027211	1.01	75	203	7	5	1	2	0	1	2	0	0	3.043848439455805	
i 1	455.75521768707483	15.15	61	203	5	16	1	9	0	0	9	0	0	5.217728500628025	
i 1	455.75521768707483	6.0600000000000005	66	203	5	19	1	6	0	1	6	0	0	2.5046176726734664	
i 1	455.75602040816324	6.0600000000000005	61	203	4	12	16	9	0	1	9	0	0	5.217728500628025	
i 1	455.75762585034016	1.5150000000000001	72	589	6	5	10	2	0	-2	2	0	0	3.043848439455805	
i 1	455.7608367346939	0.7575000000000001	74	203	6	1	11	17	0	1	17	0	0	5.419419833319788	
i 1	455.7608367346939	6.0600000000000005	66	905	6	17	8	9	0	0	9	0	0	2.5046176726734664	
i 1	455.7616394557823	2.7775	77	589	5	1	5	17	0	2	17	0	0	5.419419833319788	
i 1	455.7616394557823	6.0600000000000005	66	589	6	17	15	9	0	1	9	0	0	2.5046176726734664	
i 1	455.7656530612245	12.120000000000001	66	203	5	16	3	9	0	1	9	0	0	5.217728500628025	
i 1	455.7664557823129	0.2525	75	203	7	5	4	2	0	1	2	0	0	3.043848439455805	
i 1	455.99157142857143	0.505	72	589	6	5	16	2	0	-2	2	0	0	3.043848439455805	
i 1	456.01886394557823	2.02	71	589	5	3	15	2	0	-2	2	0	0	4.004062984616236	
i 1	456.2383605442177	0.505	74	203	6	9	2	2	0	-2	2	0	0	3.004062984616236	
i 1	456.48675510204083	0.505	71	905	6	2	5	2	0	-2	2	0	0	4.004062984616236	
i 1	456.5028095238095	0.2525	77	203	6	1	2	16	0	1	16	0	0	5.419419833319788	
i 1	456.50842857142857	0.2525	71	203	3	24	7	1	0	-1	1	0	0	4.6150260291336	
i 1	456.5164557823129	0.7575000000000001	74	589	4	24	9	17	0	1	17	0	0	6.419419833319788	
i 1	456.51886394557823	0.505	75	203	7	5	6	2	0	1	2	0	0	3.043848439455805	
i 1	456.7303333333333	0.7575000000000001	71	203	4	20	14	1	0	0	1	0	0	0.6150260291335998	
i 1	456.73755782312924	0.505	68	203	4	20	16	1	0	0	1	0	0	0.6150260291335998	
i 1	456.74076870748297	0.2525	74	203	4	3	5	2	0	-1	2	0	0	4.004062984616236	
i 1	456.74237414965984	0.2525	74	203	5	24	7	16	0	1	16	0	0	6.419419833319788	
i 1	456.7431768707483	1.5150000000000001	75	905	6	5	6	2	0	1	2	0	0	3.043848439455805	
i 1	456.98514965986396	0.2525	71	203	4	4	6	2	0	-1	2	0	0	4.004062984616236	
i 1	456.99478231292517	0.2525	72	203	7	5	12	2	0	-2	2	0	0	3.043848439455805	
i 1	456.9979931972789	1.01	71	203	3	24	8	1	0	0	1	0	0	4.6150260291336	
i 1	457.01244217687076	0.2525	74	905	6	2	11	8	0	-2	8	0	0	4.004062984616236	
i 1	457.2303333333333	0.2525	68	905	4	20	13	1	0	0	1	0	0	0.6150260291335998	
i 1	457.23595238095237	0.505	71	589	4	20	4	1	0	0	1	0	0	0.6150260291335998	
i 1	457.24397959183676	0.2525	74	203	5	1	16	17	0	1	17	0	0	5.419419833319788	
i 1	457.25120408163264	1.5150000000000001	71	905	6	2	7	2	0	-2	2	0	0	4.004062984616236	
i 1	457.25361224489797	0.505	74	203	6	1	16	17	0	1	17	0	0	5.419419833319788	
i 1	457.2568231292517	0.2525	72	589	6	5	4	2	0	-2	2	0	0	3.043848439455805	
i 1	457.26806122448977	0.2525	72	203	7	5	8	2	0	1	2	0	0	3.043848439455805	
i 1	457.48193877551023	0.7575000000000001	74	905	5	1	14	16	0	1	16	0	0	5.419419833319788	
i 1	457.4979931972789	1.5150000000000001	68	203	4	24	3	0	0	-1	0	0	0	4.6150260291336	
i 1	457.50441496598637	0.2525	71	589	4	24	11	0	0	-1	0	0	0	4.6150260291336	
i 1	457.74558503401363	2.2725	72	589	6	5	6	2	0	-2	2	0	0	3.043848439455805	
i 1	457.75361224489797	0.2525	74	203	5	24	10	16	0	1	16	0	0	6.419419833319788	
i 1	457.75842857142857	1.01	71	203	3	24	7	1	0	0	1	0	0	4.6150260291336	
i 1	457.7656530612245	2.02	71	203	3	20	1	0	0	0	0	0	0	0.6150260291335998	
i 1	457.76725850340137	0.2525	72	203	7	5	4	2	0	-2	2	0	0	3.043848439455805	
i 1	457.9843469387755	0.505	72	203	7	5	5	2	0	1	2	0	0	3.043848439455805	
i 1	457.9931768707483	0.7575000000000001	74	589	4	24	13	17	0	1	17	0	0	6.419419833319788	
i 1	458.24478231292517	0.2525	74	905	4	1	4	16	0	1	16	0	0	5.419419833319788	
i 1	458.2479931972789	3.535	71	203	3	20	3	0	0	-1	0	0	0	0.6150260291335998	
i 1	458.25361224489797	0.2525	75	203	7	5	4	2	0	1	2	0	0	3.043848439455805	
i 1	458.25602040816324	0.2525	71	203	6	9	13	2	0	-2	2	0	0	3.004062984616236	
i 1	458.26244217687076	0.2525	74	589	4	4	2	8	0	-2	8	0	0	4.004062984616236	
i 1	458.48274149659863	0.2525	77	203	6	1	11	16	0	1	16	0	0	5.419419833319788	
i 1	458.48274149659863	0.2525	75	203	7	5	8	2	0	1	2	0	0	3.043848439455805	
i 1	458.4971904761905	0.2525	74	905	5	1	10	16	0	1	16	0	0	5.419419833319788	
i 1	458.49879591836736	1.2625	71	589	5	3	1	2	0	-2	2	0	0	4.004062984616236	
i 1	458.5028095238095	0.2525	72	203	7	5	16	2	0	-2	2	0	0	3.043848439455805	
i 1	458.73595238095237	3.0300000000000002	74	589	4	24	15	17	0	1	17	0	0	6.419419833319788	
i 1	458.74237414965984	1.01	71	905	4	2	12	2	0	-2	2	0	0	4.004062984616236	
i 1	458.75361224489797	0.2525	77	589	5	1	13	17	0	2	17	0	0	5.419419833319788	
i 1	458.75842857142857	3.0300000000000002	61	905	5	13	2	9	0	0	9	0	0	3.625769078358219	
i 1	458.76485034013604	0.505	72	203	6	5	9	2	0	-2	2	0	0	3.043848439455805	
i 1	458.7656530612245	0.505	74	203	5	24	13	16	0	1	16	0	0	6.419419833319788	
i 1	458.9843469387755	1.5150000000000001	74	905	4	1	2	16	0	1	16	0	0	5.419419833319788	
i 1	459.00762585034016	0.2525	72	905	6	5	11	2	0	1	2	0	0	3.043848439455805	
i 1	459.01404761904763	0.2525	71	203	3	24	10	1	0	0	1	0	0	4.6150260291336	
i 1	459.01725850340137	0.505	68	203	1	24	7	0	0	248	0	308	0	4.6150260291336	
i 1	459.01806122448977	0.2525	74	905	6	2	12	8	0	-2	8	0	0	4.004062984616236	
i 1	459.23595238095237	2.525	74	589	4	4	13	8	0	-2	8	0	0	4.004062984616236	
i 1	459.23675510204083	0.2525	75	203	7	5	14	2	0	1	2	0	0	3.043848439455805	
i 1	459.24879591836736	0.505	68	203	4	20	11	1	0	0	1	0	0	0.6150260291335998	
i 1	459.2520068027211	0.2525	75	203	7	5	13	2	0	1	2	0	0	3.043848439455805	
i 1	459.26886394557823	0.2525	74	203	6	1	5	17	0	1	17	0	0	5.419419833319788	
i 1	459.4843469387755	0.2525	74	203	5	1	13	17	0	1	17	0	0	5.419419833319788	
i 1	459.49076870748297	1.5150000000000001	75	905	6	5	1	2	0	1	2	0	0	3.043848439455805	
i 1	459.49959863945577	1.01	68	203	4	24	12	0	0	-1	0	0	0	4.6150260291336	
i 1	459.5164557823129	0.2525	72	203	6	5	1	2	0	-2	2	0	0	3.043848439455805	
i 1	459.7303333333333	0.505	74	203	6	9	6	2	0	-2	2	0	0	3.004062984616236	
i 1	459.73113605442177	0.2525	68	589	4	20	3	0	0	0	0	0	0	0.6150260291335998	
i 1	459.74237414965984	0.2525	71	905	4	20	2	1	0	-1	1	0	0	0.6150260291335998	
i 1	459.7608367346939	0.505	75	203	7	5	12	2	0	1	2	0	0	3.043848439455805	
i 1	459.7656530612245	0.2525	74	203	6	3	9	2	0	-1	2	0	0	4.004062984616236	
i 1	459.98514965986396	0.2525	72	589	6	5	1	2	0	-2	2	0	0	3.043848439455805	
i 1	459.98595238095237	0.2525	68	203	4	20	14	1	0	0	1	0	0	0.6150260291335998	
i 1	459.99879591836736	0.2525	74	203	5	24	3	16	0	1	16	0	0	6.419419833319788	
i 1	460.00762585034016	1.7675	71	203	3	20	6	1	0	0	1	0	0	0.6150260291335998	
i 1	460.01404761904763	0.2525	71	203	6	9	11	2	0	-2	2	0	0	3.004062984616236	
i 1	460.2303333333333	0.505	72	589	6	5	7	2	0	-2	2	0	0	3.043848439455805	
i 1	460.23193877551023	0.2525	75	203	7	5	2	2	0	1	2	0	0	3.043848439455805	
i 1	460.24558503401363	0.7575000000000001	74	905	4	1	1	16	0	1	16	0	0	5.419419833319788	
i 1	460.2471904761905	0.505	71	905	4	2	13	2	0	-2	2	0	0	4.004062984616236	
i 1	460.49638775510203	0.2525	71	203	3	24	14	1	0	0	1	0	0	4.6150260291336	
i 1	460.5108367346939	1.2625	72	589	6	5	11	2	0	-2	2	0	0	3.043848439455805	
i 1	460.5164557823129	0.2525	74	203	6	1	5	17	0	1	17	0	0	5.419419833319788	
i 1	460.74397959183676	0.2525	77	203	6	1	10	16	0	1	16	0	0	5.419419833319788	
i 1	460.74638775510203	0.505	75	203	7	5	5	2	0	1	2	0	0	3.043848439455805	
i 1	460.76404761904763	0.7575000000000001	74	203	6	9	2	2	0	-2	2	0	0	3.004062984616236	
i 1	460.76806122448977	0.2525	68	203	4	24	13	0	0	-1	0	0	0	4.6150260291336	
i 1	460.99879591836736	0.505	72	905	6	5	12	2	0	1	2	0	0	3.043848439455805	
i 1	461.00040136054423	0.2525	71	905	4	2	11	2	0	-2	2	0	0	4.004062984616236	
i 1	461.00521768707483	0.7575000000000001	71	203	3	24	11	1	0	-1	1	0	0	4.6150260291336	
i 1	461.23755782312924	0.505	77	589	5	1	1	17	0	2	17	0	0	5.419419833319788	
i 1	461.2383605442177	0.505	74	203	6	3	3	2	0	-1	2	0	0	4.004062984616236	
i 1	461.25602040816324	0.505	75	905	6	5	13	2	0	1	2	0	0	3.043848439455805	
i 1	461.49959863945577	0.2525	72	203	7	5	7	2	0	1	2	0	0	3.043848439455805	
i 1	461.51806122448977	0.2525	71	589	5	3	16	2	0	-2	2	0	0	4.004062984616236	
i 1	461.73113605442177	9.09	61	1087	5	13	1	6	0	1	6	0	0	3.625769078358219	
i 1	461.73113605442177	12.625	61	1087	6	17	4	9	0	1	9	0	0	2.5046176726734664	
i 1	461.73514965986396	1.7675	74	701	4	1	13	16	5005	2	16	0	0	5.419419833319788	
i 1	461.73514965986396	0.505	68	701	3	20	14	1	5005	0	1	0	0	0.6150260291335998	
i 1	461.73595238095237	12.625	61	701	4	19	2	6	0	1	6	0	0	2.5046176726734664	
i 1	461.73996598639457	6.0600000000000005	66	1087	5	14	5	9	0	1	9	0	0	6.013708211762929	
i 1	461.73996598639457	3.0300000000000002	61	701	5	15	2	6	5005	1	6	0	0	4.4217487894931224	
i 1	461.74397959183676	25.25	66	701	6	17	4	6	5005	0	6	0	0	2.5046176726734664	
i 1	461.74638775510203	12.625	61	701	4	12	15	6	0	0	6	0	0	5.217728500628025	
i 1	461.7471904761905	0.2525	74	701	4	4	9	8	0	-1	8	0	0	4.004062984616236	
i 1	461.75120408163264	0.2525	74	203	6	9	1	2	0	-2	2	0	0	3.004062984616236	
i 1	461.75361224489797	24.240000000000002	66	701	6	17	6	6	5005	1	6	0	0	2.5046176726734664	
i 1	461.75441496598637	1.7675	72	1087	4	5	12	2	0	1	2	0	0	3.043848439455805	
i 1	461.75842857142857	0.7575000000000001	77	1087	4	1	1	17	0	1	17	0	0	5.419419833319788	
i 1	461.75842857142857	12.625	61	1087	6	17	2	9	0	0	9	0	0	2.5046176726734664	
i 1	461.7616394557823	0.505	71	701	3	24	6	0	5005	-1	0	0	0	4.6150260291336	
i 1	461.7616394557823	3.2825	71	701	3	20	6	1	0	0	1	0	0	0.6150260291335998	
i 1	461.76244217687076	12.625	61	701	4	19	13	6	0	1	6	0	0	2.5046176726734664	
i 1	461.76324489795917	2.02	74	701	4	4	10	8	5005	-1	8	0	0	4.004062984616236	
i 1	461.76485034013604	0.7575000000000001	72	701	6	5	8	2	0	1	2	0	0	3.043848439455805	
i 1	461.7656530612245	12.120000000000001	61	701	4	12	12	9	0	1	9	0	0	5.217728500628025	
i 1	461.7664557823129	0.2525	72	701	6	5	4	2	5005	-2	2	0	0	3.043848439455805	
i 1	461.76886394557823	12.120000000000001	66	701	5	15	2	6	5005	1	6	0	0	4.4217487894931224	
i 1	462.00441496598637	0.2525	72	1087	6	5	15	2	0	-2	2	0	0	3.043848439455805	
i 1	462.23274149659863	0.2525	71	701	4	24	10	0	5005	-1	0	0	0	4.6150260291336	
i 1	462.25361224489797	0.2525	68	701	4	20	2	1	5005	0	1	0	0	0.6150260291335998	
i 1	462.2568231292517	0.7575000000000001	71	203	4	20	2	1	0	0	1	0	0	0.6150260291335998	
i 1	462.26725850340137	0.505	75	203	7	5	2	2	0	1	2	0	0	3.043848439455805	
i 1	462.26806122448977	0.2525	68	1087	4	20	5	1	0	0	1	0	0	0.6150260291335998	
i 1	462.48514965986396	0.2525	75	701	6	5	4	8	0	1	8	0	0	3.043848439455805	
i 1	462.49558503401363	0.2525	71	203	6	9	11	2	0	-2	2	0	0	3.004062984616236	
i 1	462.49879591836736	0.2525	74	701	4	4	13	8	0	-1	8	0	0	4.004062984616236	
i 1	462.5116394557823	0.2525	68	701	3	20	13	1	5005	0	1	0	0	0.6150260291335998	
i 1	462.5164557823129	0.2525	71	203	4	20	7	1	0	-1	1	0	0	0.6150260291335998	
i 1	462.74076870748297	2.02	74	701	5	3	1	2	5005	-1	2	0	0	4.004062984616236	
i 1	462.74478231292517	0.505	72	1087	6	5	13	2	0	-2	2	0	0	3.043848439455805	
i 1	462.75762585034016	0.505	77	1087	4	1	7	17	0	1	17	0	0	5.419419833319788	
i 1	462.76404761904763	0.505	74	1087	4	2	1	8	0	-2	8	0	0	4.004062984616236	
i 1	462.7664557823129	0.2525	77	1087	5	1	9	16	0	2	16	0	0	5.419419833319788	
i 1	462.76886394557823	1.7675	72	701	6	5	2	2	5005	-2	2	0	0	3.043848439455805	
i 1	462.98274149659863	2.02	71	701	3	24	7	0	5005	-1	0	0	0	4.6150260291336	
i 1	463.00441496598637	0.2525	68	701	3	20	15	1	5005	0	1	0	0	0.6150260291335998	
i 1	463.00842857142857	1.2625	74	701	4	24	16	17	5005	1	17	0	0	6.419419833319788	
i 1	463.23996598639457	0.2525	74	203	6	9	7	2	0	-2	2	0	0	3.004062984616236	
i 1	463.24397959183676	0.505	75	701	6	5	16	8	0	1	8	0	0	3.043848439455805	
i 1	463.2568231292517	0.505	71	203	4	20	5	1	0	0	1	0	0	0.6150260291335998	
i 1	463.2656530612245	0.2525	77	203	6	1	14	16	0	1	16	0	0	5.419419833319788	
i 1	463.4843469387755	0.2525	77	701	5	1	15	17	0	2	17	0	0	5.419419833319788	
i 1	463.49638775510203	0.2525	74	203	5	1	13	17	0	1	17	0	0	5.419419833319788	
i 1	463.51244217687076	0.2525	72	1087	6	5	7	2	0	-2	2	0	0	3.043848439455805	
i 1	463.5156530612245	0.2525	71	1087	4	2	4	2	0	-1	2	0	0	4.004062984616236	
i 1	463.7383605442177	0.505	68	701	3	20	14	1	5005	0	1	0	0	0.6150260291335998	
i 1	463.74076870748297	0.2525	75	203	7	5	11	2	0	1	2	0	0	3.043848439455805	
i 1	463.74638775510203	1.01	77	1087	4	1	1	17	0	1	17	0	0	5.419419833319788	
i 1	463.76324489795917	2.2725	72	1087	4	5	9	2	0	1	2	0	0	3.043848439455805	
i 1	463.9931768707483	0.505	71	1087	4	2	3	2	0	-1	2	0	0	4.004062984616236	
i 1	464.01806122448977	0.2525	72	701	6	5	1	2	5005	1	2	0	0	3.043848439455805	
i 1	464.24879591836736	0.2525	71	203	6	9	7	2	0	-2	2	0	0	3.004062984616236	
i 1	464.26244217687076	0.505	75	701	6	5	9	8	0	1	8	0	0	3.043848439455805	
i 1	464.26806122448977	0.2525	68	203	2	20	10	0	0	0	0	0	0	0.6150260291335998	
i 1	464.48595238095237	0.2525	74	701	4	1	13	16	5005	2	16	0	0	5.419419833319788	
i 1	464.49397959183676	0.2525	72	701	6	5	12	2	0	1	2	0	0	3.043848439455805	
i 1	464.5108367346939	0.7575000000000001	77	1087	5	1	13	16	0	2	16	0	0	5.419419833319788	
i 1	464.51324489795917	0.505	74	203	6	9	15	2	0	-2	2	0	0	3.004062984616236	
i 1	464.51404761904763	4.545	71	701	3	24	2	1	0	0	1	0	0	4.6150260291336	
i 1	464.5164557823129	1.01	68	701	3	20	8	1	5005	0	1	0	0	0.6150260291335998	
i 1	464.7383605442177	1.5150000000000001	74	1087	4	2	11	8	0	-2	8	0	0	4.004062984616236	
i 1	464.74397959183676	0.505	74	701	4	3	2	2	5005	-1	2	0	0	4.004062984616236	
i 1	464.7528095238095	1.01	77	1087	5	1	7	17	0	1	17	0	0	5.419419833319788	
i 1	464.7528095238095	12.120000000000001	61	701	5	15	12	6	5005	1	6	0	0	4.4217487894931224	
i 1	464.75602040816324	0.2525	75	203	7	5	2	2	0	1	2	0	0	3.043848439455805	
i 1	464.75842857142857	2.525	74	701	4	24	5	17	5005	1	17	0	0	6.419419833319788	
i 1	464.76244217687076	0.2525	72	701	6	5	6	2	5005	-2	2	0	0	3.043848439455805	
i 1	464.98113605442177	2.2725	71	701	1	24	4	0	5005	252	0	307	0	4.6150260291336	
i 1	465.0164557823129	0.2525	71	203	4	20	3	1	0	0	1	0	0	0.6150260291335998	
i 1	465.23755782312924	0.2525	74	203	6	9	8	2	0	-2	2	0	0	3.004062984616236	
i 1	465.24237414965984	0.2525	71	203	2	20	15	0	0	-1	0	0	0	0.6150260291335998	
i 1	465.25361224489797	0.2525	71	1087	4	2	11	2	0	-1	2	0	0	4.004062984616236	
i 1	465.26485034013604	0.2525	74	701	4	1	13	16	5005	2	16	0	0	5.419419833319788	
i 1	465.4891632653061	0.7575000000000001	72	701	6	5	14	2	5005	-2	2	0	0	3.043848439455805	
i 1	465.49397959183676	2.02	74	701	4	3	12	2	5005	-1	2	0	0	4.004062984616236	
i 1	465.49478231292517	0.2525	77	1087	5	1	9	16	0	2	16	0	0	5.419419833319788	
i 1	465.5020068027211	0.505	71	1087	2	20	9	1	0	-1	1	0	0	0.6150260291335998	
i 1	465.50361224489797	0.505	68	701	4	20	4	1	5005	0	1	0	0	0.6150260291335998	
i 1	465.5156530612245	0.2525	75	203	7	5	13	2	0	1	2	0	0	3.043848439455805	
i 1	465.7391632653061	1.7675	72	701	6	5	8	2	5005	1	2	0	0	3.043848439455805	
i 1	465.7479931972789	0.2525	71	203	6	9	6	2	0	-2	2	0	0	3.004062984616236	
i 1	465.9835442176871	0.2525	74	701	4	4	1	8	0	-1	8	0	0	4.004062984616236	
i 1	465.98675510204083	0.2525	75	701	6	5	6	8	0	1	8	0	0	3.043848439455805	
i 1	465.9931768707483	0.505	74	701	4	1	13	16	5005	2	16	0	0	5.419419833319788	
i 1	465.9931768707483	0.2525	74	203	5	1	11	17	0	1	17	0	0	5.419419833319788	
i 1	465.99959863945577	0.2525	71	203	2	20	1	1	0	0	1	0	0	0.6150260291335998	
i 1	466.00120408163264	1.5150000000000001	68	701	3	20	13	1	5005	0	1	0	0	0.6150260291335998	
i 1	466.2343469387755	0.505	77	203	5	1	7	16	0	1	16	0	0	5.419419833319788	
i 1	466.2383605442177	0.2525	71	1087	4	2	5	2	0	-1	2	0	0	4.004062984616236	
i 1	466.24558503401363	0.2525	72	1087	4	5	12	2	0	1	2	0	0	3.043848439455805	
i 1	466.2528095238095	0.2525	75	203	7	5	14	2	0	1	2	0	0	3.043848439455805	
i 1	466.26725850340137	0.2525	71	203	2	20	2	0	0	0	0	0	0	0.6150260291335998	
i 1	466.2696666666667	0.505	71	203	6	9	11	2	0	-2	2	0	0	3.004062984616236	
i 1	466.48595238095237	0.7575000000000001	75	701	6	5	2	8	0	1	8	0	0	3.043848439455805	
i 1	466.48675510204083	0.505	74	701	5	3	12	8	0	-2	8	0	0	4.004062984616236	
i 1	466.49076870748297	0.2525	77	1087	5	1	12	16	0	2	16	0	0	5.419419833319788	
i 1	466.49478231292517	0.2525	72	203	7	5	9	2	0	1	2	0	0	3.043848439455805	
i 1	466.7343469387755	0.2525	74	203	5	1	10	17	0	1	17	0	0	5.419419833319788	
i 1	466.7431768707483	1.5150000000000001	72	1087	4	5	9	2	0	1	2	0	0	3.043848439455805	
i 1	466.75040136054423	1.01	74	701	4	1	2	16	5005	2	16	0	0	5.419419833319788	
i 1	466.7696666666667	0.2525	74	203	6	9	13	2	0	-2	2	0	0	3.004062984616236	
i 1	466.99157142857143	0.505	71	1087	4	2	15	2	0	-1	2	0	0	4.004062984616236	
i 1	467.0028095238095	0.7575000000000001	74	701	4	4	3	8	5005	-1	8	0	0	4.004062984616236	
i 1	467.2383605442177	0.7575000000000001	77	701	4	24	16	16	0	1	16	0	0	6.419419833319788	
i 1	467.24959863945577	0.7575000000000001	68	203	4	24	2	0	0	-1	0	0	0	4.6150260291336	
i 1	467.2616394557823	0.2525	72	701	6	5	15	2	0	1	2	0	0	3.043848439455805	
i 1	467.49076870748297	0.2525	75	203	7	5	15	2	0	1	2	0	0	3.043848439455805	
i 1	467.49397959183676	0.2525	68	701	4	20	11	1	5005	0	1	0	0	0.6150260291335998	
i 1	467.50441496598637	0.2525	74	1087	4	2	11	8	0	-2	8	0	0	4.004062984616236	
i 1	467.50441496598637	0.2525	74	701	4	4	4	8	0	-1	8	0	0	4.004062984616236	
i 1	467.50521768707483	0.2525	71	701	4	24	12	0	5005	-1	0	0	0	4.6150260291336	
i 1	467.51404761904763	0.2525	72	203	7	5	6	2	0	1	2	0	0	3.043848439455805	
i 1	467.5196666666667	0.2525	77	701	5	1	8	17	0	2	17	0	0	5.419419833319788	
i 1	467.74157142857143	3.0300000000000002	72	701	4	5	12	2	5005	-2	2	0	0	3.043848439455805	
i 1	467.7479931972789	6.565	66	203	5	16	10	9	0	1	9	0	0	5.217728500628025	
i 1	467.75040136054423	0.2525	74	701	4	3	6	2	5005	-1	2	0	0	4.004062984616236	
i 1	467.75120408163264	1.2625	68	701	1	20	11	1	5005	0	1	0	0	0.6150260291335998	
i 1	467.7528095238095	1.01	74	701	5	1	16	16	5005	2	16	0	0	5.419419833319788	
i 1	467.7528095238095	0.505	77	701	4	1	13	17	0	2	17	0	0	5.419419833319788	
i 1	467.7616394557823	1.5150000000000001	74	701	4	4	14	8	5005	-1	8	0	0	4.004062984616236	
i 1	467.7696666666667	0.2525	74	203	6	9	1	2	0	-2	2	0	0	3.004062984616236	
i 1	467.98274149659863	0.2525	71	701	3	20	14	1	0	0	1	0	0	0.6150260291335998	
i 1	467.9883605442177	0.2525	71	1087	4	2	5	2	0	-1	2	0	0	4.004062984616236	
i 1	467.99879591836736	0.505	74	701	5	3	5	8	0	-2	8	0	0	4.004062984616236	
i 1	468.01404761904763	0.2525	77	203	5	1	13	16	0	1	16	0	0	5.419419833319788	
i 1	468.01404761904763	0.505	68	203	1	24	8	0	0	252	0	307	0	4.6150260291336	
i 1	468.2303333333333	1.2625	77	1087	5	1	6	17	0	1	17	0	0	5.419419833319788	
i 1	468.2343469387755	0.505	75	701	6	5	5	8	0	1	8	0	0	3.043848439455805	
i 1	468.2616394557823	0.2525	71	701	3	24	15	0	5005	-1	0	0	0	4.6150260291336	
i 1	468.26244217687076	0.2525	74	701	4	24	5	17	5005	1	17	0	0	6.419419833319788	
i 1	468.50040136054423	0.2525	71	1087	4	2	3	2	0	-1	2	0	0	4.004062984616236	
i 1	468.51485034013604	1.2625	68	203	2	20	8	0	0	-1	0	0	0	0.6150260291335998	
i 1	468.5156530612245	2.2725	74	1087	4	2	14	8	0	-2	8	0	0	4.004062984616236	
i 1	468.5164557823129	1.2625	68	203	4	24	7	0	0	-1	0	0	0	4.6150260291336	
i 1	468.7471904761905	0.2525	77	701	4	24	5	16	0	1	16	0	0	6.419419833319788	
i 1	468.7479931972789	0.2525	74	203	6	9	5	2	0	-2	2	0	0	3.004062984616236	
i 1	468.75842857142857	0.505	74	701	4	24	3	17	5005	1	17	0	0	6.419419833319788	
i 1	468.9835442176871	0.7575000000000001	71	203	6	9	15	2	0	-2	2	0	0	3.004062984616236	
i 1	468.9971904761905	2.02	74	701	5	1	5	16	5005	2	16	0	0	5.419419833319788	
i 1	469.0068231292517	1.5150000000000001	68	203	2	20	14	1	0	-1	1	0	0	0.6150260291335998	
i 1	469.23755782312924	0.2525	77	203	5	1	1	16	0	1	16	0	0	5.419419833319788	
i 1	469.23996598639457	0.2525	71	1087	4	2	12	2	0	-1	2	0	0	4.004062984616236	
i 1	469.24638775510203	1.2625	71	203	4	20	2	1	0	0	1	0	0	0.6150260291335998	
i 1	469.48514965986396	0.2525	74	701	4	24	14	17	5005	1	17	0	0	6.419419833319788	
i 1	469.48595238095237	0.505	74	701	4	4	7	8	0	-1	8	0	0	4.004062984616236	
i 1	469.4931768707483	0.505	77	701	4	24	4	16	0	1	16	0	0	6.419419833319788	
i 1	469.50923129251703	1.2625	72	1087	4	5	7	2	0	1	2	0	0	3.043848439455805	
i 1	469.7520068027211	0.2525	72	701	6	5	15	2	0	1	2	0	0	3.043848439455805	
i 1	469.75923129251703	0.505	74	701	5	3	12	8	0	-2	8	0	0	4.004062984616236	
i 1	469.7656530612245	3.0300000000000002	68	701	1	20	6	1	5005	0	1	0	0	0.6150260291335998	
i 1	469.99638775510203	0.2525	74	701	4	3	3	2	5005	-1	2	0	0	4.004062984616236	
i 1	470.0108367346939	0.505	77	1087	5	1	5	17	0	1	17	0	0	5.419419833319788	
i 1	470.01324489795917	2.7775	71	701	3	24	15	1	0	0	1	0	0	4.6150260291336	
i 1	470.2383605442177	0.2525	72	701	6	5	14	2	5005	1	2	0	0	3.043848439455805	
i 1	470.25441496598637	0.2525	74	701	4	4	16	8	0	-1	8	0	0	4.004062984616236	
i 1	470.2568231292517	2.7775	74	701	4	4	3	8	5005	-1	8	0	0	4.004062984616236	
i 1	470.4835442176871	0.2525	77	701	4	1	16	17	0	2	17	0	0	5.419419833319788	
i 1	470.4835442176871	0.505	71	1087	4	2	1	2	0	-1	2	0	0	4.004062984616236	
i 1	470.49478231292517	0.2525	74	701	4	24	5	17	5005	1	17	0	0	6.419419833319788	
i 1	470.50521768707483	0.2525	71	701	3	20	8	1	0	0	1	0	0	0.6150260291335998	
i 1	470.73274149659863	0.7575000000000001	74	203	4	1	13	17	0	1	17	0	0	5.419419833319788	
i 1	470.73595238095237	0.2525	72	701	6	5	4	2	0	1	2	0	0	3.043848439455805	
i 1	470.7383605442177	2.2725	74	701	4	24	11	17	5005	1	17	0	0	6.419419833319788	
i 1	470.74397959183676	0.2525	68	203	2	20	6	1	0	-1	1	0	0	0.6150260291335998	
i 1	470.74558503401363	3.535	61	203	5	16	10	9	0	0	9	0	0	5.217728500628025	
i 1	470.75361224489797	3.0300000000000002	72	1087	5	5	1	2	0	1	2	0	0	3.043848439455805	
i 1	470.75602040816324	0.2525	75	203	7	5	10	2	0	1	2	0	0	3.043848439455805	
i 1	470.98113605442177	0.2525	77	1087	5	1	9	17	0	1	17	0	0	5.419419833319788	
i 1	470.9883605442177	0.2525	74	203	6	9	9	2	0	-2	2	0	0	3.004062984616236	
i 1	470.99076870748297	0.505	72	203	7	5	10	2	0	1	2	0	0	3.043848439455805	
i 1	470.99157142857143	0.2525	74	701	4	3	10	2	5005	-1	2	0	0	4.004062984616236	
i 1	471.00120408163264	0.2525	75	701	6	5	2	8	0	1	8	0	0	3.043848439455805	
i 1	471.01806122448977	0.505	71	701	1	24	16	0	5005	-1	0	0	0	4.6150260291336	
i 1	471.2335442176871	0.505	74	1087	4	2	2	8	0	-2	8	0	0	4.004062984616236	
i 1	471.2383605442177	0.2525	77	701	4	1	10	17	0	2	17	0	0	5.419419833319788	
i 1	471.25521768707483	0.2525	74	701	4	4	7	8	0	-1	8	0	0	4.004062984616236	
i 1	471.48193877551023	0.505	75	701	6	5	2	8	0	1	8	0	0	3.043848439455805	
i 1	471.4971904761905	0.2525	72	701	6	5	1	2	0	1	2	0	0	3.043848439455805	
i 1	471.50040136054423	0.505	68	203	2	20	2	0	0	-1	0	0	0	0.6150260291335998	
i 1	471.7335442176871	0.7575000000000001	72	701	4	5	10	2	5005	-2	2	0	0	3.043848439455805	
i 1	471.7520068027211	0.505	74	701	5	3	12	8	0	-2	8	0	0	4.004062984616236	
i 1	471.7696666666667	0.2525	74	701	4	3	7	2	5005	-1	2	0	0	4.004062984616236	
i 1	471.98274149659863	0.7575000000000001	77	1087	5	1	3	17	0	1	17	0	0	5.419419833319788	
i 1	471.9835442176871	0.505	74	701	4	4	16	8	0	-1	8	0	0	4.004062984616236	
i 1	471.9835442176871	0.2525	71	701	3	20	15	1	0	0	1	0	0	0.6150260291335998	
i 1	471.99237414965984	0.2525	75	203	7	5	8	2	0	1	2	0	0	3.043848439455805	
i 1	472.00842857142857	0.2525	77	1087	5	1	6	16	0	2	16	0	0	5.419419833319788	
i 1	472.23514965986396	2.525	74	701	5	1	13	16	5005	2	16	0	0	5.419419833319788	
i 1	472.24397959183676	1.01	71	203	4	20	16	1	0	0	1	0	0	0.6150260291335998	
i 1	472.2616394557823	1.01	68	203	2	20	2	1	0	-1	1	0	0	0.6150260291335998	
i 1	472.26404761904763	0.2525	74	203	6	9	4	2	0	-2	2	0	0	3.004062984616236	
i 1	472.26806122448977	0.7575000000000001	72	701	6	5	1	2	0	1	2	0	0	3.043848439455805	
i 1	472.48113605442177	0.2525	75	203	7	5	6	2	0	1	2	0	0	3.043848439455805	
i 1	472.49478231292517	0.505	71	203	4	9	11	2	0	-2	2	0	0	3.004062984616236	
i 1	472.49638775510203	1.7675	71	701	3	20	8	1	0	0	1	0	0	0.6150260291335998	
i 1	472.51404761904763	1.2625	71	701	1	24	14	0	5005	-1	0	0	0	4.6150260291336	
i 1	472.5156530612245	4.04	74	701	4	3	16	2	5005	-1	2	0	0	4.004062984616236	
i 1	472.73193877551023	0.2525	77	701	4	24	9	16	0	1	16	0	0	6.419419833319788	
i 1	472.7528095238095	0.505	72	1087	4	5	6	2	0	-2	2	0	0	3.043848439455805	
i 1	472.99237414965984	0.2525	74	701	4	4	9	8	0	-1	8	0	0	4.004062984616236	
i 1	472.9931768707483	0.2525	77	1087	5	1	5	16	0	2	16	0	0	5.419419833319788	
i 1	473.0108367346939	0.505	74	203	4	1	13	17	0	1	17	0	0	5.419419833319788	
i 1	473.0116394557823	1.5150000000000001	72	701	4	5	6	2	5005	-2	2	0	0	3.043848439455805	
i 1	473.0156530612245	0.2525	77	203	4	1	7	16	0	1	16	0	0	5.419419833319788	
i 1	473.0196666666667	0.505	71	1087	4	2	7	2	0	-1	2	0	0	4.004062984616236	
i 1	473.24157142857143	0.2525	68	203	2	20	9	0	0	-1	0	0	0	0.6150260291335998	
i 1	473.26003401360543	0.2525	72	203	7	5	9	2	0	1	2	0	0	3.043848439455805	
i 1	473.2616394557823	0.505	74	203	6	9	7	2	0	-2	2	0	0	3.004062984616236	
i 1	473.48675510204083	0.2525	74	701	4	4	3	8	5005	-1	8	0	0	4.004062984616236	
i 1	473.48996598639457	0.505	77	1087	5	1	13	16	0	2	16	0	0	5.419419833319788	
i 1	473.4931768707483	0.505	75	701	6	5	1	8	0	1	8	0	0	3.043848439455805	
i 1	473.49397959183676	0.2525	74	701	5	3	7	8	0	-2	8	0	0	4.004062984616236	
i 1	473.50521768707483	0.2525	68	701	1	20	3	1	5005	0	1	0	0	0.6150260291335998	
i 1	473.51404761904763	0.2525	77	203	4	1	11	16	0	1	16	0	0	5.419419833319788	
i 1	473.73514965986396	0.505	61	701	5	12	14	9	0	1	9	0	0	5.217728500628025	
i 1	473.7391632653061	0.505	74	701	4	24	5	17	5005	1	17	0	0	6.419419833319788	
i 1	473.74959863945577	0.505	71	203	4	20	3	1	0	0	1	0	0	0.6150260291335998	
i 1	473.7528095238095	0.505	71	1087	2	20	16	0	0	0	0	0	0	0.6150260291335998	
i 1	473.75521768707483	0.505	74	701	4	4	9	8	0	-1	8	0	0	4.004062984616236	
i 1	473.75602040816324	0.505	68	701	2	20	7	1	5005	0	1	0	0	0.6150260291335998	
i 1	473.76404761904763	0.2525	71	701	2	24	13	0	5005	-1	0	0	0	4.6150260291336	
i 1	473.7656530612245	0.505	71	203	4	9	8	2	0	-2	2	0	0	3.004062984616236	
i 1	473.99157142857143	0.2525	72	701	4	5	11	2	5005	1	2	0	0	3.043848439455805	
i 1	474.0028095238095	0.2525	77	1087	5	1	1	17	0	1	17	0	0	5.419419833319788	
i 1	474.00762585034016	0.2525	72	1087	5	5	9	2	0	1	2	0	0	3.043848439455805	
i 1	474.01404761904763	0.2525	72	701	6	5	2	2	0	1	2	0	0	3.043848439455805	
i 1	474.2303333333333	7.07	66	391	4	19	6	6	0	0	6	0	0	2.5046176726734664	
i 1	474.23113605442177	7.07	61	5	5	18	11	9	0	0	9	0	0	2.5046176726734664	
i 1	474.23514965986396	0.2525	68	391	3	20	10	1	0	-1	1	0	0	0.6150260291335998	
i 1	474.23675510204083	7.07	66	5	5	18	2	9	0	0	9	0	0	2.5046176726734664	
i 1	474.23755782312924	1.2625	68	5	4	20	6	1	0	-1	1	0	0	0.6150260291335998	
i 1	474.2383605442177	5.555	61	5	5	16	7	6	0	1	6	0	0	5.217728500628025	
i 1	474.2391632653061	8.585	61	5	7	17	4	9	0	0	9	0	0	2.5046176726734664	
i 1	474.24076870748297	1.7675	74	5	6	1	11	16	0	2	16	0	0	5.419419833319788	
i 1	474.24638775510203	7.07	66	391	4	19	12	9	0	0	9	0	0	2.5046176726734664	
i 1	474.24879591836736	0.2525	74	5	4	1	11	16	0	1	16	0	0	5.419419833319788	
i 1	474.24959863945577	2.525	66	391	4	12	13	6	0	0	6	0	0	5.217728500628025	
i 1	474.2520068027211	7.07	61	5	5	16	5	9	0	1	9	0	0	5.217728500628025	
i 1	474.25361224489797	0.2525	74	701	4	4	6	8	5005	-1	8	0	0	4.004062984616236	
i 1	474.25441496598637	0.2525	68	391	1	20	14	1	5005	0	1	0	0	0.6150260291335998	
i 1	474.2568231292517	1.5150000000000001	68	5	2	20	14	0	0	0	0	0	0	0.6150260291335998	
i 1	474.2608367346939	0.2525	74	5	6	1	12	17	0	1	17	0	0	5.419419833319788	
i 1	474.2608367346939	1.7675	72	5	6	5	2	2	0	-2	2	0	0	3.043848439455805	
i 1	474.26485034013604	0.2525	71	5	4	9	1	8	0	-1	8	0	0	3.004062984616236	
i 1	474.26806122448977	0.2525	72	391	6	5	3	8	0	1	8	0	0	3.043848439455805	
i 1	474.26886394557823	5.555	66	5	7	17	1	6	0	1	6	0	0	2.5046176726734664	
i 1	474.2696666666667	7.07	66	391	5	12	4	9	0	1	9	0	0	5.217728500628025	
i 1	474.48514965986396	0.2525	68	5	2	24	2	1	0	-1	1	0	0	4.6150260291336	
i 1	474.49076870748297	0.505	74	391	5	3	4	8	0	-1	8	0	0	4.004062984616236	
i 1	474.49237414965984	0.505	74	5	5	2	6	2	0	-1	2	0	0	4.004062984616236	
i 1	474.7303333333333	1.01	74	391	4	24	15	16	0	1	16	0	0	6.419419833319788	
i 1	474.73113605442177	1.5150000000000001	68	391	1	20	10	1	5005	0	1	0	0	0.6150260291335998	
i 1	474.73514965986396	0.505	71	391	4	4	7	8	0	-2	8	0	0	4.004062984616236	
i 1	474.75762585034016	3.535	71	391	3	24	10	1	0	0	1	0	0	4.6150260291336	
i 1	474.99157142857143	0.505	74	5	5	1	9	16	0	2	16	0	0	5.419419833319788	
i 1	475.00120408163264	2.7775	74	701	4	4	3	8	5005	-1	8	0	0	4.004062984616236	
i 1	475.00361224489797	0.2525	72	391	6	5	5	8	0	1	8	0	0	3.043848439455805	
i 1	475.0116394557823	0.2525	74	5	6	1	10	17	0	1	17	0	0	5.419419833319788	
i 1	475.01886394557823	0.505	75	5	6	5	5	2	0	1	2	0	0	3.043848439455805	
i 1	475.23595238095237	0.2525	71	5	4	9	8	2	0	-2	2	0	0	3.004062984616236	
i 1	475.25923129251703	1.5150000000000001	72	701	4	5	6	2	5005	-2	2	0	0	3.043848439455805	
i 1	475.50521768707483	0.505	71	5	5	2	8	8	0	-2	8	0	0	4.004062984616236	
i 1	475.50762585034016	2.02	74	701	5	1	3	16	5005	2	16	0	0	5.419419833319788	
i 1	475.5196666666667	0.2525	75	391	6	5	12	2	0	1	2	0	0	3.043848439455805	
i 1	475.74638775510203	0.505	74	5	5	1	2	16	0	2	16	0	0	5.419419833319788	
i 1	475.7479931972789	0.2525	68	391	3	20	7	1	0	-1	1	0	0	0.6150260291335998	
i 1	475.75441496598637	0.505	71	391	4	4	11	8	0	-2	8	0	0	4.004062984616236	
i 1	475.75762585034016	1.01	72	391	6	5	13	8	0	1	8	0	0	3.043848439455805	
i 1	475.98113605442177	0.2525	71	5	2	20	10	0	0	-1	0	0	0	0.6150260291335998	
i 1	475.9891632653061	0.2525	75	391	6	5	13	2	0	1	2	0	0	3.043848439455805	
i 1	476.01404761904763	0.2525	74	391	4	24	8	16	0	1	16	0	0	6.419419833319788	
i 1	476.01806122448977	0.7575000000000001	68	5	4	20	16	1	0	-1	1	0	0	0.6150260291335998	
i 1	476.2303333333333	0.2525	75	5	4	5	5	2	0	-2	2	0	0	3.043848439455805	
i 1	476.23675510204083	0.505	71	5	4	9	15	8	0	-1	8	0	0	3.004062984616236	
i 1	476.24879591836736	0.2525	71	5	5	2	16	8	0	-2	8	0	0	4.004062984616236	
i 1	476.2528095238095	0.2525	74	701	4	24	11	17	5005	1	17	0	0	6.419419833319788	
i 1	476.25521768707483	0.7575000000000001	77	391	3	1	8	16	0	1	16	0	0	5.419419833319788	
i 1	476.48595238095237	0.2525	74	391	5	3	14	8	0	-1	8	0	0	4.004062984616236	
i 1	476.73274149659863	0.2525	74	5	5	1	15	16	0	2	16	0	0	5.419419833319788	
i 1	476.73755782312924	0.505	74	391	3	3	11	8	0	-1	8	0	0	4.004062984616236	
i 1	476.7471904761905	4.545	66	391	5	12	2	6	0	0	6	0	0	5.217728500628025	
i 1	476.7656530612245	0.2525	71	391	4	4	3	8	0	-2	8	0	0	4.004062984616236	
i 1	476.7656530612245	0.505	75	391	6	5	10	2	0	1	2	0	0	3.043848439455805	
i 1	476.7664557823129	0.2525	74	5	7	1	14	17	0	1	17	0	0	5.419419833319788	
i 1	476.7664557823129	3.2825	72	701	5	5	5	2	5005	-2	2	0	0	3.043848439455805	
i 1	476.98274149659863	0.2525	72	5	4	5	14	8	0	1	8	0	0	3.043848439455805	
i 1	476.9883605442177	0.7575000000000001	68	391	1	20	4	1	5005	-1	1	0	0	0.6150260291335998	
i 1	476.9891632653061	0.2525	68	391	3	20	4	1	0	-1	1	0	0	0.6150260291335998	
i 1	476.99076870748297	2.2725	74	5	5	2	12	2	0	-1	2	0	0	4.004062984616236	
i 1	476.99558503401363	0.2525	72	391	6	5	6	8	0	1	8	0	0	3.043848439455805	
i 1	477.00361224489797	1.01	74	5	6	1	4	16	0	2	16	0	0	5.419419833319788	
i 1	477.0116394557823	2.02	74	701	4	24	10	17	5005	1	17	0	0	6.419419833319788	
i 1	477.01244217687076	0.505	68	5	2	20	13	0	0	0	0	0	0	0.6150260291335998	
i 1	477.24478231292517	0.505	75	5	6	5	8	2	0	1	2	0	0	3.043848439455805	
i 1	477.24959863945577	1.5150000000000001	71	5	4	9	9	8	0	-1	8	0	0	3.004062984616236	
i 1	477.25521768707483	0.505	71	5	2	20	15	0	0	-1	0	0	0	0.6150260291335998	
i 1	477.26324489795917	3.535	68	5	2	20	3	1	0	-1	1	0	0	0.6150260291335998	
i 1	477.26404761904763	0.2525	71	5	4	9	1	2	0	-2	2	0	0	3.004062984616236	
i 1	477.2696666666667	0.505	72	701	4	5	2	2	5005	1	2	0	0	3.043848439455805	
i 1	477.5020068027211	0.2525	75	5	4	5	4	2	0	-2	2	0	0	3.043848439455805	
i 1	477.51324489795917	0.2525	74	391	3	24	16	16	0	1	16	0	0	6.419419833319788	
i 1	477.74157142857143	0.2525	71	391	4	4	15	8	0	-2	8	0	0	4.004062984616236	
i 1	477.74558503401363	0.505	71	701	2	20	10	1	5005	-1	1	0	0	0.6150260291335998	
i 1	477.7471904761905	1.2625	68	5	2	24	7	1	0	-1	1	0	0	4.6150260291336	
i 1	477.74879591836736	0.7575000000000001	71	701	2	24	3	1	5005	-1	1	0	0	4.6150260291336	
i 1	477.74959863945577	0.505	71	5	3	20	4	0	0	-1	0	0	0	0.6150260291335998	
i 1	477.7528095238095	0.2525	74	5	7	1	3	17	0	1	17	0	0	5.419419833319788	
i 1	477.75762585034016	1.2625	72	5	5	5	9	2	0	-2	2	0	0	3.043848439455805	
i 1	477.7616394557823	0.2525	75	391	6	5	5	2	0	1	2	0	0	3.043848439455805	
i 1	477.76404761904763	0.2525	71	5	7	2	16	8	0	-2	8	0	0	4.004062984616236	
i 1	477.98113605442177	0.505	68	5	3	20	15	0	0	0	0	0	0	0.6150260291335998	
i 1	477.9971904761905	0.2525	74	701	4	3	1	2	5005	-1	2	0	0	4.004062984616236	
i 1	478.0164557823129	3.535	74	701	5	1	13	16	5005	2	16	0	0	5.419419833319788	
i 1	478.24558503401363	0.2525	72	5	4	5	13	8	0	1	8	0	0	3.043848439455805	
i 1	478.48595238095237	2.02	68	5	2	20	13	0	0	0	0	0	0	0.6150260291335998	
i 1	478.5028095238095	0.2525	74	391	3	3	13	8	0	-1	8	0	0	4.004062984616236	
i 1	478.5164557823129	0.2525	71	391	1	24	8	0	5005	0	0	0	0	4.6150260291336	
i 1	478.73113605442177	2.7775	74	701	4	4	10	8	5005	-1	8	0	0	4.004062984616236	
i 1	478.73996598639457	0.2525	72	701	4	5	8	2	5005	1	2	0	0	3.043848439455805	
i 1	478.74076870748297	0.505	71	5	4	9	14	2	0	-2	2	0	0	3.004062984616236	
i 1	478.7664557823129	0.2525	72	5	4	5	8	8	0	1	8	0	0	3.043848439455805	
i 1	478.98996598639457	0.2525	71	391	1	24	11	0	5005	0	0	0	0	4.6150260291336	
i 1	478.9931768707483	0.2525	72	391	6	5	4	8	0	1	8	0	0	3.043848439455805	
i 1	478.99879591836736	0.7575000000000001	74	5	5	1	10	16	0	2	16	0	0	5.419419833319788	
i 1	478.99959863945577	0.7575000000000001	74	391	3	24	6	16	0	1	16	0	0	6.419419833319788	
i 1	479.2303333333333	1.7675	72	5	5	5	5	2	0	-2	2	0	0	3.043848439455805	
i 1	479.24076870748297	0.2525	71	5	4	9	11	8	0	-1	8	0	0	3.004062984616236	
i 1	479.25602040816324	0.2525	74	701	4	24	15	17	5005	1	17	0	0	6.419419833319788	
i 1	479.26003401360543	0.2525	68	391	1	20	2	0	5005	0	0	0	0	0.6150260291335998	
i 1	479.26725850340137	0.2525	71	5	7	2	3	8	0	-2	8	0	0	4.004062984616236	
i 1	479.48193877551023	0.2525	71	391	4	4	14	8	0	-2	8	0	0	4.004062984616236	
i 1	479.5108367346939	0.7575000000000001	74	391	3	3	15	8	0	-1	8	0	0	4.004062984616236	
i 1	479.51244217687076	0.505	68	391	3	20	15	1	0	-1	1	0	0	0.6150260291335998	
i 1	479.73755782312924	1.5150000000000001	71	391	1	24	14	1	0	0	1	0	0	4.6150260291336	
i 1	479.74558503401363	7.07	66	5	6	17	4	6	0	1	6	0	0	2.5046176726734664	
i 1	479.75441496598637	1.01	74	5	5	1	15	16	0	1	16	0	0	5.419419833319788	
i 1	479.7608367346939	0.2525	71	5	4	9	1	8	0	-1	8	0	0	3.004062984616236	
i 1	479.76244217687076	0.7575000000000001	71	5	4	9	8	2	0	-2	2	0	0	3.004062984616236	
i 1	479.76886394557823	0.2525	74	5	7	1	8	17	0	1	17	0	0	5.419419833319788	
i 1	479.98595238095237	0.2525	75	391	6	5	9	2	0	1	2	0	0	3.043848439455805	
i 1	479.98996598639457	0.7575000000000001	71	5	6	2	5	8	0	-2	8	0	0	4.004062984616236	
i 1	479.99397959183676	0.2525	74	391	3	24	16	16	0	1	16	0	0	6.419419833319788	
i 1	480.00040136054423	0.7575000000000001	74	701	4	24	6	17	5005	1	17	0	0	6.419419833319788	
i 1	480.00361224489797	0.2525	75	5	5	5	10	2	0	1	2	0	0	3.043848439455805	
i 1	480.00762585034016	1.2625	68	391	1	20	15	0	5005	0	0	0	0	0.6150260291335998	
i 1	480.01003401360543	0.2525	75	5	4	5	10	2	0	-2	2	0	0	3.043848439455805	
i 1	480.2520068027211	2.2725	72	701	5	5	5	2	5005	-2	2	0	0	3.043848439455805	
i 1	480.25441496598637	2.525	74	701	4	3	13	2	5005	-1	2	0	0	4.004062984616236	
i 1	480.48113605442177	0.2525	71	391	3	4	2	8	0	-2	8	0	0	4.004062984616236	
i 1	480.48193877551023	0.2525	68	5	2	24	2	1	0	-1	1	0	0	4.6150260291336	
i 1	480.50762585034016	0.505	74	5	7	1	5	17	0	1	17	0	0	5.419419833319788	
i 1	480.50762585034016	0.505	75	5	4	5	8	2	0	-2	2	0	0	3.043848439455805	
i 1	480.7343469387755	0.505	71	391	1	24	15	0	5005	0	0	0	0	4.6150260291336	
i 1	480.75040136054423	0.505	68	391	3	20	2	1	0	-1	1	0	0	0.6150260291335998	
i 1	480.75120408163264	0.2525	77	391	4	1	8	16	0	1	16	0	0	5.419419833319788	
i 1	480.75602040816324	2.02	74	5	7	1	8	16	0	2	16	0	0	5.419419833319788	
i 1	480.7608367346939	0.2525	74	391	3	3	7	8	0	-1	8	0	0	4.004062984616236	
i 1	480.99157142857143	0.505	75	5	5	5	6	2	0	1	2	0	0	3.043848439455805	
i 1	480.9931768707483	0.2525	68	5	2	20	1	1	0	-1	1	0	0	0.6150260291335998	
i 1	481.00602040816324	0.2525	72	391	3	5	7	8	0	1	8	0	0	3.043848439455805	
i 1	481.0068231292517	0.2525	71	5	2	20	3	0	0	-1	0	0	0	0.6150260291335998	
i 1	481.0164557823129	0.2525	74	5	5	1	12	16	0	2	16	0	0	5.419419833319788	
i 1	481.23193877551023	0.7575000000000001	68	391	2	20	5	1	0	0	1	0	0	0.6150260291335998	
i 1	481.23274149659863	5.555	66	5	5	12	3	6	0	0	6	0	0	5.217728500628025	
i 1	481.23274149659863	5.555	61	5	5	19	8	6	0	1	6	0	0	2.5046176726734664	
i 1	481.23595238095237	1.5150000000000001	61	391	4	16	1	6	0	1	6	0	0	5.217728500628025	
i 1	481.23675510204083	5.555	61	391	4	18	8	6	0	0	6	0	0	2.5046176726734664	
i 1	481.23996598639457	0.2525	68	391	2	20	3	1	0	-1	1	0	0	0.6150260291335998	
i 1	481.23996598639457	1.2625	68	5	1	24	7	0	0	-1	0	0	0	4.6150260291336	
i 1	481.24237414965984	5.555	66	5	5	19	8	9	0	0	9	0	0	2.5046176726734664	
i 1	481.24397959183676	1.5150000000000001	68	5	3	20	12	0	0	0	0	0	0	0.6150260291335998	
i 1	481.2479931972789	5.555	61	391	4	18	8	6	0	0	6	0	0	2.5046176726734664	
i 1	481.24879591836736	0.505	74	391	5	1	6	17	0	1	17	0	0	5.419419833319788	
i 1	481.25040136054423	0.2525	75	391	4	5	4	2	0	-2	2	0	0	3.043848439455805	
i 1	481.25120408163264	0.2525	68	391	2	20	7	0	0	-1	0	0	0	0.6150260291335998	
i 1	481.2528095238095	0.505	71	391	4	9	8	2	0	-2	2	0	0	3.004062984616236	
i 1	481.25762585034016	0.2525	72	5	6	5	8	2	0	-2	2	0	0	3.043848439455805	
i 1	481.25842857142857	0.2525	68	5	1	24	8	0	5005	-1	0	0	0	4.6150260291336	
i 1	481.26003401360543	0.7575000000000001	74	701	4	24	6	17	5005	1	17	0	0	6.419419833319788	
i 1	481.2656530612245	4.545	66	5	5	12	13	6	0	0	6	0	0	5.217728500628025	
i 1	481.26725850340137	0.2525	71	5	1	20	8	1	5005	0	1	0	0	0.6150260291335998	
i 1	481.48996598639457	0.7575000000000001	74	5	4	1	15	17	0	2	17	0	0	5.419419833319788	
i 1	481.73514965986396	0.2525	68	5	1	24	8	0	5005	0	0	0	0	4.6150260291336	
i 1	481.73755782312924	1.01	68	391	2	20	4	0	0	0	0	0	0	0.6150260291335998	
i 1	481.75602040816324	0.2525	71	391	2	20	10	1	0	0	1	0	0	0.6150260291335998	
i 1	481.75842857142857	0.505	74	5	7	2	16	2	0	-1	2	0	0	4.004062984616236	
i 1	481.75842857142857	1.7675	72	701	5	5	11	2	5005	1	2	0	0	3.043848439455805	
i 1	481.76806122448977	0.2525	74	5	3	24	13	16	0	2	16	0	0	6.419419833319788	
i 1	481.76806122448977	1.01	68	5	1	20	12	0	5005	-1	0	0	0	0.6150260291335998	
i 1	481.9803333333333	1.2625	71	5	6	2	7	8	0	-2	8	0	0	4.004062984616236	
i 1	481.98675510204083	0.505	77	391	5	1	5	16	0	1	16	0	0	5.419419833319788	
i 1	481.99397959183676	0.2525	72	5	3	5	14	2	0	1	2	0	0	3.043848439455805	
i 1	482.01244217687076	4.7975	72	5	5	5	7	2	0	-2	2	0	0	3.043848439455805	
i 1	482.01886394557823	0.2525	74	391	5	1	13	17	0	1	17	0	0	5.419419833319788	
i 1	482.24638775510203	0.505	68	391	2	20	15	1	0	0	1	0	0	0.6150260291335998	
i 1	482.25602040816324	3.535	74	701	4	24	8	17	5005	1	17	0	0	6.419419833319788	
i 1	482.2664557823129	0.505	74	701	5	1	10	16	5005	2	16	0	0	5.419419833319788	
i 1	482.49397959183676	0.2525	75	5	5	5	4	2	0	1	2	0	0	3.043848439455805	
i 1	482.50040136054423	0.2525	71	391	4	9	3	8	0	-1	8	0	0	3.004062984616236	
i 1	482.5116394557823	0.505	71	391	4	9	14	2	0	-2	2	0	0	3.004062984616236	
i 1	482.73113605442177	0.7575000000000001	74	701	6	1	14	16	5005	2	16	0	0	5.419419833319788	
i 1	482.7335442176871	0.2525	74	5	7	1	10	16	0	2	16	0	0	5.419419833319788	
i 1	482.73595238095237	2.525	74	701	5	3	8	2	5005	-1	2	0	0	4.004062984616236	
i 1	482.73595238095237	2.525	68	391	2	24	15	0	0	-1	0	0	0	6.287845002869841	
i 1	482.7383605442177	0.505	74	5	6	2	12	2	0	-1	2	0	0	4.004062984616236	
i 1	482.7391632653061	4.04	61	5	6	17	12	9	0	0	9	0	0	2.5046176726734664	
i 1	482.74237414965984	0.2525	75	391	5	5	10	2	0	-2	2	0	0	3.043848439455805	
i 1	482.74478231292517	0.2525	68	5	3	20	5	0	0	0	0	0	0	2.287845002869841	
i 1	482.74558503401363	0.2525	68	701	2	24	10	1	5005	0	1	0	0	6.287845002869841	
i 1	482.74879591836736	0.505	74	5	4	24	12	16	0	2	16	0	0	6.419419833319788	
i 1	482.7520068027211	0.505	68	5	1	20	13	0	0	0	0	0	0	2.287845002869841	
i 1	482.76003401360543	0.2525	68	701	2	20	2	0	5005	-1	0	0	0	2.287845002869841	
i 1	482.7616394557823	0.505	68	391	2	20	13	1	0	0	1	0	0	2.287845002869841	
i 1	482.98514965986396	1.5150000000000001	68	5	1	24	8	1	5005	-1	1	0	0	6.287845002869841	
i 1	482.99558503401363	0.2525	68	5	1	20	12	1	5005	-1	1	0	0	2.287845002869841	
i 1	483.0156530612245	0.2525	68	391	2	20	6	0	0	0	0	0	0	2.287845002869841	
i 1	483.23113605442177	0.505	74	5	7	1	3	17	0	1	17	0	0	5.419419833319788	
i 1	483.23193877551023	0.505	72	701	4	5	14	2	5005	-2	2	0	0	3.043848439455805	
i 1	483.2431768707483	0.7575000000000001	74	5	4	1	10	17	0	2	17	0	0	5.419419833319788	
i 1	483.25521768707483	0.2525	74	5	3	4	12	8	0	-1	8	0	0	4.004062984616236	
i 1	483.2608367346939	0.505	71	391	4	9	13	2	0	-2	2	0	0	3.004062984616236	
i 1	483.49558503401363	0.2525	71	5	6	2	15	8	0	-2	8	0	0	4.004062984616236	
i 1	483.51003401360543	0.7575000000000001	74	391	5	1	4	17	0	1	17	0	0	5.419419833319788	
i 1	483.73755782312924	1.5150000000000001	74	5	7	1	16	16	0	2	16	0	0	5.419419833319788	
i 1	483.7391632653061	0.2525	68	5	1	20	10	0	0	0	0	0	0	2.287845002869841	
i 1	483.74959863945577	0.2525	72	701	5	5	6	2	5005	1	2	0	0	3.043848439455805	
i 1	483.75120408163264	0.505	74	5	3	4	16	8	0	-1	8	0	0	4.004062984616236	
i 1	483.7656530612245	0.2525	68	5	1	24	12	0	0	-1	0	0	0	6.287845002869841	
i 1	483.7696666666667	0.2525	75	391	4	5	10	8	0	-2	8	0	0	3.043848439455805	
i 1	483.98193877551023	0.505	75	5	5	5	15	2	0	1	2	0	0	3.043848439455805	
i 1	484.00361224489797	2.02	72	701	4	5	9	2	5005	-2	2	0	0	3.043848439455805	
i 1	484.01404761904763	1.7675	74	701	4	4	7	8	5005	-1	8	0	0	4.004062984616236	
i 1	484.01404761904763	0.505	68	391	2	20	15	0	0	0	0	0	0	2.287845002869841	
i 1	484.0196666666667	1.2625	68	391	2	20	6	1	0	0	1	0	0	2.287845002869841	
i 1	484.2303333333333	0.2525	74	5	4	24	15	16	0	2	16	0	0	6.419419833319788	
i 1	484.23193877551023	0.2525	74	5	7	1	14	17	0	1	17	0	0	5.419419833319788	
i 1	484.24558503401363	0.2525	72	5	3	5	2	2	0	-2	2	0	0	3.043848439455805	
i 1	484.48193877551023	0.505	75	391	4	5	9	8	0	-2	8	0	0	3.043848439455805	
i 1	484.49397959183676	0.2525	77	391	5	1	3	16	0	1	16	0	0	5.419419833319788	
i 1	484.5020068027211	0.2525	71	701	2	24	14	1	5005	-1	1	0	0	6.287845002869841	
i 1	484.5028095238095	0.2525	74	5	4	1	13	17	0	2	17	0	0	5.419419833319788	
i 1	484.50842857142857	0.2525	68	5	3	20	11	1	0	-1	1	0	0	2.287845002869841	
i 1	484.73193877551023	0.505	68	5	1	24	16	1	5005	0	1	0	0	6.287845002869841	
i 1	484.75040136054423	0.2525	75	5	5	5	14	2	0	1	2	0	0	3.043848439455805	
i 1	484.7520068027211	2.02	68	5	1	24	6	0	0	-1	0	0	0	6.287845002869841	
i 1	484.76886394557823	0.505	71	391	2	20	6	1	0	0	1	0	0	2.287845002869841	
i 1	484.98113605442177	0.2525	75	391	5	5	2	2	0	-2	2	0	0	3.043848439455805	
i 1	485.00762585034016	1.7675	68	5	1	20	14	0	0	0	0	0	0	2.287845002869841	
i 1	485.00842857142857	0.505	71	391	4	9	4	8	0	-1	8	0	0	3.004062984616236	
i 1	485.01244217687076	0.2525	74	5	3	4	7	8	0	-1	8	0	0	4.004062984616236	
i 1	485.25361224489797	0.2525	72	5	3	5	9	2	0	-2	2	0	0	3.043848439455805	
i 1	485.25521768707483	0.2525	68	701	2	20	13	0	5005	-1	0	0	0	2.287845002869841	
i 1	485.25762585034016	0.2525	71	701	2	24	3	1	5005	0	1	0	0	6.287845002869841	
i 1	485.26003401360543	0.505	74	5	4	24	7	16	0	2	16	0	0	6.419419833319788	
i 1	485.26003401360543	0.505	72	5	3	5	1	2	0	1	2	0	0	3.043848439455805	
i 1	485.2616394557823	0.2525	71	5	3	20	9	1	0	-1	1	0	0	2.287845002869841	
i 1	485.26324489795917	0.2525	77	391	5	1	6	16	0	1	16	0	0	5.419419833319788	
i 1	485.26886394557823	0.505	74	701	6	1	7	16	5005	2	16	0	0	5.419419833319788	
i 1	485.48274149659863	0.505	71	5	1	24	6	0	5005	-1	0	0	0	6.287845002869841	
i 1	485.4835442176871	1.2625	68	391	2	20	6	1	0	0	1	0	0	2.287845002869841	
i 1	485.48514965986396	0.505	74	5	7	1	10	16	0	2	16	0	0	5.419419833319788	
i 1	485.48514965986396	0.2525	71	391	4	9	5	2	0	-2	2	0	0	3.004062984616236	
i 1	485.49397959183676	1.2625	71	5	1	20	9	1	5005	0	1	0	0	2.287845002869841	
i 1	485.49558503401363	0.2525	74	701	5	3	14	2	5005	-1	2	0	0	4.004062984616236	
i 1	485.50842857142857	0.505	74	5	3	4	10	8	0	-1	8	0	0	4.004062984616236	
i 1	485.7335442176871	0.2525	74	391	5	1	11	17	0	1	17	0	0	5.419419833319788	
i 1	485.7335442176871	1.01	66	701	5	17	8	6	5005	1	6	0	0	2.5046176726734664	
i 1	485.73595238095237	1.01	75	5	5	5	13	2	0	1	2	0	0	3.043848439455805	
i 1	485.73996598639457	1.01	74	701	4	4	7	8	5005	-1	8	0	0	4.004062984616236	
i 1	485.74076870748297	1.01	74	701	4	24	13	17	5005	1	17	0	0	6.419419833319788	
i 1	485.74397959183676	0.7575000000000001	71	5	3	3	4	8	0	-2	8	0	0	4.004062984616236	
i 1	485.75361224489797	0.505	71	5	6	2	6	8	0	-2	8	0	0	4.004062984616236	
i 1	485.75923129251703	0.2525	72	701	4	5	12	2	5005	1	2	0	0	3.043848439455805	
i 1	485.9803333333333	0.2525	74	5	4	24	5	16	0	2	16	0	0	6.419419833319788	
i 1	485.99076870748297	0.7575000000000001	74	701	6	1	11	16	5005	2	16	0	0	5.419419833319788	
i 1	486.0020068027211	0.505	71	391	4	9	4	2	0	-2	2	0	0	3.004062984616236	
i 1	486.00762585034016	0.2525	74	5	4	1	2	17	0	2	17	0	0	5.419419833319788	
i 1	486.00842857142857	0.2525	72	5	3	5	9	2	0	1	2	0	0	3.043848439455805	
i 1	486.0116394557823	0.2525	75	391	5	5	2	2	0	-2	2	0	0	3.043848439455805	
i 1	486.24558503401363	0.505	74	5	6	2	9	2	0	-1	2	0	0	4.004062984616236	
i 1	486.26886394557823	0.505	74	5	7	1	6	16	0	2	16	0	0	5.419419833319788	
i 1	486.48193877551023	0.2525	74	5	4	24	10	16	0	2	16	0	0	6.419419833319788	
i 1	486.48274149659863	0.2525	68	391	2	20	12	0	0	-1	0	0	0	2.287845002869841	
i 1	486.49076870748297	0.2525	71	391	4	9	12	8	0	-1	8	0	0	3.004062984616236	
i 1	486.50521768707483	0.2525	68	391	2	20	16	1	0	0	1	0	0	2.287845002869841	
i 1	486.51003401360543	0.2525	71	5	1	24	5	0	5005	-1	0	0	0	6.287845002869841	
i 1	486.73113605442177	1.5150000000000001	74	204	5	5	16	8	0	-2	8	0	0	6.0	
i 1	486.73193877551023	0.2525	77	1088	4	4	1	16	0	2	16	0	0	4.0	
i 1	486.7383605442177	0.505	75	204	5	1	8	2	0	1	2	0	0	10.0	
i 1	486.7383605442177	0.2525	71	204	5	5	2	8	0	-1	8	0	0	6.0	
i 1	486.7383605442177	3.0300000000000002	63	204	3	14	8	16	0	2	16	0	0	6.513827711769258	
i 1	486.73996598639457	1.5150000000000001	77	204	7	2	12	17	0	1	17	0	0	4.0	
i 1	486.7431768707483	12.625	61	204	7	17	4	16	0	1	16	0	0	0.5009235345346933	
i 1	486.7479931972789	0.2525	74	702	4	5	12	2	0	-2	2	0	0	6.0	
i 1	486.74959863945577	1.01	72	204	4	1	7	2	0	-2	2	0	0	10.0	
i 1	486.75762585034016	0.2525	73	702	3	24	15	16	0	2	16	0	0	4.0	
i 1	486.7664557823129	3.0300000000000002	61	204	4	14	5	16	0	2	16	0	0	6.513827711769258	
i 1	486.76886394557823	6.0600000000000005	63	1088	3	13	7	1	0	2	1	0	0	2.605531084707703	
i 1	486.7696666666667	9.09	61	1088	4	7	7	16	0	1	16	0	0	5.211062169415406	
i 1	486.98755782312924	0.2525	77	702	5	9	14	17	0	2	17	0	0	3.0	
i 1	487.01244217687076	0.2525	74	702	4	4	5	16	0	1	16	0	0	4.0	
i 1	487.01404761904763	0.2525	71	702	4	5	9	8	0	-1	8	0	0	6.0	
i 1	487.24879591836736	0.505	77	1088	4	4	2	16	0	2	16	0	0	4.0	
i 1	487.2520068027211	0.2525	77	702	5	9	15	17	0	1	17	0	0	3.0	
i 1	487.2568231292517	0.2525	75	702	5	1	4	8	0	-2	8	0	0	10.0	
i 1	487.49076870748297	2.2725	75	204	5	1	15	2	0	1	2	0	0	10.0	
i 1	487.74157142857143	0.2525	77	702	5	9	13	17	0	1	17	0	0	3.0	
i 1	487.7471904761905	0.2525	72	702	5	1	14	2	0	1	2	0	0	10.0	
i 1	487.76244217687076	0.2525	77	702	5	9	12	17	0	2	17	0	0	3.0	
i 1	487.7664557823129	0.2525	71	1088	4	5	2	8	0	-1	8	0	0	6.0	
i 1	487.76886394557823	1.2625	73	702	3	24	12	16	0	2	16	0	0	4.0	
i 1	487.99157142857143	0.2525	72	1088	4	24	15	8	0	1	8	0	0	11.0	
i 1	488.00361224489797	0.505	77	1088	4	4	10	16	0	2	16	0	0	4.0	
i 1	488.01003401360543	0.505	71	204	5	5	7	8	0	-1	8	0	0	6.0	
i 1	488.24638775510203	1.5150000000000001	77	204	6	2	7	16	0	2	16	0	0	4.0	
i 1	488.2664557823129	0.2525	71	1088	4	5	1	2	0	-2	2	0	0	6.0	
i 1	488.49879591836736	0.505	74	204	5	5	16	8	0	-2	8	0	0	6.0	
i 1	488.50602040816324	0.2525	72	1088	4	1	15	2	0	1	2	0	0	10.0	
i 1	488.50602040816324	1.01	73	702	3	24	12	16	0	2	16	0	0	4.0	
i 1	488.51003401360543	0.2525	74	702	4	4	8	16	0	1	16	0	0	4.0	
i 1	488.51244217687076	1.7675	71	1088	4	5	4	8	0	-1	8	0	0	6.0	
i 1	488.51404761904763	0.2525	72	702	5	1	5	2	0	1	2	0	0	10.0	
i 1	488.74478231292517	0.7575000000000001	72	1088	4	24	16	8	0	1	8	0	0	11.0	
i 1	488.7528095238095	0.2525	77	1088	4	4	4	16	0	2	16	0	0	4.0	
i 1	488.99478231292517	0.2525	74	702	4	5	5	2	0	-2	2	0	0	6.0	
i 1	489.01324489795917	0.7575000000000001	73	702	1	24	11	16	0	252	16	307	0	4.0	
i 1	489.2528095238095	0.2525	71	204	5	5	14	8	0	-1	8	0	0	6.0	
i 1	489.26725850340137	1.2625	72	1088	4	1	6	2	0	1	2	0	0	10.0	
i 1	489.75842857142857	2.2725	72	204	7	1	8	2	0	-2	2	0	0	10.0	
i 1	489.76003401360543	1.2625	76	702	2	20	3	16	0	1	16	0	0	0.7914432566067586	
i 1	489.7608367346939	9.595	63	204	7	17	5	1	0	1	1	0	0	0.5009235345346933	
i 1	489.76485034013604	3.0300000000000002	63	204	4	14	2	16	0	2	16	0	0	6.513827711769258	
i 1	489.7656530612245	1.2625	76	702	3	20	12	16	0	1	16	0	0	0.7914432566067586	
i 1	489.76725850340137	9.09	61	204	6	14	8	16	0	2	16	0	0	6.513827711769258	
i 1	489.98113605442177	0.2525	72	1088	4	24	16	8	0	1	8	0	0	11.0	
i 1	489.98274149659863	1.2625	74	204	7	5	15	8	0	-2	8	0	0	6.0	
i 1	489.99638775510203	0.2525	71	1088	4	5	8	2	0	-2	2	0	0	6.0	
i 1	490.00441496598637	1.7675	77	1088	5	3	8	16	0	1	16	0	0	4.0	
i 1	490.00521768707483	0.2525	77	702	5	9	16	17	0	1	17	0	0	3.0	
i 1	490.2335442176871	0.505	71	702	4	5	15	8	0	-1	8	0	0	6.0	
i 1	490.2431768707483	0.2525	76	702	1	20	3	16	0	1	16	0	0	0.7914432566067586	
i 1	490.25441496598637	0.2525	75	204	4	1	6	2	0	1	2	0	0	10.0	
i 1	490.26886394557823	0.505	77	204	7	2	3	16	0	2	16	0	0	4.0	
i 1	490.50361224489797	0.505	77	702	5	3	6	17	0	1	17	0	0	4.0	
i 1	490.7335442176871	0.2525	71	1088	4	5	16	2	0	-2	2	0	0	6.0	
i 1	490.74397959183676	0.2525	75	702	4	24	12	2	0	1	2	0	0	11.0	
i 1	490.75441496598637	0.2525	75	702	4	1	14	8	0	-2	8	0	0	10.0	
i 1	490.76806122448977	0.2525	74	702	4	5	12	2	0	-2	2	0	0	6.0	
i 1	490.9835442176871	0.505	72	1088	4	1	2	2	0	1	2	0	0	10.0	
i 1	491.0020068027211	0.505	71	702	4	5	4	8	0	-1	8	0	0	6.0	
i 1	491.00361224489797	0.2525	77	702	5	9	6	17	0	1	17	0	0	3.0	
i 1	491.00923129251703	1.7675	73	702	3	20	9	16	0	2	16	0	0	0.7914432566067586	
i 1	491.01324489795917	1.2625	76	702	1	24	1	17	0	1	17	0	0	4.791443256606758	
i 1	491.24157142857143	1.5150000000000001	71	204	5	5	10	8	0	-1	8	0	0	6.0	
i 1	491.25040136054423	2.2725	77	204	7	2	8	17	0	1	17	0	0	4.0	
i 1	491.49638775510203	0.2525	75	702	4	24	5	2	0	1	2	0	0	11.0	
i 1	491.51485034013604	0.505	71	702	4	5	1	8	0	-1	8	0	0	6.0	
i 1	491.74959863945577	0.2525	77	1088	4	4	8	16	0	2	16	0	0	4.0	
i 1	491.75040136054423	0.505	75	702	4	1	13	2	0	1	2	0	0	10.0	
i 1	491.75842857142857	1.01	75	204	4	1	5	2	0	1	2	0	0	10.0	
i 1	491.98193877551023	0.2525	74	702	4	4	1	16	0	1	16	0	0	4.0	
i 1	491.9971904761905	0.2525	71	1088	4	5	9	2	0	-2	2	0	0	6.0	
i 1	491.9971904761905	0.505	71	702	4	5	4	8	0	-1	8	0	0	6.0	
i 1	492.23113605442177	0.2525	74	702	4	5	2	2	0	-2	2	0	0	6.0	
i 1	492.2479931972789	1.2625	72	1088	4	24	10	8	0	1	8	0	0	11.0	
i 1	492.25842857142857	0.505	73	1088	1	20	5	17	0	2	17	0	0	0.7914432566067586	
i 1	492.48514965986396	0.2525	73	204	3	20	2	16	0	1	16	0	0	0.7914432566067586	
i 1	492.7335442176871	1.01	76	702	2	20	13	16	0	2	16	0	0	0.7914432566067586	
i 1	492.7343469387755	1.01	73	702	3	24	2	16	0	2	16	0	0	4.791443256606758	
i 1	492.75602040816324	0.2525	75	702	4	1	11	8	0	-2	8	0	0	10.0	
i 1	492.76003401360543	6.565	61	1088	6	17	5	1	0	2	1	0	0	0.5009235345346933	
i 1	492.7616394557823	6.565	63	204	6	14	12	16	0	2	16	0	0	6.513827711769258	
i 1	492.7664557823129	1.5150000000000001	71	1088	4	5	15	8	0	-1	8	0	0	6.0	
i 1	492.76725850340137	3.0300000000000002	63	1088	3	13	1	1	0	2	1	0	0	2.605531084707703	
i 1	492.76806122448977	0.2525	75	702	4	24	2	2	0	1	2	0	0	11.0	
i 1	492.9803333333333	0.2525	75	702	4	1	3	2	0	1	2	0	0	10.0	
i 1	493.00762585034016	1.01	77	204	7	2	8	16	0	2	16	0	0	4.0	
i 1	493.00923129251703	0.2525	72	204	7	1	9	2	0	-2	2	0	0	10.0	
i 1	493.0108367346939	0.2525	77	702	5	9	8	17	0	2	17	0	0	3.0	
i 1	493.01886394557823	0.2525	76	702	3	20	5	16	0	1	16	0	0	0.7914432566067586	
i 1	493.24397959183676	0.2525	74	702	4	5	2	2	0	-2	2	0	0	6.0	
i 1	493.25602040816324	0.2525	72	702	6	1	9	2	0	1	2	0	0	10.0	
i 1	493.25842857142857	0.2525	73	702	3	24	11	16	0	2	16	0	0	4.791443256606758	
i 1	493.2656530612245	1.7675	72	1088	3	1	1	2	0	1	2	0	0	10.0	
i 1	493.48675510204083	0.505	74	204	7	5	7	8	0	-2	8	0	0	6.0	
i 1	493.49879591836736	0.2525	77	702	5	9	13	17	0	1	17	0	0	3.0	
i 1	493.5068231292517	1.2625	73	702	1	24	11	16	0	252	16	307	0	4.791443256606758	
i 1	493.51404761904763	0.505	75	204	7	1	6	2	0	1	2	0	0	10.0	
i 1	493.73113605442177	0.2525	72	702	4	1	4	2	0	1	2	0	0	10.0	
i 1	493.7383605442177	0.2525	76	1088	2	20	3	16	0	2	16	0	0	0.7914432566067586	
i 1	493.7431768707483	1.01	73	702	3	20	6	16	0	2	16	0	0	0.7914432566067586	
i 1	493.7528095238095	1.7675	77	1088	4	4	14	16	0	2	16	0	0	4.0	
i 1	493.75441496598637	0.2525	71	702	4	5	6	8	0	-1	8	0	0	6.0	
i 1	493.76324489795917	0.2525	74	702	4	4	11	16	0	1	16	0	0	4.0	
i 1	493.98514965986396	0.505	76	702	1	24	10	17	0	2	17	0	0	4.791443256606758	
i 1	493.99638775510203	0.7575000000000001	77	702	5	3	13	17	0	1	17	0	0	4.0	
i 1	494.00361224489797	0.505	76	702	2	20	6	17	0	2	17	0	0	0.7914432566067586	
i 1	494.01003401360543	0.7575000000000001	71	1088	4	5	6	2	0	-2	2	0	0	6.0	
i 1	494.01725850340137	0.2525	75	702	4	24	15	2	0	1	2	0	0	11.0	
i 1	494.2383605442177	0.2525	75	702	4	1	16	8	0	-2	8	0	0	10.0	
i 1	494.24397959183676	0.2525	71	702	4	5	11	8	0	-1	8	0	0	6.0	
i 1	494.25441496598637	0.2525	71	204	7	5	2	8	0	-1	8	0	0	6.0	
i 1	494.2656530612245	0.2525	75	204	7	1	11	2	0	1	2	0	0	10.0	
i 1	494.48274149659863	0.2525	76	1088	1	24	4	17	0	2	17	0	0	4.791443256606758	
i 1	494.4843469387755	0.7575000000000001	72	204	7	1	4	2	0	-2	2	0	0	10.0	
i 1	494.4883605442177	0.2525	74	702	4	5	15	2	0	-2	2	0	0	6.0	
i 1	494.49558503401363	0.7575000000000001	73	702	3	24	10	16	0	2	16	0	0	4.791443256606758	
i 1	494.4971904761905	1.7675	74	204	7	5	14	8	0	-2	8	0	0	6.0	
i 1	494.50521768707483	0.2525	76	1088	2	20	1	17	0	1	17	0	0	0.7914432566067586	
i 1	494.51003401360543	0.2525	77	702	5	9	4	17	0	1	17	0	0	3.0	
i 1	494.7471904761905	0.2525	77	204	7	2	8	17	0	1	17	0	0	4.0	
i 1	494.7616394557823	0.505	73	702	2	20	11	16	0	1	16	0	0	0.7914432566067586	
i 1	494.76244217687076	0.2525	73	702	1	24	9	16	0	2	16	0	0	4.791443256606758	
i 1	494.99397959183676	0.505	75	702	4	24	16	2	0	1	2	0	0	11.0	
i 1	495.0116394557823	0.2525	75	702	4	1	15	2	0	1	2	0	0	10.0	
i 1	495.23675510204083	0.7575000000000001	75	204	7	1	16	2	0	1	2	0	0	10.0	
i 1	495.2471904761905	0.2525	76	1088	2	20	2	17	0	2	17	0	0	0.7914432566067586	
i 1	495.2528095238095	1.7675	77	1088	5	3	10	16	0	1	16	0	0	4.0	
i 1	495.25842857142857	0.505	73	702	3	20	8	16	0	2	16	0	0	0.7914432566067586	
i 1	495.4803333333333	0.2525	73	702	1	24	5	16	0	2	16	0	0	4.791443256606758	
i 1	495.4971904761905	0.2525	71	1088	4	5	15	2	0	-2	2	0	0	6.0	
i 1	495.4979931972789	0.2525	72	1088	3	1	10	2	0	1	2	0	0	10.0	
i 1	495.5020068027211	0.2525	76	702	2	20	10	16	0	2	16	0	0	0.7914432566067586	
i 1	495.50923129251703	1.01	71	204	7	5	4	8	0	-1	8	0	0	6.0	
i 1	495.5156530612245	0.2525	73	702	2	20	8	17	0	1	17	0	0	0.7914432566067586	
i 1	495.7343469387755	3.535	63	1088	6	17	7	16	0	1	16	0	0	0.5009235345346933	
i 1	495.73996598639457	0.2525	77	702	5	9	16	17	0	1	17	0	0	3.0	
i 1	495.74237414965984	3.0300000000000002	61	1088	4	7	15	16	0	1	16	0	0	5.211062169415406	
i 1	495.7471904761905	0.2525	72	204	7	1	9	2	0	-2	2	0	0	10.0	
i 1	495.7568231292517	3.535	63	1088	5	13	7	1	0	2	1	0	0	2.605531084707703	
i 1	495.7616394557823	0.2525	77	1088	4	4	11	16	0	2	16	0	0	4.0	
i 1	495.9803333333333	1.5150000000000001	72	1088	3	24	1	8	0	1	8	0	0	11.0	
i 1	495.99237414965984	1.2625	71	1088	4	5	6	8	0	-1	8	0	0	6.0	
i 1	495.99397959183676	0.505	77	702	5	3	14	17	0	1	17	0	0	4.0	
i 1	496.0028095238095	0.505	75	702	4	1	14	2	0	1	2	0	0	10.0	
i 1	496.26404761904763	0.2525	73	702	3	20	6	16	0	2	16	0	0	0.6335246007848028	
i 1	496.4883605442177	0.2525	74	702	4	5	4	2	0	-1	2	0	0	6.0	
i 1	496.48996598639457	2.525	76	702	2	20	13	16	0	1	16	0	0	0.6335246007848028	
i 1	496.4931768707483	0.2525	74	204	7	5	10	8	0	-2	8	0	0	6.0	
i 1	496.49397959183676	0.7575000000000001	76	702	1	24	4	16	0	252	16	307	0	4.633524600784803	
i 1	496.5028095238095	2.2725	73	702	1	24	12	16	0	2	16	0	0	4.633524600784803	
i 1	496.51003401360543	0.2525	75	204	7	1	11	2	0	1	2	0	0	10.0	
i 1	496.5108367346939	0.7575000000000001	77	204	7	2	14	17	0	1	17	0	0	4.0	
i 1	496.5116394557823	0.2525	75	702	4	1	11	8	0	-2	8	0	0	10.0	
i 1	496.73193877551023	0.2525	76	702	2	20	10	17	0	1	17	0	0	0.6335246007848028	
i 1	496.73595238095237	0.2525	71	1088	6	5	12	2	0	-2	2	0	0	6.0	
i 1	496.75040136054423	0.2525	75	702	4	24	5	2	0	1	2	0	0	11.0	
i 1	496.99558503401363	0.505	74	702	4	4	12	16	0	1	16	0	0	4.0	
i 1	496.9971904761905	2.02	77	204	7	2	7	16	0	2	16	0	0	4.0	
i 1	497.0068231292517	1.7675	72	1088	6	1	12	2	0	1	2	0	0	10.0	
i 1	497.2343469387755	0.2525	75	702	4	1	1	2	0	1	2	0	0	10.0	
i 1	497.2383605442177	1.7675	71	1088	6	5	5	2	0	-2	2	0	0	6.0	
i 1	497.24879591836736	0.7575000000000001	77	1088	5	3	1	16	0	1	16	0	0	4.0	
i 1	497.25120408163264	0.2525	76	702	2	24	5	16	0	2	16	0	0	4.633524600784803	
i 1	497.49558503401363	1.5150000000000001	76	702	1	24	5	16	0	252	16	307	0	4.633524600784803	
i 1	497.4979931972789	1.2625	72	204	7	1	9	2	0	-2	2	0	0	10.0	
i 1	497.7479931972789	0.2525	77	702	5	9	11	17	0	1	17	0	0	3.0	
i 1	497.7520068027211	0.505	71	702	4	5	16	8	0	-1	8	0	0	6.0	
i 1	497.9835442176871	0.2525	77	204	7	2	4	17	0	1	17	0	0	4.0	
i 1	498.24076870748297	0.2525	75	702	4	24	12	2	0	1	2	0	0	11.0	
i 1	498.24478231292517	0.2525	77	702	5	3	8	17	0	1	17	0	0	4.0	
i 1	498.4891632653061	0.2525	71	702	4	5	5	8	0	-1	8	0	0	6.0	
i 1	498.49638775510203	0.505	73	702	2	20	6	17	0	1	17	0	0	0.6335246007848028	
i 1	498.50521768707483	0.7575000000000001	77	1088	4	4	4	16	0	2	16	0	0	4.0	
i 1	498.74397959183676	0.505	63	702	4	18	3	16	0	1	16	0	0	0.5009235345346933	
i 1	498.74397959183676	0.505	61	204	5	14	13	16	0	2	16	0	0	6.513827711769258	
i 1	498.74478231292517	0.505	77	204	7	2	8	17	0	1	17	0	0	4.0	
i 1	498.74638775510203	0.505	74	204	7	5	12	8	0	-2	8	0	0	6.0	
i 1	498.74638775510203	0.2525	73	702	2	24	4	16	0	2	16	0	0	4.633524600784803	
i 1	498.74959863945577	0.505	61	1088	5	7	13	16	0	1	16	0	0	5.211062169415406	
i 1	498.75361224489797	0.2525	76	702	1	20	12	16	0	1	16	0	0	0.6335246007848028	
i 1	498.75441496598637	0.2525	72	702	4	1	10	2	0	1	2	0	0	10.0	
i 1	498.7568231292517	0.2525	76	702	2	20	6	17	0	1	17	0	0	0.6335246007848028	
i 1	498.76244217687076	0.505	73	702	3	20	11	16	0	2	16	0	0	0.6335246007848028	
i 1	498.76886394557823	0.505	72	204	4	1	4	2	0	-2	2	0	0	10.0	
i 1	498.9835442176871	0.2525	75	702	4	24	5	2	0	1	2	0	0	11.0	
i 1	498.99076870748297	0.2525	73	1088	2	20	14	16	0	1	16	0	0	0.6335246007848028	
i 1	499.00361224489797	0.2525	72	1088	4	24	3	8	0	1	8	0	0	11.0	
i 1	499.0116394557823	0.2525	71	1088	6	5	4	8	0	-1	8	0	0	6.0	
i 1	499.01324489795917	0.2525	77	702	5	3	16	17	0	1	17	0	0	4.0	
i 1	499.23595238095237	5.555	63	702	6	17	16	16	0	2	16	0	0	0.5009235345346933	
i 1	499.23595238095237	0.2525	74	702	6	5	7	8	0	-1	8	0	0	6.0	
i 1	499.23595238095237	0.2525	74	386	6	5	13	8	0	-1	8	0	0	6.0	
i 1	499.2383605442177	12.625	63	1088	4	18	15	1	0	2	1	0	0	0.5009235345346933	
i 1	499.23996598639457	0.505	74	1088	5	9	6	16	0	1	16	0	0	3.0	
i 1	499.24076870748297	7.07	63	386	6	17	16	1	0	2	1	0	0	0.5009235345346933	
i 1	499.24076870748297	7.07	61	386	6	7	4	1	0	2	1	0	0	5.211062169415406	
i 1	499.24157142857143	7.07	61	386	6	17	13	16	0	2	16	0	0	0.5009235345346933	
i 1	499.2431768707483	1.2625	76	386	2	20	8	17	0	1	17	0	0	0.6335246007848028	
i 1	499.2479931972789	2.525	61	702	5	14	10	1	0	2	1	0	0	6.513827711769258	
i 1	499.25120408163264	5.555	63	386	5	13	11	1	0	2	1	0	0	2.605531084707703	
i 1	499.25361224489797	1.7675	72	386	4	24	13	8	0	1	8	0	0	11.0	
i 1	499.25762585034016	2.525	61	702	6	17	13	16	0	2	16	0	0	0.5009235345346933	
i 1	499.26003401360543	12.625	61	702	5	14	1	16	0	1	16	0	0	6.513827711769258	
i 1	499.26485034013604	1.01	74	702	6	2	11	17	0	2	17	0	0	4.0	
i 1	499.2656530612245	0.505	76	386	3	24	12	16	0	2	16	0	0	4.633524600784803	
i 1	499.4803333333333	0.2525	74	386	5	3	8	17	0	1	17	0	0	4.0	
i 1	499.49237414965984	0.2525	74	386	4	5	4	2	0	-1	2	0	0	6.0	
i 1	499.50441496598637	0.2525	75	386	6	1	8	2	0	1	2	0	0	10.0	
i 1	499.51485034013604	1.7675	74	386	6	5	3	8	0	-1	8	0	0	6.0	
i 1	499.51886394557823	0.505	72	1088	3	1	2	2	0	-2	2	0	0	10.0	
i 1	499.7335442176871	2.02	77	702	6	2	12	17	0	1	17	0	0	4.0	
i 1	499.73675510204083	0.505	75	386	4	24	15	2	0	1	2	0	0	11.0	
i 1	499.74638775510203	1.5150000000000001	76	386	1	24	6	16	0	2	16	0	0	4.633524600784803	
i 1	499.75842857142857	0.7575000000000001	74	702	6	5	14	8	0	-1	8	0	0	6.0	
i 1	499.7656530612245	0.505	71	386	4	5	9	8	0	-2	8	0	0	6.0	
i 1	499.76886394557823	0.2525	74	386	4	4	14	16	0	1	16	0	0	4.0	
i 1	500.2431768707483	0.2525	75	702	6	1	3	2	0	-2	2	0	0	10.0	
i 1	500.2431768707483	0.2525	77	386	5	3	6	16	0	2	16	0	0	4.0	
i 1	500.2608367346939	0.2525	74	1088	5	9	12	16	0	1	16	0	0	3.0	
i 1	500.2608367346939	0.2525	76	1088	2	20	7	17	0	2	17	0	0	0.6335246007848028	
i 1	500.2656530612245	0.2525	71	702	6	5	1	8	0	-1	8	0	0	6.0	
i 1	500.48514965986396	1.5150000000000001	76	1088	2	24	10	17	0	2	17	0	0	4.633524600784803	
i 1	500.48996598639457	0.7575000000000001	75	386	6	1	14	2	0	1	2	0	0	10.0	
i 1	500.5164557823129	0.2525	74	386	4	5	13	2	0	-1	2	0	0	6.0	
i 1	500.51725850340137	0.505	73	702	3	20	8	16	0	2	16	0	0	0.6335246007848028	
i 1	500.5196666666667	0.2525	72	1088	3	1	5	2	0	-2	2	0	0	10.0	
i 1	500.5196666666667	0.505	74	1088	5	9	5	17	0	1	17	0	0	3.0	
i 1	500.7528095238095	0.2525	73	702	3	20	5	16	0	2	16	0	0	0.6335246007848028	
i 1	500.7568231292517	1.5150000000000001	72	702	4	1	13	8	0	-2	8	0	0	10.0	
i 1	500.7696666666667	0.7575000000000001	71	702	6	5	6	8	0	-1	8	0	0	6.0	
i 1	500.99959863945577	0.2525	71	1088	4	5	3	2	0	-1	2	0	0	6.0	
i 1	501.00361224489797	0.2525	73	1088	2	20	9	16	0	2	16	0	0	0.6335246007848028	
i 1	501.0116394557823	0.2525	74	386	4	4	7	16	0	1	16	0	0	4.0	
i 1	501.01404761904763	0.7575000000000001	76	1088	2	20	6	16	0	2	16	0	0	0.6335246007848028	
i 1	501.23274149659863	0.2525	72	386	4	24	15	8	0	1	8	0	0	11.0	
i 1	501.23675510204083	0.505	71	386	4	5	13	8	0	-2	8	0	0	6.0	
i 1	501.25842857142857	0.7575000000000001	77	386	5	3	7	16	0	2	16	0	0	4.0	
i 1	501.2608367346939	1.01	74	702	6	5	5	8	0	-1	8	0	0	6.0	
i 1	501.2696666666667	0.2525	73	386	3	20	9	16	0	2	16	0	0	0.6335246007848028	
i 1	501.4883605442177	3.2825	76	386	1	24	10	16	0	2	16	0	0	4.633524600784803	
i 1	501.49478231292517	0.2525	75	702	6	1	12	2	0	-2	2	0	0	10.0	
i 1	501.5156530612245	0.2525	71	1088	4	5	4	2	0	-2	2	0	0	6.0	
i 1	501.5156530612245	0.7575000000000001	76	386	2	20	12	17	0	1	17	0	0	0.6335246007848028	
i 1	501.5164557823129	0.2525	72	1088	3	1	16	2	0	-2	2	0	0	10.0	
i 1	501.73113605442177	10.1	61	702	5	14	14	1	0	2	1	0	0	6.513827711769258	
i 1	501.7335442176871	10.1	63	1088	4	18	5	1	0	2	1	0	0	0.5009235345346933	
i 1	501.74879591836736	0.2525	71	1088	6	5	15	2	0	-2	2	0	0	6.0	
i 1	501.75040136054423	2.02	75	702	4	1	14	2	0	-2	2	0	0	10.0	
i 1	501.75040136054423	1.7675	74	386	4	4	6	16	0	1	16	0	0	4.0	
i 1	501.76244217687076	9.09	61	702	6	17	8	16	0	2	16	0	0	0.5009235345346933	
i 1	501.98113605442177	0.2525	74	386	4	4	12	16	0	1	16	0	0	4.0	
i 1	502.00361224489797	0.2525	75	386	6	1	3	2	0	1	2	0	0	10.0	
i 1	502.00441496598637	0.7575000000000001	73	386	3	20	9	16	0	2	16	0	0	0.6335246007848028	
i 1	502.23514965986396	0.2525	74	1088	5	9	7	16	0	1	16	0	0	3.0	
i 1	502.2383605442177	0.2525	76	702	3	20	14	17	0	1	17	0	0	0.6335246007848028	
i 1	502.2391632653061	0.2525	75	386	4	24	14	2	0	1	2	0	0	11.0	
i 1	502.2431768707483	1.7675	74	386	6	5	1	8	0	-1	8	0	0	6.0	
i 1	502.2471904761905	0.2525	76	386	3	20	8	17	0	1	17	0	0	0.6335246007848028	
i 1	502.25120408163264	0.2525	72	1088	6	1	9	2	0	-2	2	0	0	10.0	
i 1	502.2568231292517	0.505	76	1088	2	24	14	17	0	2	17	0	0	4.633524600784803	
i 1	502.5068231292517	0.2525	73	1088	2	20	12	17	0	2	17	0	0	0.6335246007848028	
i 1	502.50762585034016	0.2525	73	1088	2	20	5	16	0	2	16	0	0	0.6335246007848028	
i 1	502.50923129251703	0.2525	76	386	2	20	16	17	0	1	17	0	0	0.6335246007848028	
i 1	502.76886394557823	0.2525	77	702	6	2	6	17	0	1	17	0	0	4.0	
i 1	502.99157142857143	1.7675	76	386	2	20	16	17	0	1	17	0	0	0.6335246007848028	
i 1	502.9979931972789	0.7575000000000001	77	386	5	3	1	16	0	2	16	0	0	4.0	
i 1	502.99959863945577	0.2525	75	1088	3	1	13	2	0	-2	2	0	0	10.0	
i 1	503.00120408163264	0.2525	73	1088	2	20	15	17	0	1	17	0	0	0.6335246007848028	
i 1	503.01404761904763	1.2625	72	386	4	24	14	8	0	1	8	0	0	11.0	
i 1	503.0156530612245	2.525	74	702	6	2	12	17	0	2	17	0	0	4.0	
i 1	503.2303333333333	0.2525	74	386	4	5	8	2	0	-1	2	0	0	6.0	
i 1	503.50040136054423	2.02	74	386	6	5	12	8	0	-1	8	0	0	6.0	
i 1	503.51404761904763	0.2525	76	1088	2	24	10	17	0	2	17	0	0	4.633524600784803	
i 1	503.5156530612245	0.2525	74	1088	5	9	8	17	0	1	17	0	0	3.0	
i 1	503.5196666666667	0.2525	75	386	4	24	2	2	0	1	2	0	0	11.0	
i 1	503.74237414965984	1.01	75	386	6	1	7	2	0	1	2	0	0	10.0	
i 1	503.75441496598637	0.2525	74	386	4	5	11	2	0	-1	2	0	0	6.0	
i 1	503.75602040816324	0.2525	74	1088	5	9	2	16	0	1	16	0	0	3.0	
i 1	503.99959863945577	0.2525	71	386	4	5	6	8	0	-2	8	0	0	6.0	
i 1	504.0028095238095	0.2525	74	702	6	5	15	8	0	-1	8	0	0	6.0	
i 1	504.23675510204083	0.2525	72	386	4	1	8	2	0	1	2	0	0	10.0	
i 1	504.2471904761905	0.2525	75	1088	3	1	5	2	0	-2	2	0	0	10.0	
i 1	504.24959863945577	0.505	76	1088	2	24	4	17	0	2	17	0	0	4.633524600784803	
i 1	504.2696666666667	0.505	76	1088	2	20	11	16	0	1	16	0	0	0.6335246007848028	
i 1	504.49478231292517	0.2525	73	386	1	20	11	16	0	2	16	0	0	0.6335246007848028	
i 1	504.50762585034016	0.2525	75	702	4	1	15	2	0	-2	2	0	0	10.0	
i 1	504.73113605442177	7.07	61	386	4	19	16	16	0	1	16	0	0	0.5009235345346933	
i 1	504.73193877551023	0.505	75	386	4	1	5	2	0	1	2	0	0	10.0	
i 1	504.7343469387755	1.01	73	386	1	20	1	16	0	2	16	0	0	0.03877098875326901	
i 1	504.73595238095237	0.505	76	386	3	20	8	17	0	1	17	0	0	0.03877098875326901	
i 1	504.7431768707483	7.07	63	702	6	17	2	16	0	2	16	0	0	0.5009235345346933	
i 1	504.74638775510203	0.2525	73	702	3	20	15	16	0	1	16	0	0	0.03877098875326901	
i 1	504.75441496598637	1.5150000000000001	63	386	5	13	11	1	0	2	1	0	0	2.605531084707703	
i 1	504.75521768707483	1.7675	77	702	6	2	1	17	0	1	17	0	0	4.0	
i 1	504.75923129251703	0.2525	76	1088	2	24	9	17	0	2	17	0	0	4.038770988753269	
i 1	504.7696666666667	1.7675	72	702	4	1	3	8	0	-2	8	0	0	10.0	
i 1	504.9843469387755	1.01	76	1088	1	24	3	17	0	252	17	307	0	4.038770988753269	
i 1	504.99157142857143	0.2525	71	386	4	5	2	8	0	-2	8	0	0	6.0	
i 1	505.00923129251703	1.5150000000000001	74	702	6	5	2	8	0	-1	8	0	0	6.0	
i 1	505.23274149659863	1.01	76	1088	2	20	7	16	0	1	16	0	0	0.03877098875326901	
i 1	505.24879591836736	0.7575000000000001	73	1088	2	20	5	17	0	2	17	0	0	0.03877098875326901	
i 1	505.25040136054423	1.01	73	386	1	24	6	17	0	252	17	307	0	4.038770988753269	
i 1	505.25923129251703	0.2525	72	386	3	1	10	2	0	1	2	0	0	10.0	
i 1	505.25923129251703	0.505	71	702	4	5	16	8	0	-1	8	0	0	6.0	
i 1	505.26485034013604	0.2525	76	386	2	20	12	17	0	1	17	0	0	0.03877098875326901	
i 1	505.26806122448977	0.7575000000000001	75	702	4	1	7	2	0	-2	2	0	0	10.0	
i 1	505.48595238095237	0.2525	77	386	5	3	12	16	0	2	16	0	0	4.0	
i 1	505.48755782312924	0.2525	72	1088	6	1	16	2	0	-2	2	0	0	10.0	
i 1	505.49959863945577	0.7575000000000001	74	386	4	4	6	16	0	1	16	0	0	4.0	
i 1	505.73675510204083	0.2525	74	386	6	5	5	8	0	-1	8	0	0	6.0	
i 1	505.76485034013604	0.7575000000000001	76	386	2	24	10	16	0	2	16	0	0	4.038770988753269	
i 1	505.98675510204083	0.2525	74	386	6	5	1	8	0	-1	8	0	0	6.0	
i 1	505.9891632653061	0.2525	73	702	3	20	3	17	0	2	17	0	0	0.03877098875326901	
i 1	505.99879591836736	2.02	76	1088	2	24	4	17	0	2	17	0	0	4.038770988753269	
i 1	506.00361224489797	0.2525	72	386	4	24	1	8	0	1	8	0	0	11.0	
i 1	506.00762585034016	0.2525	77	386	5	3	14	16	0	2	16	0	0	4.0	
i 1	506.00762585034016	0.2525	73	702	3	20	1	17	0	1	17	0	0	0.03877098875326901	
i 1	506.2303333333333	1.2625	77	702	5	3	5	17	0	1	17	0	0	4.0	
i 1	506.2303333333333	0.2525	73	386	2	24	12	17	0	1	17	0	0	4.038770988753269	
i 1	506.23274149659863	1.2625	75	702	4	1	8	2	0	1	2	0	0	10.0	
i 1	506.23274149659863	1.5150000000000001	61	702	6	17	8	1	0	1	1	0	0	0.5009235345346933	
i 1	506.23595238095237	4.545	61	702	6	17	8	16	0	2	16	0	0	0.5009235345346933	
i 1	506.24237414965984	11.11	61	702	5	13	4	16	0	2	16	0	0	2.605531084707703	
i 1	506.2431768707483	1.5150000000000001	71	702	4	5	1	8	0	-1	8	0	0	6.0	
i 1	506.24478231292517	0.2525	76	1088	2	20	14	17	0	1	17	0	0	0.03877098875326901	
i 1	506.2471904761905	1.5150000000000001	63	702	6	7	12	16	0	2	16	0	0	5.211062169415406	
i 1	506.2568231292517	0.2525	76	1088	2	20	2	16	0	2	16	0	0	0.03877098875326901	
i 1	506.25842857142857	0.505	74	386	4	4	12	16	0	1	16	0	0	4.0	
i 1	506.26404761904763	0.7575000000000001	75	702	4	24	13	8	0	-2	8	0	0	11.0	
i 1	506.2664557823129	0.505	71	702	6	5	13	8	0	-2	8	0	0	6.0	
i 1	506.4843469387755	0.2525	77	702	4	4	1	16	0	2	16	0	0	4.0	
i 1	506.48514965986396	0.7575000000000001	76	1088	2	20	12	16	0	1	16	0	0	0.03877098875326901	
i 1	506.50923129251703	0.2525	74	386	4	5	6	2	0	-1	2	0	0	6.0	
i 1	506.5164557823129	0.2525	75	1088	6	1	2	2	0	-2	2	0	0	10.0	
i 1	506.51806122448977	0.2525	76	702	3	24	9	17	0	2	17	0	0	4.038770988753269	
i 1	506.74879591836736	0.2525	77	702	6	2	15	17	0	1	17	0	0	4.0	
i 1	506.75040136054423	0.2525	74	702	6	2	12	17	0	2	17	0	0	4.0	
i 1	506.76886394557823	1.01	74	702	6	5	10	8	0	-1	8	0	0	6.0	
i 1	506.7696666666667	0.7575000000000001	76	386	2	24	4	16	0	2	16	0	0	4.038770988753269	
i 1	506.98113605442177	0.2525	73	702	3	20	16	16	0	1	16	0	0	0.03877098875326901	
i 1	507.00120408163264	2.02	72	702	4	1	12	8	0	-2	8	0	0	10.0	
i 1	507.0156530612245	0.2525	71	1088	6	5	11	2	0	-1	2	0	0	6.0	
i 1	507.2383605442177	0.7575000000000001	76	1088	2	20	11	16	0	2	16	0	0	0.03877098875326901	
i 1	507.24558503401363	0.2525	74	702	6	5	9	8	0	-2	8	0	0	6.0	
i 1	507.2479931972789	0.2525	75	386	4	24	13	2	0	1	2	0	0	11.0	
i 1	507.2696666666667	1.7675	74	702	6	2	16	17	0	2	17	0	0	4.0	
i 1	507.48514965986396	0.2525	74	386	4	5	15	2	0	-1	2	0	0	6.0	
i 1	507.49237414965984	0.2525	75	702	4	1	16	2	0	-2	2	0	0	10.0	
i 1	507.5108367346939	0.2525	72	1088	6	1	11	2	0	-2	2	0	0	10.0	
i 1	507.7343469387755	9.09	61	702	6	17	15	1	0	1	1	0	0	0.5009235345346933	
i 1	507.73675510204083	9.595	63	702	5	7	9	16	0	2	16	0	0	5.211062169415406	
i 1	507.7391632653061	0.505	74	386	4	4	12	16	0	1	16	0	0	4.0	
i 1	507.74157142857143	0.2525	75	702	4	1	1	2	0	1	2	0	0	10.0	
i 1	507.74638775510203	0.505	71	702	6	5	13	8	0	-2	8	0	0	6.0	
i 1	507.7528095238095	0.7575000000000001	76	1088	2	20	15	16	0	1	16	0	0	0.03877098875326901	
i 1	507.75441496598637	1.7675	74	702	4	5	13	8	0	-1	8	0	0	6.0	
i 1	507.75923129251703	4.04	61	386	4	19	1	1	0	1	1	0	0	0.5009235345346933	
i 1	507.75923129251703	0.7575000000000001	76	1088	2	20	4	16	0	1	16	0	0	0.03877098875326901	
i 1	507.99879591836736	0.2525	76	386	2	24	10	16	0	2	16	0	0	4.038770988753269	
i 1	508.23193877551023	0.2525	75	702	4	24	15	8	0	-2	8	0	0	11.0	
i 1	508.2391632653061	1.7675	73	386	2	24	4	17	0	1	17	0	0	4.038770988753269	
i 1	508.23996598639457	2.2725	77	702	6	2	13	17	0	1	17	0	0	4.0	
i 1	508.25521768707483	0.2525	74	386	6	5	6	2	0	-1	2	0	0	6.0	
i 1	508.25762585034016	1.7675	73	386	2	20	4	16	0	2	16	0	0	0.03877098875326901	
i 1	508.26324489795917	0.2525	74	1088	5	9	10	16	0	1	16	0	0	3.0	
i 1	508.26485034013604	0.2525	71	386	4	5	15	8	0	-2	8	0	0	6.0	
i 1	508.48675510204083	2.2725	74	702	6	5	14	8	0	-2	8	0	0	6.0	
i 1	508.50602040816324	0.2525	72	386	6	1	13	2	0	1	2	0	0	10.0	
i 1	508.50923129251703	0.505	72	1088	6	1	9	2	0	-2	2	0	0	10.0	
i 1	508.74157142857143	0.7575000000000001	75	702	4	1	9	2	0	-2	2	0	0	10.0	
i 1	508.74959863945577	0.2525	76	1088	2	20	14	16	0	1	16	0	0	0.03877098875326901	
i 1	508.99879591836736	0.2525	76	1088	2	20	14	16	0	2	16	0	0	0.03877098875326901	
i 1	509.0020068027211	0.2525	72	386	6	1	13	2	0	1	2	0	0	10.0	
i 1	509.01003401360543	0.505	74	1088	5	9	6	17	0	1	17	0	0	3.0	
i 1	509.01003401360543	0.2525	74	386	6	5	7	2	0	-1	2	0	0	6.0	
i 1	509.01324489795917	0.2525	75	702	4	24	16	8	0	-2	8	0	0	11.0	
i 1	509.24478231292517	0.505	71	386	4	5	16	8	0	-2	8	0	0	6.0	
i 1	509.25040136054423	1.5150000000000001	72	702	4	1	9	8	0	-2	8	0	0	10.0	
i 1	509.25842857142857	0.2525	74	386	5	3	11	17	0	1	17	0	0	4.0	
i 1	509.2616394557823	0.2525	76	1088	2	20	8	16	0	1	16	0	0	0.03877098875326901	
i 1	509.48274149659863	1.01	76	1088	2	24	12	17	0	2	17	0	0	4.038770988753269	
i 1	509.4891632653061	0.2525	75	702	4	1	16	2	0	1	2	0	0	10.0	
i 1	509.49237414965984	0.2525	77	702	5	3	10	17	0	1	17	0	0	4.0	
i 1	509.49638775510203	0.2525	77	702	4	4	1	16	0	2	16	0	0	4.0	
i 1	509.50762585034016	0.7575000000000001	76	1088	2	20	11	16	0	2	16	0	0	0.03877098875326901	
i 1	509.50923129251703	0.2525	71	702	6	5	1	8	0	-1	8	0	0	6.0	
i 1	509.51324489795917	0.2525	75	702	4	24	16	8	0	-2	8	0	0	11.0	
i 1	509.73274149659863	0.505	72	1088	6	1	12	2	0	-2	2	0	0	10.0	
i 1	509.74076870748297	0.2525	72	386	6	1	9	2	0	1	2	0	0	10.0	
i 1	509.7696666666667	0.505	74	702	4	5	5	8	0	-1	8	0	0	6.0	
i 1	509.98274149659863	1.2625	76	386	2	24	12	16	0	2	16	0	0	4.038770988753269	
i 1	509.98675510204083	0.2525	74	702	6	2	13	17	0	2	17	0	0	4.0	
i 1	509.99157142857143	2.02	75	702	4	1	7	2	0	1	2	0	0	10.0	
i 1	510.00361224489797	0.2525	76	1088	2	20	6	16	0	1	16	0	0	0.03877098875326901	
i 1	510.0068231292517	0.7575000000000001	77	702	4	4	7	16	0	2	16	0	0	4.0	
i 1	510.01725850340137	0.2525	71	1088	6	5	16	2	0	-2	2	0	0	6.0	
i 1	510.23193877551023	1.7675	77	702	5	3	6	17	0	1	17	0	0	4.0	
i 1	510.25040136054423	0.2525	76	702	3	20	6	17	0	1	17	0	0	0.03877098875326901	
i 1	510.26806122448977	0.505	71	702	6	5	15	8	0	-2	8	0	0	6.0	
i 1	510.26806122448977	0.505	73	702	3	20	3	17	0	2	17	0	0	0.03877098875326901	
i 1	510.48755782312924	0.2525	74	702	6	2	10	17	0	2	17	0	0	4.0	
i 1	510.48755782312924	1.2625	71	702	6	5	9	8	0	-1	8	0	0	6.0	
i 1	510.49237414965984	0.505	76	1088	2	20	1	16	0	1	16	0	0	0.03877098875326901	
i 1	510.49879591836736	0.2525	72	1088	6	1	6	2	0	-2	2	0	0	10.0	
i 1	510.73113605442177	0.2525	74	1088	5	9	16	16	0	1	16	0	0	3.0	
i 1	510.73113605442177	0.2525	74	386	6	5	3	2	0	-1	2	0	0	6.0	
i 1	510.7335442176871	6.565	61	702	6	17	15	16	0	2	16	0	0	0.5009235345346933	
i 1	510.7471904761905	0.2525	73	1088	2	20	2	16	0	1	16	0	0	0.03877098875326901	
i 1	510.75521768707483	0.505	71	702	4	5	14	8	0	-2	8	0	0	6.0	
i 1	510.75842857142857	0.505	74	386	4	4	6	16	0	1	16	0	0	4.0	
i 1	510.76003401360543	0.2525	75	702	4	24	9	8	0	-2	8	0	0	11.0	
i 1	510.76324489795917	1.01	61	702	6	17	8	16	0	2	16	0	0	0.5009235345346933	
i 1	510.7664557823129	0.505	72	1088	3	1	10	2	0	-2	2	0	0	10.0	
i 1	510.98595238095237	0.2525	77	702	6	2	6	17	0	1	17	0	0	4.0	
i 1	510.99638775510203	0.2525	73	702	3	20	12	17	0	1	17	0	0	0.03877098875326901	
i 1	511.01324489795917	0.2525	73	702	3	20	16	17	0	2	17	0	0	0.03877098875326901	
i 1	511.2303333333333	0.505	77	702	4	4	15	16	0	2	16	0	0	4.0	
i 1	511.23595238095237	0.2525	71	386	6	5	8	8	0	-2	8	0	0	6.0	
i 1	511.23996598639457	0.505	76	1088	2	24	9	17	0	2	17	0	0	4.038770988753269	
i 1	511.24879591836736	0.505	73	1088	2	20	9	17	0	2	17	0	0	0.03877098875326901	
i 1	511.50762585034016	0.2525	77	702	6	2	4	17	0	1	17	0	0	4.0	
i 1	511.5116394557823	0.2525	72	1088	3	1	4	2	0	-2	2	0	0	10.0	
i 1	511.51244217687076	0.7575000000000001	74	702	6	5	8	8	0	-2	8	0	0	6.0	
i 1	511.51485034013604	0.2525	75	702	4	1	9	2	0	-2	2	0	0	10.0	
i 1	511.73274149659863	12.625	63	906	5	14	1	1	0	1	1	0	0	6.513827711769258	
i 1	511.7335442176871	0.2525	71	906	6	5	13	8	0	-1	8	0	0	6.0	
i 1	511.73514965986396	1.2625	75	702	4	24	8	8	0	-2	8	0	0	11.0	
i 1	511.7383605442177	1.7675	73	204	3	20	8	16	0	2	16	0	0	0.03877098875326901	
i 1	511.74157142857143	8.08	61	204	5	19	11	16	0	2	16	0	0	0.5009235345346933	
i 1	511.7431768707483	1.7675	73	204	2	24	14	17	0	1	17	0	0	4.038770988753269	
i 1	511.74397959183676	2.02	63	906	6	17	16	1	0	1	1	0	0	0.5009235345346933	
i 1	511.74478231292517	0.505	73	204	3	20	12	17	0	2	17	0	0	0.03877098875326901	
i 1	511.74558503401363	1.01	77	204	6	9	5	17	0	2	17	0	0	3.0	
i 1	511.7479931972789	2.02	61	204	5	18	2	1	0	2	1	0	0	0.5009235345346933	
i 1	511.7479931972789	0.2525	73	204	3	24	9	17	0	1	17	0	0	4.038770988753269	
i 1	511.74879591836736	12.625	61	906	5	14	8	16	0	2	16	0	0	6.513827711769258	
i 1	511.74959863945577	11.11	61	204	5	19	7	1	0	2	1	0	0	0.5009235345346933	
i 1	511.75521768707483	5.05	63	204	5	18	4	16	0	2	16	0	0	0.5009235345346933	
i 1	511.75602040816324	1.5150000000000001	71	702	4	5	5	8	0	-2	8	0	0	6.0	
i 1	511.75762585034016	0.7575000000000001	72	906	4	1	8	2	0	-2	2	0	0	10.0	
i 1	511.75842857142857	1.7675	77	906	6	2	11	16	0	2	16	0	0	4.0	
i 1	511.7656530612245	11.11	61	906	6	17	3	1	0	1	1	0	0	0.5009235345346933	
i 1	511.9931768707483	0.2525	74	204	7	5	1	8	0	-2	8	0	0	6.0	
i 1	512.233544217687	0.2525	75	204	7	1	9	2	0	-2	2	0	0	10.0	
i 1	512.2688639455782	0.2525	76	204	3	20	13	16	0	1	16	0	0	0.03877098875326901	
i 1	512.483544217687	2.02	75	702	4	1	12	2	0	1	2	0	0	10.0	
i 1	512.5012040816326	0.2525	72	906	4	1	13	2	0	1	2	0	0	10.0	
i 1	512.509231292517	0.2525	73	204	2	24	3	17	0	2	17	0	0	4.038770988753269	
i 1	512.5196666666667	0.2525	74	204	5	4	9	17	0	2	17	0	0	4.0	
i 1	512.7391632653062	0.2525	74	702	6	5	6	8	0	-2	8	0	0	6.0	
i 1	512.7463877551021	0.2525	73	204	3	20	16	17	0	2	17	0	0	0.03877098875326901	
i 1	512.7520068027211	2.02	77	702	4	4	11	16	0	2	16	0	0	4.0	
i 1	512.7544149659864	0.2525	71	204	7	5	14	2	0	-1	2	0	0	6.0	
i 1	512.9803333333333	0.7575000000000001	76	204	2	20	5	17	0	1	17	0	0	0.03877098875326901	
i 1	512.9931768707482	0.7575000000000001	73	204	2	20	2	17	0	2	17	0	0	0.03877098875326901	
i 1	512.9947823129252	0.2525	74	204	6	9	7	17	0	1	17	0	0	3.0	
i 1	513.0004013605442	0.7575000000000001	72	906	4	1	3	2	0	-2	2	0	0	10.0	
i 1	513.0020068027211	1.7675	71	906	6	5	7	8	0	-1	8	0	0	6.0	
i 1	513.2367551020408	0.505	74	204	5	4	3	17	0	2	17	0	0	4.0	
i 1	513.2399659863945	0.2525	71	204	7	5	10	2	0	-1	2	0	0	6.0	
i 1	513.2536122448979	0.505	74	702	6	5	15	8	0	-2	8	0	0	6.0	
i 1	513.4891632653062	0.2525	71	204	7	5	5	8	0	-1	8	0	0	6.0	
i 1	513.4971904761904	0.2525	73	204	2	24	10	17	0	2	17	0	0	4.038770988753269	
i 1	513.5036122448979	0.2525	74	204	6	9	3	17	0	1	17	0	0	3.0	
i 1	513.7343469387755	0.2525	75	702	4	24	2	8	0	-2	8	0	0	11.0	
i 1	513.7375578231292	10.605	63	906	6	17	16	1	0	1	1	0	0	0.5009235345346933	
i 1	513.7399659863945	9.09	61	204	5	18	12	1	0	2	1	0	0	0.5009235345346933	
i 1	513.740768707483	0.2525	72	204	7	1	11	2	0	1	2	0	0	10.0	
i 1	513.766455782313	0.2525	77	906	6	2	6	16	0	2	16	0	0	4.0	
i 1	513.9931768707482	1.2625	72	906	4	1	1	2	0	1	2	0	0	10.0	
i 1	514.0108367346938	0.2525	74	204	5	4	7	17	0	2	17	0	0	4.0	
i 1	514.0172585034013	2.02	77	702	5	3	6	17	0	1	17	0	0	4.0	
i 1	514.2303333333333	0.2525	72	204	4	1	6	2	0	-2	2	0	0	10.0	
i 1	514.233544217687	2.02	74	906	6	5	11	2	0	-1	2	0	0	6.0	
i 1	514.2439795918367	0.2525	73	204	3	24	9	17	0	1	17	0	0	4.0	
i 1	514.2616394557823	0.2525	71	204	7	5	2	2	0	-1	2	0	0	6.0	
i 1	514.4875578231292	0.2525	74	204	6	9	8	17	0	1	17	0	0	3.0	
i 1	514.4899659863945	0.2525	75	204	4	1	13	2	0	-2	2	0	0	10.0	
i 1	514.5140476190476	0.505	74	204	7	5	11	8	0	-2	8	0	0	6.0	
i 1	514.5180612244898	1.7675	72	906	4	1	2	2	0	-2	2	0	0	10.0	
i 1	514.7415714285714	0.505	71	204	7	5	10	2	0	-1	2	0	0	6.0	
i 1	514.759231292517	0.2525	74	906	6	2	14	16	0	2	16	0	0	4.0	
i 1	515.0076258503401	0.2525	71	204	7	5	5	8	0	-2	8	0	0	6.0	
i 1	515.0076258503401	0.505	73	204	1	24	11	17	0	252	17	307	0	4.0	
i 1	515.2383605442177	0.2525	74	204	7	5	13	8	0	-2	8	0	0	6.0	
i 1	515.2487959183674	0.505	72	204	5	24	5	8	0	-2	8	0	0	11.0	
i 1	515.2504013605442	0.505	71	906	6	5	15	8	0	-1	8	0	0	6.0	
i 1	515.2632448979592	3.2825	73	204	2	24	5	17	0	1	17	0	0	4.0	
i 1	515.4955850340136	0.7575000000000001	73	204	3	24	14	17	0	1	17	0	0	4.0	
i 1	515.5124421768708	2.02	74	906	6	2	6	16	0	2	16	0	0	4.0	
i 1	515.5124421768708	0.2525	74	204	6	9	16	17	0	1	17	0	0	3.0	
i 1	515.7447823129252	0.7575000000000001	74	702	4	5	13	8	0	-2	8	0	0	6.0	
i 1	515.7536122448979	0.505	77	906	6	2	11	16	0	2	16	0	0	4.0	
i 1	515.7560204081633	0.2525	71	204	7	5	15	8	0	-1	8	0	0	6.0	
i 1	515.7624421768708	1.01	72	906	4	1	16	2	0	1	2	0	0	10.0	
i 1	515.9827414965987	0.2525	74	204	5	4	10	17	0	2	17	0	0	4.0	
i 1	516.0044149659864	1.2625	71	702	6	5	5	8	0	-2	8	0	0	6.0	
i 1	516.2319387755102	0.2525	75	702	4	1	9	2	0	1	2	0	0	10.0	
i 1	516.2343469387755	0.2525	77	702	4	4	6	16	0	2	16	0	0	4.0	
i 1	516.264850340136	0.2525	74	204	6	9	7	17	0	1	17	0	0	3.0	
i 1	516.2656530612245	0.505	75	702	4	24	11	8	0	-2	8	0	0	11.0	
i 1	516.2656530612245	0.2525	71	204	7	5	7	8	0	-1	8	0	0	6.0	
i 1	516.490768707483	0.2525	74	204	7	5	4	8	0	-2	8	0	0	6.0	
i 1	516.4915714285714	0.2525	71	906	6	5	2	8	0	-1	8	0	0	6.0	
i 1	516.4939795918367	0.505	72	204	4	1	14	2	0	-2	2	0	0	10.0	
i 1	516.5116394557823	0.505	74	204	5	4	1	17	0	2	17	0	0	4.0	
i 1	516.7319387755102	0.505	61	702	6	17	16	1	0	1	1	0	0	0.5009235345346933	
i 1	516.7487959183674	9.09	63	204	5	18	1	16	0	2	16	0	0	0.5009235345346933	
i 1	516.7632448979592	1.01	74	906	6	5	5	2	0	-1	2	0	0	6.0	
i 1	516.7688639455782	0.2525	72	204	3	1	10	2	0	1	2	0	0	10.0	
i 1	516.7696666666667	1.01	72	906	5	1	13	2	0	1	2	0	0	10.0	
i 1	516.9827414965987	0.505	72	204	5	24	15	8	0	-2	8	0	0	11.0	
i 1	517.0012040816326	0.2525	77	702	4	4	5	16	0	2	16	0	0	4.0	
i 1	517.0044149659864	0.2525	75	204	4	1	15	2	0	-2	2	0	0	10.0	
i 1	517.009231292517	0.2525	71	204	7	5	15	8	0	-1	8	0	0	6.0	
i 1	517.0140476190476	0.2525	74	204	6	9	10	17	0	1	17	0	0	3.0	
i 1	517.2375578231292	2.2725	77	906	6	2	16	16	0	2	16	0	0	4.0	
i 1	517.2399659863945	7.07	63	590	6	17	6	1	0	1	1	0	0	0.5009235345346933	
i 1	517.2463877551021	1.2625	72	906	4	1	1	2	0	-2	2	0	0	10.0	
i 1	517.2471904761904	0.7575000000000001	74	590	4	4	3	16	0	2	16	0	0	4.0	
i 1	517.2479931972789	7.07	61	590	5	7	8	1	0	1	1	0	0	5.211062169415406	
i 1	517.2544149659864	1.5150000000000001	74	590	6	5	6	8	0	-2	8	0	0	6.0	
i 1	517.2624421768708	2.525	63	590	6	17	14	1	0	2	1	0	0	0.5009235345346933	
i 1	517.2632448979592	0.7575000000000001	74	590	6	5	11	8	0	-1	8	0	0	6.0	
i 1	517.2696666666667	7.07	61	590	5	13	10	16	0	1	16	0	0	2.605531084707703	
i 1	517.4947823129252	0.505	75	204	4	1	12	2	0	-2	2	0	0	10.0	
i 1	517.5172585034013	0.2525	74	204	5	4	5	17	0	2	17	0	0	4.0	
i 1	517.7303333333333	0.2525	72	204	4	1	4	2	0	-2	2	0	0	10.0	
i 1	517.764850340136	0.2525	74	204	6	9	10	17	0	1	17	0	0	3.0	
i 1	517.766455782313	0.505	71	204	7	5	7	8	0	-2	8	0	0	6.0	
i 1	517.9819387755102	3.0300000000000002	76	204	2	24	6	17	0	1	17	0	0	4.0	
i 1	517.9947823129252	3.0300000000000002	73	204	3	24	4	17	0	1	17	0	0	4.0	
i 1	517.9963877551021	0.2525	71	204	7	5	16	2	0	-1	2	0	0	6.0	
i 1	518.0060204081633	2.02	75	590	4	24	9	2	0	-2	2	0	0	11.0	
i 1	518.009231292517	0.505	74	906	6	2	16	16	0	2	16	0	0	4.0	
i 1	518.0156530612245	0.2525	72	906	5	1	2	2	0	1	2	0	0	10.0	
i 1	518.2463877551021	2.02	74	590	6	5	5	8	0	-1	8	0	0	6.0	
i 1	518.2495986394558	0.505	72	590	4	1	12	2	0	-2	2	0	0	10.0	
i 1	518.2600340136055	0.2525	74	906	6	5	1	2	0	-1	2	0	0	6.0	
i 1	518.5100340136055	0.505	72	906	5	1	4	2	0	1	2	0	0	10.0	
i 1	518.7447823129252	0.505	72	204	3	1	4	2	0	1	2	0	0	10.0	
i 1	518.7495986394558	0.2525	74	204	4	5	12	8	0	-2	8	0	0	6.0	
i 1	518.7568231292518	0.2525	74	204	5	4	10	17	0	2	17	0	0	4.0	
i 1	518.7624421768708	0.2525	71	204	7	5	6	8	0	-1	8	0	0	6.0	
i 1	518.7656530612245	2.02	74	906	6	2	15	16	0	2	16	0	0	4.0	
i 1	518.9987959183674	0.7575000000000001	71	204	7	5	12	2	0	-1	2	0	0	6.0	
i 1	518.9995986394558	0.2525	75	204	4	1	15	2	0	-2	2	0	0	10.0	
i 1	519.0020068027211	0.7575000000000001	74	590	4	4	14	16	0	2	16	0	0	4.0	
i 1	519.0076258503401	0.505	71	204	7	5	6	8	0	-2	8	0	0	6.0	
i 1	519.2520068027211	1.7675	72	590	4	1	6	2	0	-2	2	0	0	10.0	
i 1	519.266455782313	0.2525	72	906	5	1	13	2	0	1	2	0	0	10.0	
i 1	519.4859523809524	0.2525	71	204	7	5	9	8	0	-1	8	0	0	6.0	
i 1	519.5108367346938	1.01	74	590	5	3	14	17	0	1	17	0	0	4.0	
i 1	519.514850340136	0.2525	72	204	5	24	12	8	0	-2	8	0	0	11.0	
i 1	519.7343469387755	0.505	72	204	3	24	14	8	0	-2	8	0	0	11.0	
i 1	519.735149659864	4.545	71	906	6	5	11	8	0	-1	8	0	0	6.0	
i 1	519.7439795918367	0.505	74	204	6	9	10	17	0	1	17	0	0	3.0	
i 1	519.7471904761904	4.545	61	204	5	19	2	16	0	2	16	0	0	0.5009235345346933	
i 1	519.7584285714286	4.545	63	590	6	17	10	1	0	2	1	0	0	0.5009235345346933	
i 1	519.766455782313	0.2525	74	590	6	5	10	8	0	-2	8	0	0	6.0	
i 1	519.9867551020408	0.505	71	204	7	5	15	2	0	-1	2	0	0	6.0	
i 1	519.9955850340136	1.01	72	906	5	1	10	2	0	-2	2	0	0	10.0	
i 1	520.2359523809524	1.7675	72	906	5	1	7	2	0	1	2	0	0	10.0	
i 1	520.2600340136055	0.2525	71	204	7	5	5	8	0	-2	8	0	0	6.0	
i 1	520.2640476190476	1.5150000000000001	77	906	6	2	4	16	0	2	16	0	0	4.0	
i 1	520.4827414965987	0.7575000000000001	74	204	5	4	9	17	0	2	17	0	0	4.0	
i 1	520.4955850340136	0.2525	74	204	7	5	15	8	0	-2	8	0	0	6.0	
i 1	520.5140476190476	0.505	74	590	6	5	1	8	0	-1	8	0	0	6.0	
i 1	520.7303333333333	2.02	73	204	2	24	9	17	0	1	17	0	0	4.0	
i 1	520.7391632653062	0.2525	74	590	4	4	12	16	0	2	16	0	0	4.0	
i 1	520.985149659864	0.2525	72	204	4	1	16	2	0	-2	2	0	0	10.0	
i 1	520.9875578231292	0.2525	74	204	6	3	16	17	0	1	17	0	0	4.0	
i 1	520.9939795918367	0.2525	72	204	3	1	16	2	0	1	2	0	0	10.0	
i 1	520.9979931972789	0.7575000000000001	76	204	1	24	16	17	0	248	17	308	0	4.0	
i 1	521.014850340136	1.01	74	906	6	5	10	2	0	-1	2	0	0	6.0	
i 1	521.2391632653062	0.2525	72	204	3	24	6	8	0	-2	8	0	0	11.0	
i 1	521.2495986394558	2.525	72	906	5	1	6	2	0	-2	2	0	0	10.0	
i 1	521.2608367346938	2.02	74	590	4	4	10	16	0	2	16	0	0	4.0	
i 1	521.4963877551021	0.2525	74	590	6	5	5	8	0	-2	8	0	0	6.0	
i 1	521.7447823129252	0.2525	76	204	2	24	13	17	0	1	17	0	0	4.0	
i 1	521.7616394557823	0.505	74	204	7	5	4	8	0	-2	8	0	0	6.0	
i 1	521.7624421768708	0.2525	72	204	3	1	14	2	0	1	2	0	0	10.0	
i 1	521.7672585034013	0.7575000000000001	77	204	6	9	5	17	0	2	17	0	0	3.0	
i 1	521.985149659864	0.2525	72	204	4	1	2	2	0	-2	2	0	0	10.0	
i 1	522.0044149659864	0.505	71	204	4	5	4	8	0	-1	8	0	0	6.0	
i 1	522.0196666666667	0.2525	75	204	4	1	9	2	0	-2	2	0	0	10.0	
i 1	522.2512040816326	0.2525	74	590	6	5	3	8	0	-1	8	0	0	6.0	
i 1	522.2616394557823	4.04	73	204	3	24	12	17	0	1	17	0	0	4.0	
i 1	522.4915714285714	0.2525	72	204	3	24	10	8	0	-2	8	0	0	11.0	
i 1	522.4963877551021	1.7675	74	590	5	3	10	17	0	1	17	0	0	4.0	
i 1	522.5076258503401	0.2525	76	590	3	24	8	17	0	1	17	0	0	4.0	
i 1	522.5108367346938	0.2525	75	204	4	1	5	2	0	-2	2	0	0	10.0	
i 1	522.514850340136	0.2525	74	590	6	5	15	8	0	-2	8	0	0	6.0	
i 1	522.5156530612245	0.2525	71	204	7	5	12	2	0	-1	2	0	0	6.0	
i 1	522.7479931972789	0.7575000000000001	72	906	5	1	10	2	0	1	2	0	0	10.0	
i 1	522.7479931972789	1.01	74	590	6	5	8	8	0	-1	8	0	0	6.0	
i 1	522.7495986394558	1.01	73	204	2	24	6	17	0	1	17	0	0	4.0	
i 1	522.7600340136055	1.5150000000000001	72	590	5	1	12	2	0	-2	2	0	0	10.0	
i 1	522.7640476190476	9.09	61	204	5	18	3	1	0	2	1	0	0	0.5009235345346933	
i 1	522.7640476190476	1.5150000000000001	61	204	5	19	8	1	0	2	1	0	0	0.5009235345346933	
i 1	523.016455782313	0.2525	74	204	7	5	4	8	0	-2	8	0	0	6.0	
i 1	523.2624421768708	0.7575000000000001	71	204	7	5	2	2	0	-1	2	0	0	6.0	
i 1	523.5188639455782	0.2525	72	204	3	24	13	8	0	-2	8	0	0	11.0	
i 1	523.7375578231292	0.505	73	204	2	24	12	17	0	1	17	0	0	4.0	
i 1	523.7415714285714	0.2525	74	906	6	5	11	2	0	-1	2	0	0	6.0	
i 1	523.7447823129252	0.2525	72	204	3	1	16	2	0	1	2	0	0	10.0	
i 1	523.7528095238096	0.505	72	906	5	1	5	2	0	1	2	0	0	10.0	
i 1	523.766455782313	0.2525	76	590	3	24	1	16	0	1	16	0	0	4.0	
i 1	523.9899659863945	0.7575000000000001	74	204	7	5	3	8	0	-2	8	0	0	6.0	
i 1	523.9987959183674	0.2525	74	590	6	5	3	8	0	-2	8	0	0	6.0	
i 1	524.233544217687	0.2525	74	1088	6	5	3	8	0	-2	8	0	0	6.0	
i 1	524.2375578231292	7.575	61	1088	5	14	8	16	0	2	16	0	0	6.513827711769258	
i 1	524.2383605442177	1.5150000000000001	61	1088	6	17	14	16	0	2	16	0	0	0.5009235345346933	
i 1	524.2399659863945	7.575	63	1088	5	14	15	1	0	1	1	0	0	6.513827711769258	
i 1	524.2399659863945	5.555	63	702	5	7	2	1	0	2	1	0	0	5.211062169415406	
i 1	524.2423741496599	2.02	74	702	4	4	2	16	0	2	16	0	0	4.0	
i 1	524.2431768707482	2.02	71	702	6	5	11	8	0	-1	8	0	0	6.0	
i 1	524.2463877551021	4.545	63	702	4	19	14	16	0	1	16	0	0	0.5009235345346933	
i 1	524.2504013605442	5.555	63	702	6	17	15	16	0	1	16	0	0	0.5009235345346933	
i 1	524.2536122448979	5.555	61	702	5	13	11	16	0	1	16	0	0	2.605531084707703	
i 1	524.2560204081633	0.7575000000000001	77	1088	6	2	2	16	0	1	16	0	0	4.0	
i 1	524.2600340136055	7.575	61	702	4	19	5	1	0	2	1	0	0	0.5009235345346933	
i 1	524.2624421768708	0.505	72	204	4	1	3	2	0	-2	2	0	0	10.0	
i 1	524.264850340136	4.545	61	702	6	17	15	1	0	1	1	0	0	0.5009235345346933	
i 1	524.2656530612245	1.01	72	702	4	24	11	2	0	-2	2	0	0	11.0	
i 1	524.2672585034013	0.2525	73	702	2	24	16	17	0	2	17	0	0	4.0	
i 1	524.7383605442177	0.505	74	702	6	5	3	2	0	-2	2	0	0	6.0	
i 1	524.7495986394558	2.2725	72	702	5	1	15	8	0	-2	8	0	0	10.0	
i 1	524.7600340136055	0.2525	71	204	7	5	8	8	0	-1	8	0	0	6.0	
i 1	525.0084285714286	0.505	74	702	6	5	11	8	0	-2	8	0	0	6.0	
i 1	525.2479931972789	0.505	75	204	4	1	8	2	0	-2	2	0	0	10.0	
i 1	525.2584285714286	0.2525	74	1088	6	5	6	8	0	-1	8	0	0	6.0	
i 1	525.5012040816326	0.2525	74	1088	6	5	16	8	0	-2	8	0	0	6.0	
i 1	525.5076258503401	2.02	74	702	6	5	11	2	0	-2	2	0	0	6.0	
i 1	525.7327414965987	3.0300000000000002	75	1088	5	1	6	2	0	-2	2	0	0	10.0	
i 1	525.7359523809524	1.2625	73	702	2	24	4	17	0	2	17	0	0	4.0	
i 1	525.7423741496599	2.02	77	1088	6	2	8	16	0	1	16	0	0	4.0	
i 1	525.7479931972789	6.0600000000000005	63	204	5	18	4	16	0	2	16	0	0	0.5009235345346933	
i 1	525.7584285714286	0.2525	75	702	3	24	12	2	0	1	2	0	0	11.0	
i 1	525.9947823129252	0.2525	71	702	6	5	6	8	0	-1	8	0	0	6.0	
i 1	526.0124421768708	0.505	75	1088	5	1	16	2	0	1	2	0	0	10.0	
i 1	526.2375578231292	0.505	71	204	7	5	10	8	0	-1	8	0	0	6.0	
i 1	526.2431768707482	0.2525	77	702	5	3	7	17	0	1	17	0	0	4.0	
i 1	526.2600340136055	0.505	74	204	6	9	9	17	0	1	17	0	0	3.0	
i 1	526.2600340136055	0.505	74	702	3	5	7	8	0	-2	8	0	0	6.0	
i 1	526.4923741496599	4.04	73	204	3	24	14	17	0	1	17	0	0	4.0	
i 1	526.4963877551021	0.2525	75	204	4	1	8	2	0	-2	2	0	0	10.0	
i 1	526.7303333333333	0.2525	77	204	6	9	6	17	0	2	17	0	0	3.0	
i 1	526.7399659863945	0.505	74	702	4	4	10	16	0	2	16	0	0	4.0	
i 1	526.7552176870748	0.2525	74	204	7	5	9	8	0	-2	8	0	0	6.0	
i 1	526.7576258503401	2.02	74	1088	6	5	3	8	0	-1	8	0	0	6.0	
i 1	526.7672585034013	0.2525	75	702	3	24	1	2	0	1	2	0	0	11.0	
i 1	526.985149659864	0.505	74	702	5	3	4	16	0	1	16	0	0	4.0	
i 1	527.0116394557823	0.7575000000000001	74	1088	6	5	15	8	0	-2	8	0	0	6.0	
i 1	527.2520068027211	0.2525	73	702	2	24	5	17	0	2	17	0	0	4.0	
i 1	527.2544149659864	1.5150000000000001	74	1088	6	2	15	17	0	2	17	0	0	4.0	
i 1	527.2584285714286	0.7575000000000001	75	1088	5	1	15	2	0	1	2	0	0	10.0	
i 1	527.4915714285714	0.7575000000000001	71	204	7	5	12	8	0	-1	8	0	0	6.0	
i 1	527.4955850340136	0.2525	77	702	4	4	9	16	0	2	16	0	0	4.0	
i 1	527.7584285714286	0.2525	77	204	6	9	10	17	0	2	17	0	0	3.0	
i 1	527.7656530612245	0.2525	77	702	5	3	11	17	0	1	17	0	0	4.0	
i 1	527.7672585034013	0.2525	74	702	3	5	11	8	0	-2	8	0	0	6.0	
i 1	528.0004013605442	1.7675	72	702	5	1	1	8	0	-2	8	0	0	10.0	
i 1	528.0108367346938	0.505	71	702	6	5	3	8	0	-1	8	0	0	6.0	
i 1	528.2512040816326	0.2525	74	702	3	5	2	8	0	-2	8	0	0	6.0	
i 1	528.2616394557823	2.02	77	1088	6	2	1	16	0	1	16	0	0	4.0	
i 1	528.5012040816326	1.2625	74	702	6	5	12	2	0	-2	2	0	0	6.0	
i 1	528.5084285714286	0.2525	71	204	7	5	10	8	0	-1	8	0	0	6.0	
i 1	528.5100340136055	0.7575000000000001	73	702	2	24	3	17	0	2	17	0	0	4.0	
i 1	528.7495986394558	3.0300000000000002	63	702	4	19	10	16	0	1	16	0	0	0.5009235345346933	
i 1	528.7512040816326	0.505	74	1088	6	5	6	8	0	-1	8	0	0	6.0	
i 1	528.7640476190476	0.7575000000000001	74	1088	6	5	7	8	0	-2	8	0	0	6.0	
i 1	529.0180612244898	0.505	77	702	5	3	13	17	0	1	17	0	0	4.0	
i 1	529.2359523809524	0.505	72	204	5	1	15	2	0	-2	2	0	0	10.0	
i 1	529.2431768707482	0.2525	73	702	2	24	7	16	0	2	16	0	0	4.0	
i 1	529.2455850340136	0.2525	74	204	7	5	13	8	0	-2	8	0	0	6.0	
i 1	529.2696666666667	0.2525	75	1088	5	1	14	2	0	-2	2	0	0	10.0	
i 1	529.485149659864	0.2525	71	702	6	5	11	8	0	-1	8	0	0	6.0	
i 1	529.4899659863945	2.02	74	1088	6	5	10	8	0	-1	8	0	0	6.0	
i 1	529.4939795918367	0.2525	73	702	3	24	14	16	0	2	16	0	0	4.0	
i 1	529.5012040816326	1.2625	75	1088	5	1	11	2	0	1	2	0	0	10.0	
i 1	529.7343469387755	0.505	75	702	3	24	3	2	0	1	2	0	0	11.0	
i 1	529.7391632653062	0.505	71	590	6	5	4	2	0	-1	2	0	0	6.0	
i 1	529.7479931972789	2.02	63	590	5	13	1	1	0	2	1	0	0	2.605531084707703	
i 1	529.7487959183674	2.02	61	590	6	17	15	16	0	1	16	0	0	0.5009235345346933	
i 1	529.7568231292518	0.2525	75	590	5	1	14	2	0	1	2	0	0	10.0	
i 1	529.7584285714286	2.02	63	590	5	7	15	16	0	2	16	0	0	5.211062169415406	
i 1	529.7608367346938	1.7675	74	590	5	3	4	17	0	1	17	0	0	4.0	
i 1	529.9875578231292	0.7575000000000001	73	702	2	24	14	17	0	2	17	0	0	4.0	
i 1	530.0116394557823	1.7675	75	590	4	24	3	2	0	-2	2	0	0	11.0	
i 1	530.2343469387755	0.2525	77	702	4	4	11	16	0	2	16	0	0	4.0	
i 1	530.2391632653062	0.2525	75	702	3	1	9	2	0	-2	2	0	0	10.0	
i 1	530.2447823129252	0.7575000000000001	74	204	6	9	9	17	0	1	17	0	0	3.0	
i 1	530.264850340136	0.2525	76	590	3	24	7	17	0	1	17	0	0	4.0	
i 1	530.4899659863945	1.01	73	702	2	24	6	16	0	2	16	0	0	4.0	
i 1	530.516455782313	0.505	77	204	6	9	9	17	0	2	17	0	0	3.0	
i 1	530.5188639455782	0.2525	72	204	5	1	16	2	0	-2	2	0	0	10.0	
i 1	530.7495986394558	0.505	75	702	3	1	3	2	0	-2	2	0	0	10.0	
i 1	530.7512040816326	0.2525	71	204	7	5	14	8	0	-1	8	0	0	6.0	
i 1	530.7640476190476	0.2525	75	590	5	1	11	2	0	1	2	0	0	10.0	
i 1	530.7696666666667	0.505	71	702	6	5	3	8	0	-1	8	0	0	6.0	
i 1	530.983544217687	0.7575000000000001	71	590	6	5	15	2	0	-1	2	0	0	6.0	
i 1	530.9995986394558	0.7575000000000001	74	1088	6	2	3	17	0	2	17	0	0	4.0	
i 1	531.0052176870748	0.505	75	1088	5	1	11	2	0	1	2	0	0	10.0	
i 1	531.0100340136055	0.2525	77	702	4	4	3	16	0	2	16	0	0	4.0	
i 1	531.2303333333333	0.505	75	590	5	1	14	2	0	1	2	0	0	10.0	
i 1	531.233544217687	0.505	71	590	6	5	2	2	0	-1	2	0	0	6.0	
i 1	531.2568231292518	3.0300000000000002	77	1088	6	2	14	16	0	1	16	0	0	4.0	
i 1	531.483544217687	0.2525	74	702	6	5	12	8	0	-2	8	0	0	6.0	
i 1	531.4891632653062	0.2525	77	204	6	9	11	17	0	2	17	0	0	3.0	
i 1	531.4963877551021	0.2525	75	702	3	24	12	2	0	1	2	0	0	11.0	
i 1	531.5028095238096	1.01	73	702	2	24	14	17	0	2	17	0	0	4.0	
i 1	531.7319387755102	5.05	63	702	4	19	12	16	0	1	16	0	0	3.506464741742853	
i 1	531.7343469387755	5.05	61	702	4	19	9	1	0	2	1	0	0	3.506464741742853	
i 1	531.7375578231292	0.505	74	590	4	4	8	16	0	1	16	0	0	4.0	
i 1	531.7415714285714	6.0600000000000005	63	204	5	18	16	16	0	2	16	0	0	3.506464741742853	
i 1	531.7431768707482	0.505	74	702	6	5	9	8	0	-2	8	0	0	9.948905943535717	
i 1	531.7471904761904	0.505	74	590	5	3	8	17	0	1	17	0	0	4.0	
i 1	531.7487959183674	3.0300000000000002	61	204	5	18	9	1	0	2	1	0	0	3.506464741742853	
i 1	531.7495986394558	10.605	63	204	5	26	10	1	0	1	1	0	0	0.39147284124284637	
i 1	531.7520068027211	0.2525	75	590	4	24	4	2	0	-2	2	0	0	8.79455711903287	
i 1	531.7552176870748	0.7575000000000001	61	590	5	25	12	1	0	2	1	0	0	0.39147284124284637	
i 1	531.759231292517	5.05	63	1088	5	25	5	16	0	2	16	0	0	0.39147284124284637	
i 1	531.7600340136055	10.605	61	204	5	26	9	16	0	2	16	0	0	0.39147284124284637	
i 1	531.7624421768708	0.7575000000000001	71	590	6	5	14	2	0	-1	2	0	0	9.948905943535717	
i 1	531.7632448979592	0.7575000000000001	63	590	5	25	3	1	0	1	1	0	0	0.39147284124284637	
i 1	531.7656530612245	0.2525	74	204	7	5	2	8	0	-2	8	0	0	9.948905943535717	
i 1	531.766455782313	5.05	63	1088	5	25	3	16	0	1	16	0	0	0.39147284124284637	
i 1	531.7680612244898	0.7575000000000001	75	590	5	1	9	2	0	1	2	0	0	7.794557119032869	
i 1	531.7696666666667	0.505	75	1088	5	1	14	2	0	-2	2	0	0	7.794557119032869	
i 1	531.9827414965987	0.505	75	204	5	1	2	2	0	-2	2	0	0	7.794557119032869	
i 1	532.0004013605442	2.02	73	204	3	24	2	17	0	1	17	0	0	4.0	
i 1	532.2367551020408	0.2525	77	702	5	3	9	17	0	1	17	0	0	4.0	
i 1	532.2447823129252	0.2525	71	702	6	5	7	8	0	-1	8	0	0	9.948905943535717	
i 1	532.2471904761904	0.2525	74	204	6	9	16	17	0	1	17	0	0	3.0	
i 1	532.2504013605442	0.505	74	1088	6	5	1	8	0	-2	8	0	0	9.948905943535717	
i 1	532.2624421768708	0.505	75	702	3	24	3	2	0	1	2	0	0	8.79455711903287	
i 1	532.4811360544218	0.2525	77	386	5	3	1	17	0	2	17	0	0	4.0	
i 1	532.4819387755102	0.505	75	386	5	1	15	2	0	-2	2	0	0	7.794557119032869	
i 1	532.4867551020408	4.2925	61	386	5	25	1	1	0	2	1	0	0	0.39147284124284637	
i 1	532.4891632653062	0.505	71	386	6	5	5	2	0	-2	2	0	0	9.948905943535717	
i 1	532.490768707483	0.2525	77	386	4	4	5	16	0	1	16	0	0	4.0	
i 1	532.5004013605442	4.2925	61	386	5	25	3	16	0	1	16	0	0	0.39147284124284637	
i 1	532.5060204081633	3.535	75	1088	5	1	9	2	0	-2	2	0	0	7.794557119032869	
i 1	532.5172585034013	2.02	74	1088	6	5	4	8	0	-1	8	0	0	9.948905943535717	
i 1	532.7544149659864	0.2525	71	204	7	5	8	8	0	-1	8	0	0	9.948905943535717	
i 1	532.7576258503401	0.7575000000000001	72	204	5	1	11	2	0	-2	2	0	0	7.794557119032869	
i 1	532.7616394557823	0.505	77	702	4	4	5	16	0	2	16	0	0	4.0	
i 1	532.985149659864	0.505	71	702	6	5	16	8	0	-1	8	0	0	9.948905943535717	
i 1	533.0036122448979	0.2525	71	386	6	5	6	8	0	-2	8	0	0	9.948905943535717	
i 1	533.016455782313	0.2525	75	1088	5	1	12	2	0	1	2	0	0	7.794557119032869	
i 1	533.016455782313	0.2525	77	386	4	4	1	16	0	1	16	0	0	4.0	
i 1	533.0172585034013	0.2525	73	702	1	24	14	17	0	2	17	0	0	4.0	
i 1	533.2319387755102	0.2525	77	386	5	3	13	17	0	2	17	0	0	4.0	
i 1	533.2495986394558	2.7775	75	386	5	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	533.2672585034013	0.2525	77	702	5	3	15	17	0	1	17	0	0	4.0	
i 1	533.4843469387755	0.2525	75	1088	5	1	4	2	0	1	2	0	0	7.794557119032869	
i 1	533.5052176870748	2.02	74	1088	4	2	7	17	0	2	17	0	0	4.0	
i 1	533.5076258503401	0.505	74	204	7	5	6	8	0	-2	8	0	0	9.948905943535717	
i 1	533.5084285714286	0.2525	74	1088	6	5	6	8	0	-2	8	0	0	9.948905943535717	
i 1	533.7447823129252	0.2525	71	204	7	5	7	8	0	-1	8	0	0	9.948905943535717	
i 1	533.7576258503401	0.2525	75	386	4	24	2	2	0	-2	2	0	0	8.79455711903287	
i 1	533.9859523809524	0.505	75	702	3	24	4	2	0	1	2	0	0	8.79455711903287	
i 1	533.9955850340136	1.01	74	1088	6	5	12	8	0	-2	8	0	0	9.948905943535717	
i 1	533.9979931972789	0.2525	71	702	6	5	13	8	0	-1	8	0	0	9.948905943535717	
i 1	534.2303333333333	0.2525	77	386	4	4	4	16	0	1	16	0	0	4.0	
i 1	534.2319387755102	0.505	73	204	3	24	10	17	0	1	17	0	0	4.0	
i 1	534.233544217687	0.505	77	702	5	3	7	17	0	1	17	0	0	4.0	
i 1	534.2536122448979	0.2525	73	702	1	24	14	17	0	2	17	0	0	4.0	
i 1	534.2680612244898	1.5150000000000001	71	386	6	5	12	8	0	-2	8	0	0	9.948905943535717	
i 1	534.485149659864	0.2525	71	702	6	5	3	8	0	-1	8	0	0	9.948905943535717	
i 1	534.4963877551021	0.505	77	204	6	9	12	17	0	2	17	0	0	3.0	
i 1	534.5044149659864	0.2525	73	386	2	24	1	17	0	1	17	0	0	4.0	
i 1	534.5108367346938	0.2525	75	702	3	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	534.7319387755102	0.7575000000000001	76	702	1	24	2	17	0	1	17	0	0	4.0	
i 1	534.7383605442177	2.02	77	386	5	3	11	17	0	2	17	0	0	4.0	
i 1	534.7383605442177	2.02	61	702	3	27	14	16	0	1	16	0	0	12.738040549334222	
i 1	534.7447823129252	0.505	73	204	2	24	5	17	0	1	17	0	0	4.0	
i 1	534.7471904761904	0.2525	75	386	4	24	4	2	0	-2	2	0	0	8.79455711903287	
i 1	534.7624421768708	0.2525	74	204	7	5	12	8	0	-2	8	0	0	9.948905943535717	
i 1	535.0044149659864	0.2525	74	702	6	5	7	8	0	-2	8	0	0	9.948905943535717	
i 1	535.0076258503401	0.2525	77	386	4	4	8	16	0	1	16	0	0	4.0	
i 1	535.009231292517	0.505	71	204	7	5	14	8	0	-1	8	0	0	9.948905943535717	
i 1	535.0156530612245	1.7675	75	1088	5	1	2	2	0	1	2	0	0	7.794557119032869	
i 1	535.2367551020408	0.2525	77	702	5	3	7	17	0	1	17	0	0	4.0	
i 1	535.2399659863945	1.5150000000000001	74	1088	6	5	1	8	0	-2	8	0	0	9.948905943535717	
i 1	535.4923741496599	0.2525	76	386	2	24	4	16	0	1	16	0	0	4.0	
i 1	535.5036122448979	0.2525	74	702	6	5	16	8	0	-2	8	0	0	9.948905943535717	
i 1	535.5196666666667	1.2625	77	386	4	4	3	16	0	1	16	0	0	4.0	
i 1	535.7495986394558	0.2525	71	386	6	5	3	2	0	-2	2	0	0	9.948905943535717	
i 1	535.759231292517	1.01	73	702	2	24	5	17	0	2	17	0	0	4.0	
i 1	535.7632448979592	0.2525	71	702	6	5	7	8	0	-1	8	0	0	9.948905943535717	
i 1	536.0124421768708	0.2525	72	204	5	1	4	2	0	-2	2	0	0	7.794557119032869	
i 1	536.0196666666667	0.2525	75	702	4	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	536.2391632653062	0.2525	75	386	4	24	15	2	0	-2	2	0	0	8.79455711903287	
i 1	536.2487959183674	0.505	71	386	6	5	6	2	0	-2	2	0	0	9.948905943535717	
i 1	536.2552176870748	0.2525	74	702	6	5	11	8	0	-2	8	0	0	9.948905943535717	
i 1	536.2584285714286	0.7575000000000001	73	204	2	24	8	17	0	1	17	0	0	4.0	
i 1	536.2688639455782	0.2525	75	702	3	24	9	2	0	1	2	0	0	8.79455711903287	
i 1	536.5124421768708	0.2525	76	386	2	24	8	16	0	2	16	0	0	4.0	
i 1	536.7311360544218	1.01	61	204	1	27	9	16	0	248	16	308	0	12.738040549334222	
i 1	536.7311360544218	1.7675	76	204	1	24	5	16	0	2	16	0	0	4.0	
i 1	536.7327414965987	2.7775	72	590	5	1	12	2	0	-2	2	0	0	7.794557119032869	
i 1	536.7359523809524	0.505	77	906	4	2	15	17	0	2	17	0	0	4.0	
i 1	536.7359523809524	3.535	71	590	6	5	10	2	0	-2	2	0	0	9.948905943535717	
i 1	536.7383605442177	11.11	63	590	5	25	7	1	0	2	1	0	0	0.39147284124284637	
i 1	536.7391632653062	11.11	61	906	5	25	4	16	0	2	16	0	0	0.39147284124284637	
i 1	536.7391632653062	11.11	61	590	5	25	14	16	0	2	16	0	0	0.39147284124284637	
i 1	536.7447823129252	5.555	63	204	4	27	4	1	0	1	1	0	0	12.738040549334222	
i 1	536.7487959183674	2.02	77	906	4	2	13	16	0	1	16	0	0	4.0	
i 1	536.7536122448979	0.2525	71	590	6	5	10	2	0	-1	2	0	0	9.948905943535717	
i 1	536.7568231292518	11.11	63	906	5	25	1	1	0	2	1	0	0	0.39147284124284637	
i 1	536.7576258503401	5.555	63	204	5	19	12	16	0	2	16	0	0	3.506464741742853	
i 1	536.7656530612245	0.2525	74	906	6	5	9	8	0	-1	8	0	0	9.948905943535717	
i 1	536.7672585034013	4.04	63	204	5	19	12	16	0	2	16	0	0	3.506464741742853	
i 1	536.9819387755102	0.2525	74	590	5	3	15	17	0	2	17	0	0	4.0	
i 1	536.9987959183674	0.2525	74	906	6	5	11	8	0	-1	8	0	0	9.948905943535717	
i 1	536.9987959183674	0.2525	76	204	2	24	7	16	0	1	16	0	0	4.0	
i 1	537.009231292517	0.505	71	204	7	5	6	8	0	-1	8	0	0	9.948905943535717	
i 1	537.2319387755102	0.505	74	204	6	9	12	17	0	1	17	0	0	3.0	
i 1	537.2504013605442	0.505	74	204	6	3	15	17	0	2	17	0	0	4.0	
i 1	537.2608367346938	0.7575000000000001	72	204	5	1	1	2	0	-2	2	0	0	7.794557119032869	
i 1	537.4931768707482	0.2525	75	204	3	24	8	2	0	1	2	0	0	8.79455711903287	
i 1	537.5004013605442	0.505	74	906	6	5	5	8	0	-1	8	0	0	9.948905943535717	
i 1	537.740768707483	4.545	61	204	4	27	2	16	0	1	16	0	0	12.738040549334222	
i 1	537.7487959183674	0.2525	76	204	2	24	16	16	0	1	16	0	0	4.0	
i 1	537.759231292517	0.2525	74	590	4	3	15	17	0	2	17	0	0	4.0	
i 1	537.7624421768708	0.2525	77	204	6	9	10	17	0	2	17	0	0	3.0	
i 1	537.764850340136	1.01	75	906	4	1	7	2	0	1	2	0	0	7.794557119032869	
i 1	537.9803333333333	0.2525	74	204	6	3	10	17	0	2	17	0	0	4.0	
i 1	537.9843469387755	0.2525	71	204	7	5	16	8	0	-1	8	0	0	9.948905943535717	
i 1	537.9891632653062	0.505	71	204	7	5	2	8	0	-1	8	0	0	9.948905943535717	
i 1	538.0140476190476	0.2525	75	204	4	1	12	2	0	-2	2	0	0	7.794557119032869	
i 1	538.014850340136	2.2725	74	590	4	4	1	16	0	2	16	0	0	4.0	
i 1	538.2576258503401	0.505	74	906	6	5	12	8	0	-1	8	0	0	9.948905943535717	
i 1	538.2616394557823	0.505	77	204	6	9	2	17	0	2	17	0	0	3.0	
i 1	538.2656530612245	1.7675	73	204	2	24	2	17	0	1	17	0	0	4.0	
i 1	538.266455782313	0.2525	75	204	5	1	6	2	0	-2	2	0	0	7.794557119032869	
i 1	538.4987959183674	0.2525	71	590	6	5	6	2	0	-1	2	0	0	9.948905943535717	
i 1	538.5076258503401	0.505	72	204	5	1	2	2	0	-2	2	0	0	7.794557119032869	
i 1	538.7319387755102	0.2525	74	204	5	4	9	16	0	1	16	0	0	4.0	
i 1	538.7520068027211	0.7575000000000001	76	204	2	24	9	16	0	1	16	0	0	4.0	
i 1	538.7568231292518	0.505	71	204	7	5	4	8	0	-1	8	0	0	9.948905943535717	
i 1	538.759231292517	0.2525	75	204	5	1	5	2	0	-2	2	0	0	7.794557119032869	
i 1	538.759231292517	0.2525	74	204	6	5	6	8	0	-2	8	0	0	9.948905943535717	
i 1	538.7696666666667	0.505	77	906	4	2	9	17	0	2	17	0	0	4.0	
i 1	538.9947823129252	0.2525	77	906	4	2	13	16	0	1	16	0	0	4.0	
i 1	538.9955850340136	0.2525	73	590	2	24	11	16	0	1	16	0	0	4.0	
i 1	539.0084285714286	0.505	74	906	6	5	5	8	0	-1	8	0	0	9.948905943535717	
i 1	539.009231292517	2.02	75	906	4	1	3	2	0	1	2	0	0	7.794557119032869	
i 1	539.0180612244898	0.2525	75	204	4	1	8	2	0	-2	2	0	0	7.794557119032869	
i 1	539.2431768707482	0.2525	74	204	7	5	3	8	0	-2	8	0	0	9.948905943535717	
i 1	539.2463877551021	0.2525	76	204	1	24	7	17	0	2	17	0	0	4.0	
i 1	539.2504013605442	0.7575000000000001	72	204	5	1	7	2	0	-2	2	0	0	7.794557119032869	
i 1	539.2608367346938	0.505	74	590	4	3	7	17	0	2	17	0	0	4.0	
i 1	539.4843469387755	0.2525	74	204	6	5	8	8	0	-2	8	0	0	9.948905943535717	
i 1	539.4843469387755	0.505	71	204	7	5	7	8	0	-1	8	0	0	9.948905943535717	
i 1	539.5108367346938	0.2525	72	590	4	24	15	8	0	1	8	0	0	8.79455711903287	
i 1	539.7327414965987	0.7575000000000001	74	906	6	5	5	8	0	-1	8	0	0	9.948905943535717	
i 1	539.733544217687	1.5150000000000001	77	906	4	2	11	16	0	1	16	0	0	4.0	
i 1	539.735149659864	0.7575000000000001	76	204	2	24	13	16	0	1	16	0	0	4.0	
i 1	539.7399659863945	0.2525	72	906	5	1	13	2	0	-2	2	0	0	7.794557119032869	
i 1	539.983544217687	0.7575000000000001	74	906	6	5	15	8	0	-1	8	0	0	9.948905943535717	
i 1	540.2327414965987	0.505	71	204	7	5	7	8	0	-1	8	0	0	9.948905943535717	
i 1	540.4819387755102	1.2625	72	590	5	1	6	2	0	-2	2	0	0	7.794557119032869	
i 1	540.4963877551021	0.2525	71	204	7	5	4	8	0	-1	8	0	0	9.948905943535717	
i 1	540.7359523809524	0.2525	74	204	6	9	15	17	0	1	17	0	0	3.0	
i 1	540.7391632653062	1.01	74	906	5	5	16	8	0	-1	8	0	0	9.948905943535717	
i 1	540.7504013605442	0.2525	73	204	1	20	8	16	0	1	16	0	0	0.7587699775925509	
i 1	540.7528095238096	0.2525	71	590	6	5	3	2	0	-2	2	0	0	9.948905943535717	
i 1	540.7560204081633	2.02	77	906	4	2	8	17	0	2	17	0	0	4.0	
i 1	540.7560204081633	1.5150000000000001	76	204	2	20	12	16	0	1	16	0	0	0.7587699775925509	
i 1	540.7584285714286	0.2525	74	906	6	5	2	8	0	-1	8	0	0	9.948905943535717	
i 1	540.766455782313	1.01	76	204	2	20	8	17	0	1	17	0	0	0.7587699775925509	
i 1	540.9859523809524	0.7575000000000001	71	204	7	5	15	8	0	-1	8	0	0	9.948905943535717	
i 1	540.9891632653062	0.2525	73	204	2	24	6	17	0	1	17	0	0	4.758769977592551	
i 1	541.0068231292518	0.505	77	204	6	9	15	17	0	2	17	0	0	3.0	
i 1	541.0084285714286	2.2725	71	590	6	5	5	2	0	-1	2	0	0	9.948905943535717	
i 1	541.2367551020408	1.5150000000000001	75	906	4	1	5	2	0	1	2	0	0	7.794557119032869	
i 1	541.2423741496599	1.01	73	204	1	24	10	17	0	252	17	307	0	4.758769977592551	
i 1	541.2504013605442	1.01	73	204	2	20	9	17	0	2	17	0	0	0.7587699775925509	
i 1	541.2552176870748	0.2525	74	590	4	3	11	17	0	2	17	0	0	4.0	
i 1	541.264850340136	0.7575000000000001	73	204	1	24	16	16	0	2	16	0	0	4.758769977592551	
i 1	541.5028095238096	0.2525	74	204	6	9	7	17	0	1	17	0	0	3.0	
i 1	541.5052176870748	0.2525	72	590	4	24	12	8	0	1	8	0	0	8.79455711903287	
i 1	541.5052176870748	0.2525	77	906	4	2	5	16	0	1	16	0	0	4.0	
i 1	541.7447823129252	0.505	75	204	4	1	14	2	0	-2	2	0	0	7.794557119032869	
i 1	541.7447823129252	0.2525	76	204	2	20	5	17	0	1	17	0	0	0.7587699775925509	
i 1	541.7512040816326	0.505	75	204	4	24	14	2	0	1	2	0	0	8.79455711903287	
i 1	541.7528095238096	0.2525	74	906	6	5	11	8	0	-1	8	0	0	9.948905943535717	
i 1	541.7552176870748	0.2525	71	204	6	5	10	8	0	-1	8	0	0	9.948905943535717	
i 1	541.9883605442177	0.505	76	906	2	20	16	16	0	1	16	0	0	0.7587699775925509	
i 1	541.9883605442177	0.2525	73	590	2	24	4	16	0	2	16	0	0	4.758769977592551	
i 1	541.9995986394558	0.2525	71	204	7	5	13	8	0	-1	8	0	0	9.948905943535717	
i 1	542.0196666666667	0.2525	74	204	7	5	11	8	0	-2	8	0	0	9.948905943535717	
i 1	542.2311360544218	0.505	74	906	6	5	15	8	0	-1	8	0	0	9.948905943535717	
i 1	542.2375578231292	1.5150000000000001	63	203	5	19	15	1	0	1	1	0	0	3.506464741742853	
i 1	542.2415714285714	5.555	61	203	4	27	7	16	0	1	16	0	0	12.738040549334222	
i 1	542.2455850340136	5.555	61	1172	4	26	12	1	0	1	1	0	0	0.39147284124284637	
i 1	542.2471904761904	1.5150000000000001	72	590	5	1	4	2	0	-2	2	0	0	7.794557119032869	
i 1	542.2495986394558	0.2525	75	1172	5	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	542.2512040816326	0.2525	71	1172	6	5	1	8	0	-2	8	0	0	9.948905943535717	
i 1	542.2536122448979	0.2525	77	203	6	3	1	17	0	2	17	0	0	4.0	
i 1	542.2584285714286	5.555	63	1172	4	26	1	16	0	2	16	0	0	0.39147284124284637	
i 1	542.259231292517	5.555	61	203	4	27	3	1	0	2	1	0	0	12.738040549334222	
i 1	542.2624421768708	2.2725	76	1172	2	20	1	16	0	2	16	0	0	0.7587699775925509	
i 1	542.2696666666667	4.04	74	590	4	3	15	17	0	2	17	0	0	4.0	
i 1	542.4819387755102	2.02	74	906	5	5	9	8	0	-1	8	0	0	9.948905943535717	
i 1	542.4843469387755	0.505	74	1172	5	9	11	16	0	1	16	0	0	3.0	
i 1	542.4859523809524	0.7575000000000001	73	1172	2	24	16	17	0	1	17	0	0	4.758769977592551	
i 1	542.4923741496599	0.505	75	203	4	1	10	2	0	1	2	0	0	7.794557119032869	
i 1	542.4971904761904	0.2525	73	1172	2	20	6	16	0	1	16	0	0	0.7587699775925509	
i 1	542.5052176870748	0.2525	76	1172	2	20	16	16	0	2	16	0	0	0.7587699775925509	
i 1	542.5084285714286	0.2525	73	203	1	24	2	17	0	2	17	0	0	4.758769977592551	
i 1	542.7303333333333	0.505	76	906	2	20	2	16	0	2	16	0	0	0.7587699775925509	
i 1	542.7367551020408	0.505	76	590	2	24	8	17	0	2	17	0	0	4.758769977592551	
i 1	542.7455850340136	0.2525	71	203	7	5	9	2	0	-1	2	0	0	9.948905943535717	
i 1	542.7512040816326	0.505	75	1172	5	1	5	2	0	-2	2	0	0	7.794557119032869	
i 1	542.7552176870748	0.7575000000000001	73	203	1	24	13	17	0	2	17	0	0	4.758769977592551	
i 1	542.7632448979592	0.2525	74	590	4	4	16	16	0	2	16	0	0	4.0	
i 1	542.9827414965987	0.2525	77	1172	5	9	14	17	0	2	17	0	0	3.0	
i 1	543.0020068027211	0.2525	74	203	7	5	9	2	0	-2	2	0	0	9.948905943535717	
i 1	543.0028095238096	0.2525	72	203	4	24	9	2	0	-2	2	0	0	8.79455711903287	
i 1	543.0044149659864	0.505	77	203	6	3	8	17	0	2	17	0	0	4.0	
i 1	543.2391632653062	0.2525	72	590	4	24	8	8	0	1	8	0	0	8.79455711903287	
i 1	543.2479931972789	1.5150000000000001	73	1172	2	20	9	16	0	2	16	0	0	0.7587699775925509	
i 1	543.2624421768708	0.2525	75	906	4	1	10	2	0	1	2	0	0	7.794557119032869	
i 1	543.4819387755102	0.2525	73	1172	2	20	9	16	0	1	16	0	0	0.7587699775925509	
i 1	543.4891632653062	0.2525	74	1172	5	9	15	16	0	1	16	0	0	3.0	
i 1	543.5004013605442	0.505	71	590	6	5	3	2	0	-1	2	0	0	9.948905943535717	
i 1	543.5132448979592	0.505	77	906	4	2	2	17	0	2	17	0	0	4.0	
i 1	543.5140476190476	0.2525	71	1172	6	5	1	8	0	-1	8	0	0	9.948905943535717	
i 1	543.7327414965987	0.7575000000000001	72	590	4	24	13	8	0	1	8	0	0	8.79455711903287	
i 1	543.7327414965987	1.2625	74	590	4	4	8	16	0	2	16	0	0	4.0	
i 1	543.7512040816326	1.5150000000000001	72	590	4	1	4	2	0	-2	2	0	0	7.794557119032869	
i 1	543.7640476190476	1.2625	73	1172	2	24	10	17	0	1	17	0	0	4.758769977592551	
i 1	543.9875578231292	0.7575000000000001	74	906	5	5	9	8	0	-1	8	0	0	9.948905943535717	
i 1	543.9899659863945	0.2525	77	906	4	2	6	16	0	1	16	0	0	4.0	
i 1	543.9915714285714	0.2525	71	203	7	5	14	2	0	-1	2	0	0	9.948905943535717	
i 1	543.9979931972789	0.7575000000000001	73	1172	2	20	12	16	0	1	16	0	0	0.7587699775925509	
i 1	544.2415714285714	0.2525	74	203	5	4	8	17	0	1	17	0	0	4.0	
i 1	544.2447823129252	3.2825	71	590	6	5	5	2	0	-2	2	0	0	9.948905943535717	
i 1	544.4827414965987	2.2725	75	906	4	1	3	2	0	1	2	0	0	7.794557119032869	
i 1	544.4859523809524	0.7575000000000001	73	203	1	24	16	17	0	2	17	0	0	4.758769977592551	
i 1	544.4883605442177	0.2525	74	203	5	5	9	2	0	-2	2	0	0	9.948905943535717	
i 1	544.733544217687	0.2525	76	906	2	20	3	17	0	1	17	0	0	0.7587699775925509	
i 1	544.735149659864	0.2525	73	906	2	20	1	16	0	1	16	0	0	0.7587699775925509	
i 1	544.7455850340136	0.2525	71	1172	6	5	12	8	0	-1	8	0	0	9.948905943535717	
i 1	544.759231292517	0.2525	73	590	2	24	7	16	0	1	16	0	0	4.758769977592551	
i 1	544.766455782313	0.2525	71	590	6	5	7	2	0	-1	2	0	0	9.948905943535717	
i 1	544.7680612244898	1.01	73	203	1	20	9	16	0	1	16	0	0	0.7587699775925509	
i 1	544.7696666666667	0.2525	72	906	4	1	7	2	0	-2	2	0	0	7.794557119032869	
i 1	544.9819387755102	0.2525	76	1172	2	20	6	16	0	2	16	0	0	0.7587699775925509	
i 1	544.9827414965987	0.505	73	203	1	24	8	17	0	2	17	0	0	4.758769977592551	
i 1	544.9859523809524	0.7575000000000001	72	590	4	24	1	8	0	1	8	0	0	8.79455711903287	
i 1	545.0180612244898	0.505	74	1172	4	9	8	16	0	1	16	0	0	3.0	
i 1	545.2455850340136	0.7575000000000001	76	1172	2	20	5	16	0	2	16	0	0	0.7587699775925509	
i 1	545.2520068027211	0.2525	72	906	4	1	11	2	0	-2	2	0	0	7.794557119032869	
i 1	545.2536122448979	0.2525	74	906	5	5	4	8	0	-1	8	0	0	9.948905943535717	
i 1	545.2608367346938	0.505	71	590	6	5	7	2	0	-1	2	0	0	9.948905943535717	
i 1	545.4811360544218	0.7575000000000001	76	906	2	20	13	16	0	1	16	0	0	0.7587699775925509	
i 1	545.4819387755102	2.2725	73	203	1	24	16	17	0	2	17	0	0	4.758769977592551	
i 1	545.4891632653062	0.2525	75	1172	5	1	3	2	0	-2	2	0	0	7.794557119032869	
i 1	545.4971904761904	0.7575000000000001	76	906	2	20	3	17	0	1	17	0	0	0.7587699775925509	
i 1	545.5020068027211	0.2525	73	590	2	24	4	17	0	2	17	0	0	4.758769977592551	
i 1	545.5060204081633	2.2725	77	906	4	2	4	17	0	2	17	0	0	4.0	
i 1	545.5188639455782	0.505	71	1172	6	5	15	8	0	-2	8	0	0	9.948905943535717	
i 1	545.7479931972789	0.2525	74	906	5	5	5	8	0	-1	8	0	0	9.948905943535717	
i 1	545.7656530612245	0.2525	77	1172	5	9	9	17	0	2	17	0	0	3.0	
i 1	545.9891632653062	0.505	77	906	4	2	8	16	0	1	16	0	0	4.0	
i 1	545.9939795918367	1.7675	73	1172	2	24	4	17	0	1	17	0	0	4.758769977592551	
i 1	545.9955850340136	0.505	75	203	4	1	10	2	0	1	2	0	0	7.794557119032869	
i 1	545.9987959183674	0.505	71	1172	6	5	11	8	0	-1	8	0	0	9.948905943535717	
i 1	546.0020068027211	0.2525	72	906	4	1	6	2	0	-2	2	0	0	7.794557119032869	
i 1	546.0132448979592	0.2525	74	203	5	5	6	2	0	-2	2	0	0	9.948905943535717	
i 1	546.2327414965987	0.2525	76	1172	2	20	3	17	0	2	17	0	0	0.7587699775925509	
i 1	546.2423741496599	0.7575000000000001	76	1172	2	20	1	16	0	2	16	0	0	0.7587699775925509	
i 1	546.2504013605442	1.5150000000000001	72	590	4	1	4	2	0	-2	2	0	0	7.794557119032869	
i 1	546.2584285714286	0.2525	74	590	4	4	2	16	0	2	16	0	0	4.0	
i 1	546.4883605442177	0.2525	74	906	5	5	12	8	0	-1	8	0	0	9.948905943535717	
i 1	546.4915714285714	0.505	74	203	5	5	2	2	0	-2	2	0	0	9.948905943535717	
i 1	546.4995986394558	0.2525	74	203	5	4	15	17	0	1	17	0	0	4.0	
i 1	546.5084285714286	0.2525	75	1172	5	1	9	2	0	-2	2	0	0	7.794557119032869	
i 1	546.5180612244898	0.2525	74	590	4	3	13	17	0	2	17	0	0	4.0	
i 1	546.7327414965987	0.2525	72	203	4	24	9	2	0	-2	2	0	0	8.79455711903287	
i 1	546.733544217687	0.505	75	1172	5	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	546.7367551020408	1.01	63	906	5	17	15	16	0	2	16	0	0	3.506464741742853	
i 1	546.7512040816326	1.01	77	906	4	2	5	16	0	1	16	0	0	4.0	
i 1	546.7536122448979	0.505	71	1172	6	5	2	8	0	-2	8	0	0	9.948905943535717	
i 1	546.990768707483	0.7575000000000001	75	906	4	1	13	2	0	1	2	0	0	7.794557119032869	
i 1	547.0028095238096	0.7575000000000001	74	906	5	5	8	8	0	-1	8	0	0	9.948905943535717	
i 1	547.0068231292518	0.2525	73	906	2	20	13	16	0	2	16	0	0	0.7587699775925509	
i 1	547.0116394557823	0.2525	73	906	2	20	2	16	0	1	16	0	0	0.7587699775925509	
i 1	547.2359523809524	0.505	73	1172	2	20	6	17	0	2	17	0	0	0.7587699775925509	
i 1	547.2463877551021	0.505	73	1172	2	20	2	16	0	1	16	0	0	0.7587699775925509	
i 1	547.2560204081633	0.505	72	906	4	1	5	2	0	-2	2	0	0	7.794557119032869	
i 1	547.259231292517	0.2525	71	203	5	5	10	2	0	-1	2	0	0	9.948905943535717	
i 1	547.2680612244898	0.505	73	203	1	24	10	17	0	252	17	307	0	4.758769977592551	
i 1	547.4803333333333	0.2525	71	590	5	5	15	2	0	-1	2	0	0	9.948905943535717	
i 1	547.5020068027211	0.2525	71	1172	6	5	15	8	0	-1	8	0	0	9.948905943535717	
i 1	547.7359523809524	1.7675	72	698	4	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	547.7359523809524	2.02	63	698	5	25	4	1	0	2	1	0	0	0.39147284124284637	
i 1	547.7359523809524	23.23	63	698	3	27	15	1	0	2	1	0	0	12.738040549334222	
i 1	547.7423741496599	1.7675	74	698	4	2	7	17	0	2	17	0	0	4.0	
i 1	547.7423741496599	3.535	73	1084	1	24	5	17	0	1	17	0	0	4.758769977592551	
i 1	547.7471904761904	0.2525	75	200	4	1	5	2	0	1	2	0	0	7.794557119032869	
i 1	547.7471904761904	0.2525	76	1084	1	20	2	17	0	2	17	0	0	0.7587699775925509	
i 1	547.7479931972789	0.2525	72	200	4	24	11	8	0	-2	8	0	0	8.79455711903287	
i 1	547.7512040816326	20.2	61	698	3	27	1	16	0	2	16	0	0	12.738040549334222	
i 1	547.7552176870748	17.17	63	1084	4	26	14	16	0	1	16	0	0	0.39147284124284637	
i 1	547.7584285714286	0.7575000000000001	74	200	4	4	13	16	0	2	16	0	0	4.0	
i 1	547.7584285714286	11.11	61	200	6	25	12	16	0	2	16	0	0	0.39147284124284637	
i 1	547.7584285714286	1.01	74	698	5	5	14	2	0	-2	2	0	0	9.948905943535717	
i 1	547.759231292517	8.08	63	200	6	25	15	1	0	1	1	0	0	0.39147284124284637	
i 1	547.7616394557823	0.2525	76	1084	1	20	4	17	0	2	17	0	0	0.7587699775925509	
i 1	547.7624421768708	5.05	61	698	5	25	7	16	0	1	16	0	0	0.39147284124284637	
i 1	547.7624421768708	14.14	61	1084	4	26	15	1	0	2	1	0	0	0.39147284124284637	
i 1	547.7632448979592	20.2	61	698	5	17	14	1	0	2	1	0	0	3.506464741742853	
i 1	547.7656530612245	1.7675	71	200	5	5	6	8	0	-2	8	0	0	9.948905943535717	
i 1	547.7696666666667	0.505	71	1084	5	5	8	2	0	-2	2	0	0	9.948905943535717	
i 1	547.9875578231292	0.2525	75	698	4	1	12	8	0	-2	8	0	0	7.794557119032869	
i 1	547.9875578231292	0.2525	72	698	3	24	3	2	0	-2	2	0	0	8.79455711903287	
i 1	547.9947823129252	0.2525	73	698	2	20	6	16	0	2	16	0	0	0.7587699775925509	
i 1	547.9995986394558	0.2525	76	698	2	20	15	17	0	1	17	0	0	0.7587699775925509	
i 1	548.2319387755102	0.2525	73	1084	1	20	10	17	0	2	17	0	0	0.7587699775925509	
i 1	548.235149659864	0.2525	73	1084	1	20	10	17	0	2	17	0	0	0.7587699775925509	
i 1	548.2367551020408	0.2525	77	698	4	2	4	16	0	1	16	0	0	4.0	
i 1	548.2391632653062	0.2525	71	698	4	5	16	8	0	-1	8	0	0	9.948905943535717	
i 1	548.2608367346938	0.7575000000000001	75	1084	4	1	12	2	0	-2	2	0	0	7.794557119032869	
i 1	548.485149659864	0.505	71	1084	5	5	5	2	0	-2	2	0	0	9.948905943535717	
i 1	548.4867551020408	0.505	73	698	2	20	1	17	0	2	17	0	0	0.7587699775925509	
i 1	548.4955850340136	0.505	76	698	2	20	1	16	0	2	16	0	0	0.7587699775925509	
i 1	548.5004013605442	0.7575000000000001	74	1084	3	9	11	16	0	1	16	0	0	3.0	
i 1	548.5156530612245	0.505	74	1084	3	9	5	17	0	2	17	0	0	3.0	
i 1	548.5196666666667	0.2525	72	200	4	24	7	8	0	-2	8	0	0	8.79455711903287	
i 1	548.7487959183674	0.2525	71	200	6	5	15	2	0	-1	2	0	0	9.948905943535717	
i 1	548.7495986394558	1.01	75	200	4	1	3	2	0	1	2	0	0	7.794557119032869	
i 1	548.9819387755102	0.505	76	1084	1	20	4	16	0	2	16	0	0	0.7587699775925509	
i 1	548.9827414965987	1.7675	74	698	5	5	14	2	0	-1	2	0	0	9.948905943535717	
i 1	548.983544217687	0.7575000000000001	77	698	4	2	1	16	0	1	16	0	0	4.0	
i 1	549.0124421768708	0.2525	71	698	4	5	16	2	0	-1	2	0	0	9.948905943535717	
i 1	549.014850340136	0.2525	72	698	3	1	16	2	0	1	2	0	0	7.794557119032869	
i 1	549.014850340136	0.505	76	1084	1	20	9	16	0	2	16	0	0	0.7587699775925509	
i 1	549.2423741496599	1.2625	72	200	4	24	2	8	0	-2	8	0	0	8.79455711903287	
i 1	549.2624421768708	0.2525	74	200	4	3	10	17	0	1	17	0	0	4.0	
i 1	549.2632448979592	2.02	74	698	5	5	6	2	0	-2	2	0	0	9.948905943535717	
i 1	549.4811360544218	0.2525	76	698	2	20	2	17	0	1	17	0	0	0.7587699775925509	
i 1	549.4923741496599	0.2525	76	698	2	20	7	16	0	1	16	0	0	0.7587699775925509	
i 1	549.4931768707482	0.2525	74	1084	3	9	10	17	0	2	17	0	0	3.0	
i 1	549.4995986394558	0.2525	72	698	3	24	2	2	0	-2	2	0	0	8.79455711903287	
i 1	549.5052176870748	0.505	74	200	4	4	11	16	0	2	16	0	0	4.0	
i 1	549.5172585034013	0.2525	71	698	4	5	6	2	0	-1	2	0	0	9.948905943535717	
i 1	549.7311360544218	0.2525	76	1084	1	20	1	17	0	2	17	0	0	0.7587699775925509	
i 1	549.7319387755102	0.2525	71	1084	5	5	7	2	0	-2	2	0	0	9.948905943535717	
i 1	549.7367551020408	0.2525	73	1084	2	20	12	16	0	1	16	0	0	0.7587699775925509	
i 1	549.7391632653062	21.21	61	698	5	17	2	1	0	1	1	0	0	3.506464741742853	
i 1	549.7471904761904	0.2525	75	1084	3	1	14	2	0	-2	2	0	0	7.794557119032869	
i 1	549.7479931972789	0.505	74	200	4	3	3	17	0	1	17	0	0	4.0	
i 1	549.7552176870748	0.505	72	1084	4	1	1	8	0	-2	8	0	0	7.794557119032869	
i 1	549.764850340136	12.120000000000001	63	698	5	25	16	1	0	2	1	0	0	0.39147284124284637	
i 1	549.766455782313	1.2625	77	698	6	2	6	16	0	1	16	0	0	4.0	
i 1	549.9899659863945	0.2525	74	698	2	3	3	16	0	1	16	0	0	4.0	
i 1	550.0116394557823	3.7875	75	200	4	1	3	2	0	1	2	0	0	7.794557119032869	
i 1	550.2375578231292	0.2525	74	1084	3	9	2	17	0	2	17	0	0	3.0	
i 1	550.2447823129252	0.2525	73	1084	1	20	7	16	0	1	16	0	0	0.7587699775925509	
i 1	550.2487959183674	0.2525	74	1084	3	9	16	16	0	1	16	0	0	3.0	
i 1	550.2552176870748	0.2525	73	1084	2	20	1	16	0	2	16	0	0	0.7587699775925509	
i 1	550.4819387755102	0.2525	72	1084	4	1	12	8	0	-2	8	0	0	7.794557119032869	
i 1	550.483544217687	0.2525	72	698	3	24	14	2	0	-2	2	0	0	8.79455711903287	
i 1	550.483544217687	0.505	76	698	2	20	7	17	0	1	17	0	0	0.7587699775925509	
i 1	550.4867551020408	0.505	76	200	1	24	5	17	0	252	17	307	0	4.758769977592551	
i 1	550.5124421768708	2.2725	74	200	4	4	12	16	0	2	16	0	0	4.0	
i 1	550.5140476190476	0.505	76	698	3	20	13	17	0	2	17	0	0	0.7587699775925509	
i 1	550.5180612244898	1.01	74	200	4	3	9	17	0	1	17	0	0	4.0	
i 1	550.7383605442177	0.505	72	200	4	24	13	8	0	-2	8	0	0	8.79455711903287	
i 1	550.7552176870748	3.2825	71	200	5	5	13	2	0	-1	2	0	0	9.948905943535717	
i 1	550.7672585034013	0.2525	75	1084	3	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	550.9803333333333	0.505	72	698	3	24	14	2	0	-2	2	0	0	8.79455711903287	
i 1	550.9923741496599	0.2525	73	1084	2	20	15	17	0	1	17	0	0	0.7587699775925509	
i 1	550.9995986394558	0.7575000000000001	73	1084	1	20	4	16	0	1	16	0	0	0.7587699775925509	
i 1	551.0100340136055	0.2525	77	698	4	4	14	17	0	1	17	0	0	4.0	
i 1	551.2495986394558	0.2525	72	698	3	1	7	2	0	1	2	0	0	7.794557119032869	
i 1	551.2656530612245	0.2525	74	1084	3	9	14	17	0	2	17	0	0	3.0	
i 1	551.4819387755102	0.2525	72	1084	4	1	14	8	0	-2	8	0	0	7.794557119032869	
i 1	551.4819387755102	0.505	74	698	2	3	5	16	0	1	16	0	0	4.0	
i 1	551.4859523809524	0.505	71	1084	5	5	4	2	0	-1	2	0	0	9.948905943535717	
i 1	551.4859523809524	1.01	73	1084	1	24	14	17	0	1	17	0	0	4.758769977592551	
i 1	551.4979931972789	0.7575000000000001	74	1084	3	9	2	16	0	1	16	0	0	3.0	
i 1	551.5124421768708	0.2525	73	1084	2	20	9	17	0	1	17	0	0	0.7587699775925509	
i 1	551.5196666666667	1.2625	72	698	4	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	551.7391632653062	0.505	73	698	2	20	5	16	0	1	16	0	0	0.7587699775925509	
i 1	551.7552176870748	0.505	73	698	3	20	8	17	0	1	17	0	0	0.7587699775925509	
i 1	551.9803333333333	0.2525	74	698	4	2	9	17	0	2	17	0	0	4.0	
i 1	552.2327414965987	0.2525	72	698	3	1	16	2	0	1	2	0	0	7.794557119032869	
i 1	552.2471904761904	0.2525	74	1084	3	9	10	17	0	2	17	0	0	3.0	
i 1	552.2495986394558	0.505	73	1084	1	20	8	16	0	1	16	0	0	0.7587699775925509	
i 1	552.2584285714286	0.505	71	1084	5	5	15	2	0	-2	2	0	0	9.948905943535717	
i 1	552.2584285714286	0.2525	73	1084	2	20	7	16	0	2	16	0	0	0.7587699775925509	
i 1	552.259231292517	2.02	74	200	4	3	6	17	0	1	17	0	0	4.0	
i 1	552.2696666666667	3.7875	76	698	1	24	12	16	0	252	16	307	0	4.758769977592551	
i 1	552.5132448979592	0.7575000000000001	72	698	3	24	8	2	0	-2	2	0	0	8.79455711903287	
i 1	552.7399659863945	0.2525	75	1084	3	1	12	2	0	-2	2	0	0	7.794557119032869	
i 1	552.7439795918367	20.2	61	200	5	17	12	16	0	1	16	0	0	3.506464741742853	
i 1	552.7447823129252	0.2525	73	1084	1	24	8	17	0	1	17	0	0	4.758769977592551	
i 1	552.7504013605442	0.505	74	1084	3	9	5	16	0	1	16	0	0	3.0	
i 1	552.7520068027211	1.7675	73	1084	2	20	4	16	0	1	16	0	0	0.7587699775925509	
i 1	552.7616394557823	0.2525	74	1084	3	9	13	17	0	2	17	0	0	3.0	
i 1	552.7632448979592	12.120000000000001	61	698	5	25	12	16	0	1	16	0	0	0.39147284124284637	
i 1	552.9819387755102	0.505	74	200	4	4	16	16	0	2	16	0	0	4.0	
i 1	553.0004013605442	0.2525	76	1084	1	20	15	17	0	2	17	0	0	0.7587699775925509	
i 1	553.0028095238096	0.7575000000000001	72	698	3	1	13	2	0	1	2	0	0	7.794557119032869	
i 1	553.2327414965987	0.2525	74	698	5	5	8	2	0	-1	2	0	0	9.948905943535717	
i 1	553.2399659863945	2.525	72	698	4	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	553.2520068027211	0.2525	71	698	4	5	9	8	0	-1	8	0	0	9.948905943535717	
i 1	553.264850340136	0.2525	74	698	2	3	12	16	0	1	16	0	0	4.0	
i 1	553.4811360544218	0.2525	74	698	6	2	7	17	0	2	17	0	0	4.0	
i 1	553.5076258503401	2.02	74	698	5	5	12	2	0	-2	2	0	0	9.948905943535717	
i 1	553.514850340136	0.505	71	1084	5	5	2	2	0	-2	2	0	0	9.948905943535717	
i 1	553.5180612244898	0.2525	74	1084	3	9	14	17	0	2	17	0	0	3.0	
i 1	553.7319387755102	1.5150000000000001	73	1084	2	20	13	16	0	2	16	0	0	0.7587699775925509	
i 1	553.740768707483	0.7575000000000001	72	200	4	24	7	8	0	-2	8	0	0	8.79455711903287	
i 1	553.7487959183674	0.2525	74	1084	3	9	4	16	0	1	16	0	0	3.0	
i 1	553.7504013605442	1.7675	76	1084	1	20	16	17	0	2	17	0	0	0.7587699775925509	
i 1	553.7608367346938	0.505	75	1084	3	1	2	2	0	-2	2	0	0	7.794557119032869	
i 1	553.7656530612245	1.5150000000000001	77	698	6	2	1	16	0	1	16	0	0	4.0	
i 1	553.990768707483	0.2525	71	1084	4	5	13	2	0	-1	2	0	0	9.948905943535717	
i 1	554.0012040816326	0.7575000000000001	71	698	4	5	10	8	0	-1	8	0	0	9.948905943535717	
i 1	554.0044149659864	0.505	74	698	6	2	1	17	0	2	17	0	0	4.0	
i 1	554.2447823129252	0.2525	72	698	3	1	14	2	0	1	2	0	0	7.794557119032869	
i 1	554.2520068027211	0.2525	74	200	4	4	14	16	0	2	16	0	0	4.0	
i 1	554.2624421768708	0.2525	71	200	5	5	6	2	0	-1	2	0	0	9.948905943535717	
i 1	554.4987959183674	0.505	75	1084	3	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	554.5116394557823	0.2525	74	1084	3	9	10	17	0	2	17	0	0	3.0	
i 1	554.5116394557823	0.2525	74	698	2	3	14	16	0	1	16	0	0	4.0	
i 1	554.5116394557823	0.2525	73	1084	1	24	16	17	0	1	17	0	0	4.758769977592551	
i 1	554.5180612244898	0.2525	72	1084	3	1	2	8	0	-2	8	0	0	7.794557119032869	
i 1	554.7327414965987	1.2625	73	1084	2	20	1	16	0	1	16	0	0	0.7587699775925509	
i 1	554.7399659863945	0.7575000000000001	75	200	4	1	13	2	0	1	2	0	0	7.794557119032869	
i 1	554.7552176870748	1.01	74	200	4	3	6	17	0	1	17	0	0	4.0	
i 1	554.9971904761904	0.2525	72	1084	3	1	11	8	0	-2	8	0	0	7.794557119032869	
i 1	555.0060204081633	0.7575000000000001	74	698	5	5	3	2	0	-1	2	0	0	9.948905943535717	
i 1	555.0084285714286	0.2525	71	1084	5	5	7	2	0	-2	2	0	0	9.948905943535717	
i 1	555.014850340136	0.2525	74	698	2	3	10	16	0	1	16	0	0	4.0	
i 1	555.2359523809524	0.505	74	200	4	4	5	16	0	2	16	0	0	4.0	
i 1	555.2423741496599	0.2525	77	698	2	4	8	17	0	1	17	0	0	4.0	
i 1	555.2680612244898	0.2525	75	1084	3	1	14	2	0	-2	2	0	0	7.794557119032869	
i 1	555.2680612244898	2.02	71	200	5	5	3	8	0	-2	8	0	0	9.948905943535717	
i 1	555.4963877551021	1.2625	73	1084	1	24	8	17	0	1	17	0	0	4.758769977592551	
i 1	555.5108367346938	0.505	71	1084	4	5	2	2	0	-1	2	0	0	9.948905943535717	
i 1	555.7327414965987	0.505	74	698	5	5	11	2	0	-2	2	0	0	9.948905943535717	
i 1	555.740768707483	2.02	75	200	4	1	4	2	0	1	2	0	0	7.794557119032869	
i 1	555.7471904761904	0.2525	72	698	2	1	10	2	0	1	2	0	0	7.794557119032869	
i 1	555.7495986394558	0.505	72	698	6	1	10	2	0	-2	2	0	0	7.794557119032869	
i 1	555.7495986394558	17.17	63	200	5	17	11	16	0	2	16	0	0	3.506464741742853	
i 1	555.7560204081633	12.120000000000001	63	200	6	25	12	1	0	1	1	0	0	0.39147284124284637	
i 1	555.7632448979592	0.2525	73	1084	2	20	2	16	0	2	16	0	0	0.7587699775925509	
i 1	555.7672585034013	1.01	74	200	6	3	4	17	0	1	17	0	0	4.0	
i 1	555.9875578231292	0.505	74	698	5	5	9	2	0	-1	2	0	0	9.948905943535717	
i 1	555.9955850340136	0.505	73	698	3	20	3	16	0	1	16	0	0	0.7587699775925509	
i 1	556.0052176870748	0.505	72	200	4	24	15	8	0	-2	8	0	0	8.79455711903287	
i 1	556.0124421768708	0.2525	76	200	2	24	15	17	0	1	17	0	0	4.758769977592551	
i 1	556.2303333333333	0.505	72	698	3	24	16	2	0	-2	2	0	0	8.79455711903287	
i 1	556.233544217687	1.7675	74	200	4	4	7	16	0	2	16	0	0	4.0	
i 1	556.2367551020408	0.505	71	698	4	5	10	8	0	-1	8	0	0	9.948905943535717	
i 1	556.2632448979592	0.2525	73	698	3	20	11	16	0	2	16	0	0	0.7587699775925509	
i 1	556.4803333333333	2.2725	76	1084	1	20	2	17	0	2	17	0	0	0.7587699775925509	
i 1	556.483544217687	0.7575000000000001	73	1084	2	20	3	17	0	2	17	0	0	0.7587699775925509	
i 1	556.4891632653062	0.2525	75	1084	3	1	11	2	0	-2	2	0	0	7.794557119032869	
i 1	556.4987959183674	0.505	76	1084	2	20	1	16	0	1	16	0	0	0.7587699775925509	
i 1	556.5044149659864	0.2525	71	200	5	5	4	2	0	-1	2	0	0	9.948905943535717	
i 1	556.735149659864	0.2525	75	698	4	1	14	8	0	-2	8	0	0	7.794557119032869	
i 1	556.7383605442177	0.2525	71	1084	4	5	6	2	0	-2	2	0	0	9.948905943535717	
i 1	556.7399659863945	1.01	74	698	5	5	1	2	0	-1	2	0	0	9.948905943535717	
i 1	556.7528095238096	0.2525	72	200	4	24	12	8	0	-2	8	0	0	8.79455711903287	
i 1	556.9811360544218	1.7675	74	698	5	5	5	2	0	-2	2	0	0	9.948905943535717	
i 1	556.9867551020408	0.505	74	200	6	3	5	17	0	1	17	0	0	4.0	
i 1	556.9947823129252	0.7575000000000001	73	1084	1	24	11	17	0	1	17	0	0	4.758769977592551	
i 1	556.9995986394558	0.2525	72	698	6	1	7	2	0	-2	2	0	0	7.794557119032869	
i 1	557.0140476190476	0.2525	72	698	2	1	13	2	0	1	2	0	0	7.794557119032869	
i 1	557.2439795918367	0.2525	71	1084	4	5	1	2	0	-1	2	0	0	9.948905943535717	
i 1	557.2455850340136	0.2525	76	698	3	20	9	16	0	1	16	0	0	0.7587699775925509	
i 1	557.2520068027211	1.2625	72	200	4	24	3	8	0	-2	8	0	0	8.79455711903287	
i 1	557.2656530612245	0.2525	74	698	2	3	14	16	0	1	16	0	0	4.0	
i 1	557.4819387755102	1.5150000000000001	74	698	6	2	13	17	0	2	17	0	0	4.0	
i 1	557.4859523809524	0.2525	71	1084	4	5	8	2	0	-2	2	0	0	9.948905943535717	
i 1	557.4995986394558	0.505	76	1084	2	20	3	16	0	1	16	0	0	0.7587699775925509	
i 1	557.5052176870748	0.505	77	698	2	4	7	17	0	1	17	0	0	4.0	
i 1	557.7512040816326	0.2525	72	698	2	1	9	2	0	1	2	0	0	7.794557119032869	
i 1	557.7560204081633	3.7875	71	200	5	5	12	2	0	-1	2	0	0	9.948905943535717	
i 1	557.7656530612245	0.2525	75	698	4	1	6	8	0	-2	8	0	0	7.794557119032869	
i 1	557.9803333333333	0.2525	74	698	2	3	13	16	0	1	16	0	0	4.0	
i 1	557.9819387755102	0.2525	72	698	6	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	557.9979931972789	0.7575000000000001	76	698	3	20	7	17	0	1	17	0	0	0.7587699775925509	
i 1	558.0044149659864	1.2625	75	200	4	1	1	2	0	1	2	0	0	7.794557119032869	
i 1	558.009231292517	0.2525	76	698	3	20	12	16	0	1	16	0	0	0.7587699775925509	
i 1	558.0172585034013	0.2525	74	200	6	3	11	17	0	1	17	0	0	4.0	
i 1	558.0172585034013	0.2525	71	1084	4	5	10	2	0	-2	2	0	0	9.948905943535717	
i 1	558.2528095238096	1.7675	77	698	6	2	10	16	0	1	16	0	0	4.0	
i 1	558.2608367346938	0.2525	74	200	4	4	10	16	0	2	16	0	0	4.0	
i 1	558.2672585034013	0.2525	71	200	5	5	7	8	0	-2	8	0	0	9.948905943535717	
i 1	558.4803333333333	0.2525	73	1084	1	24	10	17	0	1	17	0	0	4.758769977592551	
i 1	558.4859523809524	0.2525	77	698	2	4	12	17	0	1	17	0	0	4.0	
i 1	558.5076258503401	0.2525	71	698	4	5	15	8	0	-1	8	0	0	9.948905943535717	
i 1	558.7359523809524	0.505	71	1084	4	5	15	2	0	-2	2	0	0	9.948905943535717	
i 1	558.740768707483	1.01	76	1084	1	20	14	17	0	2	17	0	0	3.336144960550463	
i 1	558.7447823129252	14.14	63	1084	4	18	5	1	0	2	1	0	0	3.506464741742853	
i 1	558.7455850340136	0.2525	76	200	3	20	1	17	0	1	17	0	0	3.336144960550463	
i 1	558.7479931972789	0.7575000000000001	74	1084	3	9	8	17	0	2	17	0	0	3.0	
i 1	558.7528095238096	0.2525	72	200	4	24	5	8	0	-2	8	0	0	8.79455711903287	
i 1	558.7600340136055	0.2525	72	698	2	24	14	2	0	-2	2	0	0	8.79455711903287	
i 1	558.7656530612245	12.120000000000001	61	200	6	25	16	16	0	2	16	0	0	0.39147284124284637	
i 1	558.7672585034013	0.2525	76	698	3	20	8	17	0	1	17	0	0	3.336144960550463	
i 1	558.9843469387755	0.2525	71	698	4	5	15	8	0	-1	8	0	0	9.948905943535717	
i 1	558.9931768707482	0.7575000000000001	73	1084	2	20	7	16	0	1	16	0	0	3.336144960550463	
i 1	558.9955850340136	0.2525	74	698	2	3	8	16	0	1	16	0	0	4.0	
i 1	558.9979931972789	0.7575000000000001	76	1084	2	20	10	17	0	1	17	0	0	3.336144960550463	
i 1	558.9987959183674	3.0300000000000002	72	698	6	1	3	2	0	-2	2	0	0	7.794557119032869	
i 1	559.2303333333333	0.2525	75	698	6	1	16	8	0	-2	8	0	0	7.794557119032869	
i 1	559.2319387755102	1.01	72	200	4	24	16	8	0	-2	8	0	0	8.79455711903287	
i 1	559.2415714285714	0.2525	71	1084	4	5	11	2	0	-1	2	0	0	9.948905943535717	
i 1	559.2487959183674	0.505	74	200	5	4	1	16	0	2	16	0	0	4.0	
i 1	559.264850340136	0.2525	71	200	5	5	14	8	0	-2	8	0	0	9.948905943535717	
i 1	559.5132448979592	2.02	74	200	6	3	6	17	0	1	17	0	0	4.0	
i 1	559.5196666666667	0.505	72	698	2	1	7	2	0	1	2	0	0	7.794557119032869	
i 1	559.7383605442177	0.505	73	1084	1	24	10	17	0	1	17	0	0	7.336144960550463	
i 1	559.7487959183674	0.2525	74	698	6	2	13	17	0	2	17	0	0	4.0	
i 1	559.7504013605442	1.2625	71	1084	4	5	13	2	0	-1	2	0	0	9.948905943535717	
i 1	559.764850340136	0.505	76	698	3	20	14	17	0	1	17	0	0	3.336144960550463	
i 1	559.7672585034013	0.2525	76	200	3	20	12	17	0	1	17	0	0	3.336144960550463	
i 1	559.9947823129252	0.2525	76	698	3	20	6	16	0	1	16	0	0	3.336144960550463	
i 1	559.9971904761904	0.2525	75	1084	3	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	559.9987959183674	0.505	77	698	2	4	8	17	0	1	17	0	0	4.0	
i 1	560.0052176870748	0.7575000000000001	74	1084	3	9	7	17	0	2	17	0	0	3.0	
i 1	560.2552176870748	0.2525	75	698	6	1	7	8	0	-2	8	0	0	7.794557119032869	
i 1	560.2552176870748	0.2525	72	1084	3	1	12	8	0	-2	8	0	0	7.794557119032869	
i 1	560.2560204081633	0.2525	74	698	6	5	4	2	0	-1	2	0	0	9.948905943535717	
i 1	560.4883605442177	0.2525	74	200	5	4	12	16	0	2	16	0	0	4.0	
i 1	560.4971904761904	0.2525	73	698	3	20	12	17	0	2	17	0	0	3.336144960550463	
i 1	560.4995986394558	0.2525	73	698	3	20	14	16	0	2	16	0	0	3.336144960550463	
i 1	560.5020068027211	0.7575000000000001	75	200	4	1	2	2	0	1	2	0	0	7.794557119032869	
i 1	560.5100340136055	0.505	76	1084	1	20	9	17	0	2	17	0	0	3.336144960550463	
i 1	560.5180612244898	1.01	73	1084	1	24	1	17	0	1	17	0	0	7.336144960550463	
i 1	560.735149659864	0.2525	77	698	2	4	14	17	0	1	17	0	0	4.0	
i 1	560.7423741496599	0.7575000000000001	76	698	1	24	11	16	0	1	16	0	0	7.336144960550463	
i 1	560.7552176870748	0.505	77	698	6	2	6	16	0	1	16	0	0	4.0	
i 1	560.7616394557823	0.2525	74	698	5	5	4	2	0	-2	2	0	0	9.948905943535717	
i 1	560.9883605442177	1.2625	74	200	5	4	12	16	0	2	16	0	0	4.0	
i 1	560.9891632653062	0.2525	75	1084	3	1	9	2	0	-2	2	0	0	7.794557119032869	
i 1	560.9923741496599	0.2525	71	1084	4	5	7	2	0	-2	2	0	0	9.948905943535717	
i 1	561.0052176870748	0.2525	71	698	4	5	3	8	0	-1	8	0	0	9.948905943535717	
i 1	561.2431768707482	0.2525	74	698	2	3	1	16	0	1	16	0	0	4.0	
i 1	561.2447823129252	0.505	72	698	2	1	6	2	0	1	2	0	0	7.794557119032869	
i 1	561.2504013605442	0.2525	72	1084	3	1	8	8	0	-2	8	0	0	7.794557119032869	
i 1	561.2632448979592	0.505	74	698	5	5	7	2	0	-2	2	0	0	9.948905943535717	
i 1	561.2632448979592	0.7575000000000001	76	1084	1	20	4	17	0	2	17	0	0	3.336144960550463	
i 1	561.266455782313	0.7575000000000001	73	1084	2	20	15	17	0	2	17	0	0	3.336144960550463	
i 1	561.4947823129252	0.2525	77	698	6	2	11	16	0	1	16	0	0	4.0	
i 1	561.4955850340136	0.2525	77	698	2	4	13	17	0	1	17	0	0	4.0	
i 1	561.7319387755102	11.11	61	1084	4	18	3	1	0	1	1	0	0	3.506464741742853	
i 1	561.7327414965987	1.5150000000000001	75	200	6	1	14	2	0	1	2	0	0	7.794557119032869	
i 1	561.7447823129252	0.2525	74	698	2	3	6	16	0	1	16	0	0	4.0	
i 1	561.7455850340136	1.01	73	698	1	20	5	17	0	1	17	0	0	3.336144960550463	
i 1	561.7495986394558	1.7675	74	698	6	5	9	2	0	-2	2	0	0	9.948905943535717	
i 1	561.7512040816326	11.11	61	1084	4	26	4	1	0	2	1	0	0	0.39147284124284637	
i 1	561.9923741496599	0.2525	73	1084	2	24	16	17	0	1	17	0	0	7.336144960550463	
i 1	562.0052176870748	2.2725	74	200	6	3	5	17	0	1	17	0	0	4.0	
i 1	562.2399659863945	0.2525	73	1084	2	20	16	17	0	2	17	0	0	3.336144960550463	
i 1	562.2487959183674	0.505	72	200	4	24	10	8	0	-2	8	0	0	8.79455711903287	
i 1	562.4803333333333	0.2525	74	200	5	4	6	16	0	2	16	0	0	4.0	
i 1	562.4827414965987	0.2525	71	698	3	5	3	2	0	-1	2	0	0	9.948905943535717	
i 1	562.4979931972789	0.2525	74	1084	3	9	9	17	0	2	17	0	0	3.0	
i 1	562.516455782313	1.01	73	1084	2	24	4	17	0	1	17	0	0	7.336144960550463	
i 1	562.740768707483	0.2525	77	698	4	2	4	16	0	1	16	0	0	4.0	
i 1	562.740768707483	0.2525	77	698	2	4	12	17	0	1	17	0	0	4.0	
i 1	562.7600340136055	1.01	74	698	6	5	3	2	0	-1	2	0	0	9.948905943535717	
i 1	562.9899659863945	1.2625	72	698	6	1	8	2	0	-2	2	0	0	7.794557119032869	
i 1	563.0004013605442	0.2525	73	1084	2	20	7	17	0	2	17	0	0	3.336144960550463	
i 1	563.0012040816326	1.01	76	698	1	20	8	16	0	2	16	0	0	3.336144960550463	
i 1	563.0044149659864	1.7675	71	200	5	5	8	8	0	-2	8	0	0	9.948905943535717	
i 1	563.0156530612245	0.505	74	200	5	4	1	16	0	2	16	0	0	4.0	
i 1	563.2600340136055	0.505	74	1084	3	9	9	17	0	2	17	0	0	3.0	
i 1	563.485149659864	1.7675	77	698	4	2	1	16	0	1	16	0	0	4.0	
i 1	563.5076258503401	0.2525	71	698	3	5	6	2	0	-1	2	0	0	9.948905943535717	
i 1	563.735149659864	1.5150000000000001	75	200	6	1	2	2	0	1	2	0	0	7.794557119032869	
i 1	563.7536122448979	0.2525	75	698	6	1	9	8	0	-2	8	0	0	7.794557119032869	
i 1	563.7544149659864	0.2525	71	1084	4	5	4	2	0	-2	2	0	0	9.948905943535717	
i 1	563.7584285714286	0.2525	74	200	5	4	10	16	0	2	16	0	0	4.0	
i 1	563.766455782313	0.2525	74	698	6	5	14	2	0	-2	2	0	0	9.948905943535717	
i 1	563.9811360544218	0.2525	74	698	2	3	7	16	0	1	16	0	0	4.0	
i 1	563.9859523809524	2.02	74	698	6	5	1	2	0	-1	2	0	0	9.948905943535717	
i 1	564.0100340136055	0.2525	76	200	3	20	10	17	0	1	17	0	0	3.336144960550463	
i 1	564.014850340136	0.2525	71	698	3	5	2	8	0	-1	8	0	0	9.948905943535717	
i 1	564.2471904761904	0.2525	72	200	4	24	11	8	0	-2	8	0	0	8.79455711903287	
i 1	564.259231292517	0.2525	73	698	1	20	10	16	0	2	16	0	0	3.336144960550463	
i 1	564.4803333333333	0.2525	72	698	2	1	11	2	0	1	2	0	0	7.794557119032869	
i 1	564.485149659864	0.2525	72	698	2	24	6	2	0	-2	2	0	0	8.79455711903287	
i 1	564.4971904761904	0.2525	71	698	3	5	16	2	0	-1	2	0	0	9.948905943535717	
i 1	564.5052176870748	0.2525	74	698	2	3	8	16	0	1	16	0	0	4.0	
i 1	564.514850340136	0.2525	74	698	6	2	11	17	0	2	17	0	0	4.0	
i 1	564.7303333333333	0.7575000000000001	76	1084	2	20	14	17	0	2	17	0	0	3.336144960550463	
i 1	564.7367551020408	1.01	73	1084	2	24	4	17	0	1	17	0	0	7.336144960550463	
i 1	564.7383605442177	8.08	61	698	3	19	12	16	0	1	16	0	0	3.506464741742853	
i 1	564.7439795918367	0.2525	71	200	5	5	7	2	0	-1	2	0	0	9.948905943535717	
i 1	564.7447823129252	0.2525	73	698	3	20	3	17	0	2	17	0	0	3.336144960550463	
i 1	564.7479931972789	1.01	74	200	6	3	9	17	0	1	17	0	0	4.0	
i 1	564.7568231292518	0.2525	74	698	6	5	5	2	0	-2	2	0	0	9.948905943535717	
i 1	564.7640476190476	8.08	63	1084	4	26	12	16	0	1	16	0	0	0.39147284124284637	
i 1	564.7688639455782	0.2525	72	698	5	1	1	2	0	-2	2	0	0	7.794557119032869	
i 1	564.9803333333333	0.2525	73	1084	2	20	10	16	0	2	16	0	0	3.336144960550463	
i 1	564.9883605442177	1.7675	72	200	5	24	6	8	0	-2	8	0	0	8.79455711903287	
i 1	565.0076258503401	0.2525	71	200	7	5	10	8	0	-2	8	0	0	9.948905943535717	
i 1	565.2319387755102	0.505	72	698	5	1	1	2	0	-2	2	0	0	7.794557119032869	
i 1	565.2399659863945	0.2525	75	1084	3	1	4	2	0	-2	2	0	0	7.794557119032869	
i 1	565.2463877551021	2.2725	74	698	6	5	11	2	0	-2	2	0	0	9.948905943535717	
i 1	565.2471904761904	0.2525	74	1084	5	9	2	16	0	1	16	0	0	3.0	
i 1	565.2528095238096	0.2525	73	698	3	20	12	16	0	1	16	0	0	3.336144960550463	
i 1	565.4811360544218	0.505	74	698	4	2	12	17	0	2	17	0	0	4.0	
i 1	565.4883605442177	1.5150000000000001	74	200	5	4	3	16	0	2	16	0	0	4.0	
i 1	565.4931768707482	1.7675	76	1084	2	20	1	16	0	1	16	0	0	3.336144960550463	
i 1	565.5036122448979	0.2525	72	1084	3	1	16	8	0	-2	8	0	0	7.794557119032869	
i 1	565.5124421768708	0.2525	71	200	7	5	6	8	0	-2	8	0	0	9.948905943535717	
i 1	565.7383605442177	0.2525	74	698	2	3	11	16	0	1	16	0	0	4.0	
i 1	565.7479931972789	0.505	71	200	5	5	5	2	0	-1	2	0	0	9.948905943535717	
i 1	565.7680612244898	0.2525	73	698	1	24	2	17	0	1	17	0	0	7.336144960550463	
i 1	565.983544217687	0.505	76	1084	2	20	6	17	0	2	17	0	0	3.336144960550463	
i 1	565.9843469387755	1.01	75	200	6	1	10	2	0	1	2	0	0	7.794557119032869	
i 1	565.9955850340136	0.7575000000000001	76	1084	2	20	9	17	0	2	17	0	0	3.336144960550463	
i 1	566.0068231292518	0.505	74	1084	5	9	3	17	0	2	17	0	0	3.0	
i 1	566.016455782313	0.2525	75	1084	3	1	2	2	0	-2	2	0	0	7.794557119032869	
i 1	566.2303333333333	0.505	71	200	7	5	3	8	0	-2	8	0	0	9.948905943535717	
i 1	566.2656530612245	0.2525	71	698	3	5	15	2	0	-1	2	0	0	9.948905943535717	
i 1	566.4803333333333	0.2525	77	698	2	4	3	17	0	1	17	0	0	4.0	
i 1	566.5012040816326	0.2525	74	200	6	3	1	17	0	1	17	0	0	4.0	
i 1	566.509231292517	0.2525	71	1084	4	5	16	2	0	-1	2	0	0	9.948905943535717	
i 1	566.514850340136	1.01	72	698	5	1	15	2	0	-2	2	0	0	7.794557119032869	
i 1	566.7415714285714	2.02	74	698	4	2	9	17	0	2	17	0	0	4.0	
i 1	566.7560204081633	0.2525	72	1084	3	1	5	8	0	-2	8	0	0	7.794557119032869	
i 1	566.7616394557823	0.2525	74	1084	5	9	12	16	0	1	16	0	0	3.0	
i 1	566.985149659864	0.2525	74	698	6	5	1	2	0	-1	2	0	0	9.948905943535717	
i 1	567.0020068027211	0.2525	75	1084	3	1	1	2	0	-2	2	0	0	7.794557119032869	
i 1	567.2367551020408	1.7675	75	200	6	1	13	2	0	1	2	0	0	7.794557119032869	
i 1	567.2423741496599	0.2525	76	1084	2	20	14	17	0	2	17	0	0	3.336144960550463	
i 1	567.2536122448979	0.7575000000000001	76	698	1	20	16	17	0	1	17	0	0	3.336144960550463	
i 1	567.2616394557823	0.505	71	200	5	5	14	2	0	-1	2	0	0	9.948905943535717	
i 1	567.2640476190476	0.505	72	698	2	24	7	2	0	-2	2	0	0	8.79455711903287	
i 1	567.490768707483	0.2525	72	698	2	1	4	2	0	1	2	0	0	7.794557119032869	
i 1	567.5052176870748	0.2525	74	200	6	3	8	17	0	1	17	0	0	4.0	
i 1	567.5052176870748	0.2525	74	698	6	5	16	2	0	-1	2	0	0	9.948905943535717	
i 1	567.5188639455782	0.2525	74	200	5	4	4	16	0	2	16	0	0	4.0	
i 1	567.7303333333333	0.7575000000000001	76	1084	2	20	13	17	0	2	17	0	0	3.336144960550463	
i 1	567.7343469387755	1.7675	71	200	7	5	13	2	0	-1	2	0	0	9.948905943535717	
i 1	567.7367551020408	0.505	77	698	2	4	7	17	0	1	17	0	0	4.0	
i 1	567.7399659863945	0.2525	72	1084	3	1	9	8	0	-2	8	0	0	7.794557119032869	
i 1	567.7399659863945	5.05	61	698	5	14	12	1	0	1	1	0	0	2.551638712202796	
i 1	567.7423741496599	5.05	61	698	6	17	1	1	0	2	1	0	0	3.506464741742853	
i 1	567.7439795918367	0.2525	71	698	3	5	11	8	0	-1	8	0	0	9.948905943535717	
i 1	567.7495986394558	0.2525	72	698	5	1	12	2	0	-2	2	0	0	7.794557119032869	
i 1	567.7504013605442	5.05	61	698	3	27	13	16	0	2	16	0	0	12.738040549334222	
i 1	567.7544149659864	5.05	63	698	3	19	13	1	0	1	1	0	0	3.506464741742853	
i 1	567.7552176870748	1.01	76	1084	2	20	2	17	0	2	17	0	0	3.336144960550463	
i 1	567.9819387755102	0.2525	74	1084	5	9	13	16	0	1	16	0	0	3.0	
i 1	568.2375578231292	0.2525	74	698	4	5	12	2	0	-1	2	0	0	9.948905943535717	
i 1	568.2431768707482	0.2525	74	200	4	3	9	17	0	1	17	0	0	4.0	
i 1	568.2536122448979	1.5150000000000001	77	698	4	2	12	16	0	1	16	0	0	4.0	
i 1	568.2656530612245	0.505	71	1084	4	5	1	2	0	-2	2	0	0	9.948905943535717	
i 1	568.4899659863945	0.505	73	1084	2	24	12	17	0	1	17	0	0	7.336144960550463	
i 1	568.5004013605442	0.505	75	698	5	1	13	8	0	-2	8	0	0	7.794557119032869	
i 1	568.5180612244898	0.505	76	698	3	20	2	17	0	1	17	0	0	3.336144960550463	
i 1	568.7391632653062	0.2525	71	1084	4	5	3	2	0	-1	2	0	0	9.948905943535717	
i 1	568.740768707483	1.2625	76	698	1	24	6	17	0	2	17	0	0	7.336144960550463	
i 1	568.7455850340136	0.2525	74	200	5	4	8	16	0	2	16	0	0	4.0	
i 1	568.7504013605442	0.2525	76	698	3	20	3	16	0	1	16	0	0	3.336144960550463	
i 1	568.9811360544218	0.2525	74	698	4	5	9	2	0	-1	2	0	0	9.948905943535717	
i 1	568.9827414965987	0.2525	75	1084	5	1	8	2	0	-2	2	0	0	7.794557119032869	
i 1	568.9931768707482	2.525	73	1084	1	24	6	17	0	252	17	307	0	7.336144960550463	
i 1	569.0020068027211	1.5150000000000001	74	698	6	5	12	2	0	-2	2	0	0	9.948905943535717	
i 1	569.0076258503401	0.7575000000000001	72	698	5	1	8	2	0	-2	2	0	0	7.794557119032869	
i 1	569.0156530612245	0.7575000000000001	76	1084	2	20	12	17	0	1	17	0	0	3.336144960550463	
i 1	569.016455782313	0.505	77	698	2	4	6	17	0	1	17	0	0	4.0	
i 1	569.0196666666667	0.505	74	1084	5	9	3	17	0	2	17	0	0	3.0	
i 1	569.4811360544218	0.2525	72	698	2	1	16	2	0	1	2	0	0	7.794557119032869	
i 1	569.4859523809524	2.02	74	200	4	3	8	17	0	1	17	0	0	4.0	
i 1	569.4875578231292	1.2625	76	1084	2	20	9	17	0	2	17	0	0	3.336144960550463	
i 1	569.4915714285714	0.505	74	1084	5	9	8	16	0	1	16	0	0	3.0	
i 1	569.4971904761904	0.2525	71	1084	4	5	3	2	0	-2	2	0	0	9.948905943535717	
i 1	569.4995986394558	0.2525	75	1084	5	1	14	2	0	-2	2	0	0	7.794557119032869	
i 1	569.5012040816326	0.505	71	1084	4	5	5	2	0	-1	2	0	0	9.948905943535717	
i 1	569.735149659864	0.505	72	698	2	24	11	2	0	-2	2	0	0	8.79455711903287	
i 1	569.7367551020408	0.2525	71	698	3	5	15	2	0	-1	2	0	0	9.948905943535717	
i 1	569.7447823129252	0.2525	74	1084	5	9	11	17	0	2	17	0	0	3.0	
i 1	569.7479931972789	0.2525	73	698	3	20	13	16	0	2	16	0	0	3.336144960550463	
i 1	569.7512040816326	1.01	75	200	6	1	2	2	0	1	2	0	0	7.794557119032869	
i 1	569.7656530612245	0.2525	73	698	3	20	12	16	0	2	16	0	0	3.336144960550463	
i 1	569.9859523809524	0.2525	74	200	5	4	13	16	0	2	16	0	0	4.0	
i 1	569.9883605442177	0.7575000000000001	73	1084	2	20	6	16	0	2	16	0	0	3.336144960550463	
i 1	569.9955850340136	0.2525	74	698	5	3	16	16	0	1	16	0	0	4.0	
i 1	569.9963877551021	0.2525	72	698	5	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	569.9971904761904	0.2525	73	1084	2	20	12	17	0	2	17	0	0	3.336144960550463	
i 1	570.0132448979592	2.02	74	698	4	5	3	2	0	-1	2	0	0	9.948905943535717	
i 1	570.0180612244898	1.5150000000000001	73	698	1	24	5	17	0	252	17	307	0	7.336144960550463	
i 1	570.2431768707482	0.2525	71	200	7	5	3	8	0	-2	8	0	0	9.948905943535717	
i 1	570.2455850340136	0.2525	72	200	5	24	9	8	0	-2	8	0	0	8.79455711903287	
i 1	570.266455782313	0.2525	75	1084	5	1	9	2	0	-2	2	0	0	7.794557119032869	
i 1	570.4843469387755	2.02	72	698	5	1	16	2	0	-2	2	0	0	7.794557119032869	
i 1	570.4843469387755	0.2525	74	698	5	3	16	16	0	1	16	0	0	4.0	
i 1	570.509231292517	1.01	76	698	1	20	14	16	0	2	16	0	0	3.336144960550463	
i 1	570.5100340136055	0.505	71	1084	4	5	12	2	0	-2	2	0	0	9.948905943535717	
i 1	570.516455782313	0.2525	74	1084	5	9	9	17	0	2	17	0	0	3.0	
i 1	570.7303333333333	0.7575000000000001	73	698	1	20	11	17	0	2	17	0	0	3.336144960550463	
i 1	570.7327414965987	0.505	74	698	4	2	3	17	0	2	17	0	0	4.0	
i 1	570.7359523809524	2.02	63	698	3	27	10	1	0	2	1	0	0	12.738040549334222	
i 1	570.7544149659864	2.02	61	698	6	17	1	1	0	1	1	0	0	3.506464741742853	
i 1	570.7600340136055	2.02	61	698	5	13	15	1	0	1	1	0	0	0.16369957879808614	
i 1	570.9875578231292	0.7575000000000001	72	1084	5	1	2	8	0	-2	8	0	0	7.794557119032869	
i 1	570.9891632653062	0.2525	71	200	7	5	4	2	0	-1	2	0	0	9.948905943535717	
i 1	571.0076258503401	0.2525	75	1084	5	1	11	2	0	-2	2	0	0	7.794557119032869	
i 1	571.009231292517	1.5150000000000001	74	200	4	4	13	16	0	2	16	0	0	4.0	
i 1	571.0124421768708	0.2525	71	200	7	5	15	8	0	-2	8	0	0	9.948905943535717	
i 1	571.2471904761904	0.2525	71	1084	6	5	8	2	0	-1	2	0	0	9.948905943535717	
i 1	571.2672585034013	0.2525	71	698	3	5	3	8	0	-1	8	0	0	9.948905943535717	
i 1	571.490768707483	0.2525	76	200	3	20	11	16	0	2	16	0	0	3.336144960550463	
i 1	571.4995986394558	0.2525	74	1084	5	9	7	17	0	2	17	0	0	3.0	
i 1	571.5140476190476	0.2525	74	698	4	5	6	2	0	-2	2	0	0	9.948905943535717	
i 1	571.5140476190476	0.505	76	698	1	24	2	17	0	2	17	0	0	7.336144960550463	
i 1	571.514850340136	0.2525	73	1084	2	24	13	17	0	1	17	0	0	7.336144960550463	
i 1	571.7303333333333	1.01	76	1084	2	20	10	17	0	2	17	0	0	3.336144960550463	
i 1	571.7447823129252	0.2525	75	1084	5	1	15	2	0	-2	2	0	0	7.794557119032869	
i 1	571.7520068027211	0.505	74	698	5	3	14	16	0	1	16	0	0	4.0	
i 1	571.7544149659864	0.2525	74	698	4	2	12	17	0	2	17	0	0	4.0	
i 1	571.7552176870748	0.2525	72	698	2	1	13	2	0	1	2	0	0	7.794557119032869	
i 1	571.7608367346938	0.2525	73	698	1	20	8	16	0	1	16	0	0	3.336144960550463	
i 1	571.7656530612245	1.01	71	200	7	5	11	8	0	-2	8	0	0	9.948905943535717	
i 1	571.7672585034013	1.01	73	1084	2	20	8	16	0	1	16	0	0	3.336144960550463	
i 1	571.985149659864	0.505	73	698	1	20	2	17	0	2	17	0	0	3.336144960550463	
i 1	572.0012040816326	0.7575000000000001	72	200	5	24	6	8	0	-2	8	0	0	8.79455711903287	
i 1	572.0124421768708	0.2525	74	698	4	5	3	2	0	-2	2	0	0	9.948905943535717	
i 1	572.2367551020408	0.2525	75	200	5	1	14	2	0	1	2	0	0	7.794557119032869	
i 1	572.2375578231292	0.2525	74	1084	5	9	3	17	0	2	17	0	0	3.0	
i 1	572.2447823129252	0.2525	71	698	3	5	10	8	0	-1	8	0	0	9.948905943535717	
i 1	572.2576258503401	0.505	74	200	4	3	1	17	0	1	17	0	0	4.0	
i 1	572.2632448979592	0.505	71	698	3	5	8	2	0	-1	2	0	0	9.948905943535717	
i 1	572.5004013605442	0.2525	72	698	2	1	6	2	0	1	2	0	0	7.794557119032869	
i 1	572.5156530612245	0.2525	74	698	5	3	9	16	0	1	16	0	0	4.0	
i 1	572.7311360544218	1.01	63	588	5	17	9	16	0	2	16	0	0	3.506464741742853	
i 1	572.7319387755102	4.04	61	202	4	27	14	16	0	1	16	0	0	12.738040549334222	
i 1	572.7327414965987	2.02	74	588	4	3	8	16	0	1	16	0	0	4.0	
i 1	572.733544217687	0.2525	74	904	4	2	2	17	0	2	17	0	0	4.0	
i 1	572.733544217687	0.7575000000000001	76	202	3	20	10	17	0	1	17	0	0	3.336144960550463	
i 1	572.7343469387755	1.01	75	904	5	1	9	2	0	1	2	0	0	7.794557119032869	
i 1	572.735149659864	0.505	74	904	4	5	4	2	0	-1	2	0	0	9.948905943535717	
i 1	572.735149659864	0.7575000000000001	73	202	3	20	8	16	0	2	16	0	0	3.336144960550463	
i 1	572.7367551020408	4.04	63	904	6	17	6	16	0	1	16	0	0	3.506464741742853	
i 1	572.7415714285714	4.04	63	202	5	26	3	1	0	2	1	0	0	0.39147284124284637	
i 1	572.7415714285714	4.04	61	202	4	27	9	1	0	1	1	0	0	12.738040549334222	
i 1	572.7439795918367	4.04	61	202	5	18	5	16	0	1	16	0	0	3.506464741742853	
i 1	572.7447823129252	4.04	63	904	5	14	5	16	0	1	16	0	0	2.551638712202796	
i 1	572.7447823129252	4.04	61	202	4	19	4	16	0	1	16	0	0	3.506464741742853	
i 1	572.7463877551021	0.2525	74	202	5	4	2	16	0	1	16	0	0	4.0	
i 1	572.7479931972789	0.2525	74	588	6	5	15	8	0	-2	8	0	0	9.948905943535717	
i 1	572.7520068027211	4.04	61	904	6	17	13	16	0	2	16	0	0	3.506464741742853	
i 1	572.7520068027211	4.04	61	202	4	19	7	1	0	1	1	0	0	3.506464741742853	
i 1	572.7528095238096	3.0300000000000002	74	588	6	5	4	8	0	-2	8	0	0	9.948905943535717	
i 1	572.7584285714286	4.04	61	904	5	13	14	16	0	1	16	0	0	0.16369957879808614	
i 1	572.7608367346938	1.01	61	202	5	26	14	16	0	2	16	0	0	0.39147284124284637	
i 1	572.7640476190476	4.04	63	588	5	17	6	1	0	1	1	0	0	3.506464741742853	
i 1	572.7688639455782	4.04	63	202	5	18	1	1	0	1	1	0	0	3.506464741742853	
i 1	572.983544217687	0.2525	76	202	2	24	1	17	0	1	17	0	0	7.336144960550463	
i 1	573.2455850340136	0.505	77	202	6	9	16	17	0	1	17	0	0	3.0	
i 1	573.2463877551021	0.2525	75	904	5	1	8	2	0	1	2	0	0	7.794557119032869	
i 1	573.2479931972789	0.505	75	202	6	1	13	2	0	-2	2	0	0	7.794557119032869	
i 1	573.2479931972789	0.2525	74	588	6	5	2	8	0	-2	8	0	0	9.948905943535717	
i 1	573.2632448979592	5.3025	76	202	1	24	9	17	0	252	17	307	0	7.336144960550463	
i 1	573.4875578231292	0.2525	71	202	7	5	14	2	0	-1	2	0	0	9.948905943535717	
i 1	573.514850340136	0.2525	74	202	6	3	9	16	0	2	16	0	0	4.0	
i 1	573.514850340136	0.2525	73	202	3	20	2	17	0	2	17	0	0	3.336144960550463	
i 1	573.5156530612245	0.2525	76	202	3	24	5	16	0	1	16	0	0	7.336144960550463	
i 1	573.7311360544218	0.7575000000000001	73	202	3	20	3	16	0	2	16	0	0	3.336144960550463	
i 1	573.7383605442177	0.2525	74	904	4	2	1	17	0	2	17	0	0	4.0	
i 1	573.7471904761904	3.0300000000000002	63	588	6	17	15	16	0	2	16	0	0	3.506464741742853	
i 1	573.7471904761904	0.505	71	202	4	5	5	8	0	-1	8	0	0	9.948905943535717	
i 1	573.7512040816326	0.2525	77	904	4	2	13	16	0	2	16	0	0	4.0	
i 1	573.7544149659864	0.7575000000000001	75	904	6	1	2	2	0	1	2	0	0	7.794557119032869	
i 1	573.7584285714286	0.2525	71	202	7	5	15	2	0	-1	2	0	0	9.948905943535717	
i 1	573.759231292517	0.505	76	202	3	20	3	17	0	1	17	0	0	3.336144960550463	
i 1	573.7632448979592	3.0300000000000002	63	588	5	15	6	1	0	2	1	0	0	0.9596792899329893	
i 1	573.7640476190476	0.2525	72	588	4	24	7	2	0	-2	2	0	0	8.79455711903287	
i 1	573.9803333333333	0.2525	74	202	5	4	2	16	0	1	16	0	0	4.0	
i 1	573.9803333333333	0.7575000000000001	73	202	2	20	4	16	0	2	16	0	0	3.336144960550463	
i 1	574.0140476190476	1.2625	72	588	5	1	11	2	0	1	2	0	0	7.794557119032869	
i 1	574.0140476190476	0.2525	76	202	2	20	12	17	0	2	17	0	0	3.336144960550463	
i 1	574.2383605442177	0.2525	76	588	3	20	8	16	0	1	16	0	0	3.336144960550463	
i 1	574.2463877551021	0.505	71	904	4	5	15	2	0	-1	2	0	0	9.948905943535717	
i 1	574.2608367346938	1.5150000000000001	74	588	4	4	16	17	0	2	17	0	0	4.0	
i 1	574.483544217687	0.505	75	202	6	1	12	2	0	-2	2	0	0	7.794557119032869	
i 1	574.4955850340136	0.505	74	904	4	2	14	17	0	2	17	0	0	4.0	
i 1	574.5068231292518	0.2525	74	588	4	5	9	8	0	-2	8	0	0	9.948905943535717	
i 1	574.5124421768708	0.2525	73	202	2	24	8	16	0	2	16	0	0	7.336144960550463	
i 1	574.7383605442177	1.7675	73	202	3	20	5	17	0	1	17	0	0	3.336144960550463	
i 1	574.7471904761904	1.7675	73	202	3	20	15	16	0	2	16	0	0	3.336144960550463	
i 1	574.7568231292518	0.2525	71	202	7	5	16	2	0	-1	2	0	0	9.948905943535717	
i 1	574.7608367346938	0.2525	71	202	7	5	8	2	0	-1	2	0	0	9.948905943535717	
i 1	574.9859523809524	0.2525	74	202	5	4	10	16	0	1	16	0	0	4.0	
i 1	574.9963877551021	0.2525	74	904	4	5	8	2	0	-1	2	0	0	9.948905943535717	
i 1	575.014850340136	0.2525	72	202	3	24	14	2	0	1	2	0	0	8.79455711903287	
i 1	575.2471904761904	0.7575000000000001	75	904	5	1	7	2	0	1	2	0	0	7.794557119032869	
i 1	575.2600340136055	0.2525	74	904	4	2	6	17	0	2	17	0	0	4.0	
i 1	575.264850340136	1.01	75	904	6	1	14	2	0	1	2	0	0	7.794557119032869	
i 1	575.5028095238096	0.2525	74	202	4	5	12	2	0	-1	2	0	0	9.948905943535717	
i 1	575.7447823129252	0.2525	72	202	3	24	10	2	0	1	2	0	0	8.79455711903287	
i 1	575.7479931972789	0.2525	71	202	7	5	2	2	0	-1	2	0	0	9.948905943535717	
i 1	575.7576258503401	1.01	71	904	4	5	5	2	0	-1	2	0	0	9.948905943535717	
i 1	575.7584285714286	1.2625	74	904	4	2	9	17	0	2	17	0	0	4.0	
i 1	575.9827414965987	0.2525	72	588	4	24	2	2	0	-2	2	0	0	8.79455711903287	
i 1	576.2367551020408	0.505	74	202	4	5	10	2	0	-1	2	0	0	9.948905943535717	
i 1	576.2375578231292	0.505	75	904	5	1	1	2	0	1	2	0	0	7.794557119032869	
i 1	576.2688639455782	0.505	72	588	5	1	16	2	0	1	2	0	0	7.794557119032869	
i 1	576.4859523809524	0.505	73	202	3	20	16	17	0	1	17	0	0	3.336144960550463	
i 1	576.5172585034013	0.2525	72	202	6	1	13	2	0	-2	2	0	0	7.794557119032869	
i 1	576.5196666666667	0.505	76	202	3	24	3	16	0	1	16	0	0	7.336144960550463	
i 1	576.7367551020408	0.2525	75	904	6	1	9	2	0	1	2	0	0	7.72388007207531	
i 1	576.7383605442177	5.8075	61	202	4	19	12	1	0	1	1	0	0	3.5064647417428527	
i 1	576.7399659863945	1.5150000000000001	77	904	4	2	5	16	0	2	16	0	0	4.0	
i 1	576.7455850340136	5.8075	61	588	5	15	12	1	0	2	1	0	0	0.7950005952107598	
i 1	576.7455850340136	5.8075	61	202	4	27	2	16	0	1	16	0	0	12.802460130804567	
i 1	576.7463877551021	2.02	72	588	5	1	3	2	0	1	2	0	0	7.72388007207531	
i 1	576.7479931972789	5.8075	63	904	5	14	11	16	0	1	16	0	0	2.386960017480566	
i 1	576.7479931972789	5.8075	63	904	6	17	13	16	0	1	16	0	0	3.5064647417428527	
i 1	576.7504013605442	3.0300000000000002	61	202	5	18	1	16	0	1	16	0	0	3.5064647417428527	
i 1	576.7512040816326	0.7575000000000001	73	202	2	20	13	16	0	2	16	0	0	3.336144960550463	
i 1	576.7528095238096	4.04	71	904	4	5	1	2	0	-1	2	0	0	11.606964696238188	
i 1	576.7536122448979	5.8075	61	904	6	17	3	16	0	2	16	0	0	3.5064647417428527	
i 1	576.7544149659864	3.0300000000000002	61	202	4	27	12	1	0	1	1	0	0	12.802460130804567	
i 1	576.7544149659864	0.2525	73	202	2	20	16	16	0	2	16	0	0	3.336144960550463	
i 1	576.7560204081633	0.2525	72	202	5	24	7	2	0	1	2	0	0	8.72388007207531	
i 1	576.7576258503401	0.2525	73	202	3	20	7	16	0	2	16	0	0	3.336144960550463	
i 1	576.7600340136055	5.8075	63	588	6	17	4	1	0	1	1	0	0	3.5064647417428527	
i 1	576.7632448979592	5.8075	63	202	5	18	3	1	0	1	1	0	0	3.5064647417428527	
i 1	576.7640476190476	5.8075	61	202	4	19	2	16	0	1	16	0	0	3.5064647417428527	
i 1	576.7672585034013	0.2525	73	202	3	20	10	17	0	1	17	0	0	3.336144960550463	
i 1	576.7680612244898	5.8075	63	588	6	17	10	16	0	2	16	0	0	3.5064647417428527	
i 1	576.7696666666667	5.8075	63	588	5	15	10	1	0	2	1	0	0	0.7950005952107598	
i 1	576.9803333333333	0.505	74	202	6	3	16	16	0	2	16	0	0	4.0	
i 1	576.983544217687	0.2525	74	588	4	4	9	17	0	2	17	0	0	4.0	
i 1	576.9859523809524	0.2525	73	588	3	20	7	17	0	2	17	0	0	3.336144960550463	
i 1	577.2552176870748	0.7575000000000001	71	202	7	5	14	8	0	-1	8	0	0	11.606964696238188	
i 1	577.2616394557823	0.2525	76	202	2	24	2	16	0	2	16	0	0	7.336144960550463	
i 1	577.4867551020408	0.2525	74	588	4	3	2	16	0	1	16	0	0	4.0	
i 1	577.4971904761904	1.2625	73	202	3	20	11	16	0	2	16	0	0	3.336144960550463	
i 1	577.5140476190476	0.7575000000000001	73	202	3	20	1	17	0	1	17	0	0	3.336144960550463	
i 1	577.514850340136	0.2525	72	202	6	1	11	2	0	-2	2	0	0	7.72388007207531	
i 1	577.5156530612245	0.2525	74	588	4	5	1	8	0	-2	8	0	0	11.606964696238188	
i 1	577.7600340136055	0.2525	77	202	4	9	13	17	0	1	17	0	0	3.0	
i 1	577.7696666666667	0.505	75	904	6	1	16	2	0	1	2	0	0	7.72388007207531	
i 1	577.9819387755102	0.2525	71	202	7	5	15	2	0	-1	2	0	0	11.606964696238188	
i 1	577.9899659863945	3.535	74	588	4	3	14	16	0	1	16	0	0	4.0	
i 1	577.9939795918367	0.2525	76	202	2	24	7	16	0	2	16	0	0	7.336144960550463	
i 1	578.009231292517	1.2625	75	202	5	1	10	2	0	-2	2	0	0	7.72388007207531	
i 1	578.240768707483	0.2525	77	202	4	9	10	17	0	1	17	0	0	3.0	
i 1	578.2479931972789	0.2525	74	588	4	5	8	8	0	-2	8	0	0	11.606964696238188	
i 1	578.2624421768708	0.2525	73	904	3	20	8	16	0	1	16	0	0	3.336144960550463	
i 1	578.4803333333333	1.7675	72	588	4	24	10	2	0	-2	2	0	0	8.72388007207531	
i 1	578.4931768707482	0.7575000000000001	76	202	2	24	5	17	0	1	17	0	0	7.336144960550463	
i 1	578.4963877551021	0.2525	74	904	4	2	11	17	0	2	17	0	0	4.0	
i 1	578.516455782313	0.2525	76	202	3	20	14	17	0	1	17	0	0	3.336144960550463	
i 1	578.5188639455782	0.7575000000000001	73	202	2	20	11	16	0	1	16	0	0	3.336144960550463	
i 1	578.5196666666667	0.2525	76	202	3	24	14	16	0	1	16	0	0	7.336144960550463	
i 1	578.7415714285714	0.2525	74	588	4	5	4	8	0	-2	8	0	0	11.606964696238188	
i 1	578.7624421768708	0.505	74	904	4	5	6	2	0	-1	2	0	0	11.606964696238188	
i 1	579.2455850340136	0.2525	74	588	4	5	1	8	0	-2	8	0	0	11.606964696238188	
i 1	579.2463877551021	0.2525	76	202	3	24	11	16	0	1	16	0	0	7.336144960550463	
i 1	579.2656530612245	0.2525	73	588	3	24	9	16	0	1	16	0	0	7.336144960550463	
i 1	579.2688639455782	0.2525	72	202	6	1	4	2	0	-2	2	0	0	7.72388007207531	
i 1	579.4899659863945	0.2525	73	202	3	20	12	16	0	2	16	0	0	3.336144960550463	
i 1	579.5084285714286	0.2525	71	202	7	5	7	2	0	-1	2	0	0	11.606964696238188	
i 1	579.5124421768708	0.505	75	202	5	1	6	2	0	-2	2	0	0	7.72388007207531	
i 1	579.5180612244898	0.2525	76	202	3	20	14	16	0	2	16	0	0	3.336144960550463	
i 1	579.7311360544218	2.7775	63	202	5	16	5	1	0	1	1	0	0	1.5909803063456631	
i 1	579.7512040816326	2.7775	61	202	5	18	11	16	0	1	16	0	0	3.5064647417428527	
i 1	579.9963877551021	0.2525	72	202	5	1	6	2	0	1	2	0	0	7.72388007207531	
i 1	580.0020068027211	0.2525	76	202	2	24	9	17	0	1	17	0	0	10.439844327211144	
i 1	580.0140476190476	0.2525	73	202	2	20	4	17	0	1	17	0	0	6.439844327211144	
i 1	580.235149659864	1.01	72	588	6	1	8	2	0	1	2	0	0	7.72388007207531	
i 1	580.2471904761904	0.2525	77	904	6	2	5	16	0	2	16	0	0	4.0	
i 1	580.2471904761904	1.7675	76	202	1	24	12	17	0	252	17	307	0	10.439844327211144	
i 1	580.2512040816326	0.7575000000000001	73	202	3	20	12	16	0	2	16	0	0	6.439844327211144	
i 1	580.2632448979592	0.7575000000000001	76	202	3	20	8	17	0	1	17	0	0	6.439844327211144	
i 1	580.266455782313	0.2525	75	904	6	1	16	2	0	1	2	0	0	7.72388007207531	
i 1	580.5180612244898	0.505	74	588	4	4	8	17	0	2	17	0	0	4.0	
i 1	580.7504013605442	0.2525	71	202	7	5	15	2	0	-1	2	0	0	11.606964696238188	
i 1	580.7584285714286	1.7675	74	588	4	5	6	8	0	-2	8	0	0	11.606964696238188	
i 1	580.9867551020408	0.505	74	202	7	5	16	2	0	-1	2	0	0	11.606964696238188	
i 1	580.9867551020408	1.01	73	202	2	24	11	16	0	2	16	0	0	10.439844327211144	
i 1	580.990768707483	0.2525	77	904	6	2	9	16	0	2	16	0	0	4.0	
i 1	580.9947823129252	1.01	73	202	2	20	9	16	0	2	16	0	0	6.439844327211144	
i 1	581.0028095238096	0.2525	72	588	4	24	15	2	0	-2	2	0	0	8.72388007207531	
i 1	581.2311360544218	0.2525	74	202	4	9	9	17	0	1	17	0	0	3.0	
i 1	581.2359523809524	1.01	75	904	6	1	12	2	0	1	2	0	0	7.72388007207531	
i 1	581.4995986394558	1.01	77	904	6	2	4	16	0	2	16	0	0	4.0	
i 1	581.5116394557823	0.2525	75	202	5	1	16	2	0	-2	2	0	0	7.72388007207531	
i 1	581.5196666666667	0.2525	71	904	4	5	9	2	0	-1	2	0	0	11.606964696238188	
i 1	581.7303333333333	0.2525	74	202	3	3	8	16	0	2	16	0	0	4.0	
i 1	581.7311360544218	0.2525	72	202	5	1	4	2	0	1	2	0	0	7.72388007207531	
i 1	581.7552176870748	0.505	71	202	7	5	3	2	0	-1	2	0	0	11.606964696238188	
i 1	581.9875578231292	0.505	76	904	3	20	5	17	0	2	17	0	0	6.439844327211144	
i 1	582.0068231292518	0.505	72	202	5	1	5	2	0	-2	2	0	0	7.72388007207531	
i 1	582.0076258503401	0.505	76	202	2	24	5	17	0	1	17	0	0	10.439844327211144	
i 1	582.0132448979592	0.505	74	202	4	9	8	17	0	1	17	0	0	3.0	
i 1	582.235149659864	0.2525	74	588	4	5	13	8	0	-2	8	0	0	11.606964696238188	
i 1	582.2640476190476	0.2525	72	588	6	1	14	2	0	1	2	0	0	7.72388007207531	
i 1	582.4803333333333	12.625	61	209	5	19	16	9	0	1	9	0	0	2.5046176726734664	
i 1	582.4811360544218	2.02	72	1093	4	5	6	2	0	1	2	0	0	3.043848439455805	
i 1	582.4819387755102	12.625	61	1093	5	17	5	9	0	1	9	0	0	2.5046176726734664	
i 1	582.4819387755102	0.2525	71	1093	2	20	14	0	0	-1	0	0	0	2.287845002869841	
i 1	582.4827414965987	2.2725	74	701	6	1	11	16	5005	2	16	0	0	5.419419833319788	
i 1	582.4915714285714	6.565	71	209	2	24	4	1	0	0	1	0	0	6.287845002869841	
i 1	582.4923741496599	0.505	77	209	5	1	8	16	0	2	16	0	0	5.419419833319788	
i 1	582.4923741496599	0.2525	71	701	2	24	12	0	5005	-1	0	0	0	6.287845002869841	
i 1	582.4923741496599	1.01	68	209	1	20	9	1	0	-1	1	0	0	2.287845002869841	
i 1	582.4947823129252	5.05	61	209	5	18	14	6	0	1	6	0	0	2.5046176726734664	
i 1	582.4955850340136	0.2525	71	1093	5	2	7	8	0	-2	8	0	0	4.004062984616236	
i 1	582.5012040816326	14.14	66	701	5	17	8	6	5005	1	6	0	0	2.5046176726734664	
i 1	582.5012040816326	0.505	71	209	1	24	11	0	0	-1	0	0	0	6.287845002869841	
i 1	582.5044149659864	11.11	61	209	5	19	15	9	0	1	9	0	0	2.5046176726734664	
i 1	582.5060204081633	0.7575000000000001	71	209	2	20	11	1	0	-1	1	0	0	2.287845002869841	
i 1	582.5100340136055	2.02	74	701	4	4	7	8	5005	-1	8	0	0	4.004062984616236	
i 1	582.5108367346938	2.02	66	701	6	17	4	6	5005	0	6	0	0	2.5046176726734664	
i 1	582.5124421768708	0.2525	74	209	4	1	13	17	0	2	17	0	0	5.419419833319788	
i 1	582.5124421768708	2.02	61	209	5	12	7	9	0	1	9	0	0	5.217728500628025	
i 1	582.5132448979592	8.08	61	209	5	18	14	9	0	1	9	0	0	2.5046176726734664	
i 1	582.5140476190476	1.01	77	1093	6	1	8	17	0	1	17	0	0	5.419419833319788	
i 1	582.5156530612245	12.625	66	1093	5	17	10	6	0	1	6	0	0	2.5046176726734664	
i 1	582.5180612244898	0.505	71	209	4	9	15	2	0	-1	2	0	0	3.004062984616236	
i 1	582.5180612244898	0.505	71	209	3	3	7	8	0	-2	8	0	0	4.004062984616236	
i 1	582.5180612244898	0.2525	71	1093	2	20	16	0	0	0	0	0	0	2.287845002869841	
i 1	582.733544217687	1.01	71	1093	5	2	8	2	0	-1	2	0	0	4.004062984616236	
i 1	582.7383605442177	0.2525	72	209	5	5	2	2	0	1	2	0	0	3.043848439455805	
i 1	582.7383605442177	0.2525	71	209	2	20	7	1	0	0	1	0	0	2.287845002869841	
i 1	582.7423741496599	0.2525	75	209	3	5	5	8	0	1	8	0	0	3.043848439455805	
i 1	582.7552176870748	0.505	68	209	2	20	14	0	0	-1	0	0	0	2.287845002869841	
i 1	582.7600340136055	1.2625	68	209	1	24	1	0	5005	0	0	0	0	6.287845002869841	
i 1	582.9883605442177	0.505	71	209	4	9	14	8	0	-1	8	0	0	3.004062984616236	
i 1	582.9955850340136	2.525	72	701	4	5	1	2	5005	-2	2	0	0	3.043848439455805	
i 1	583.0052176870748	0.2525	74	209	5	1	16	16	0	1	16	0	0	5.419419833319788	
i 1	583.0068231292518	0.505	72	209	5	5	10	2	0	1	2	0	0	3.043848439455805	
i 1	583.2343469387755	0.2525	71	1093	5	2	6	8	0	-2	8	0	0	4.004062984616236	
i 1	583.2447823129252	0.505	72	209	5	5	10	2	0	1	2	0	0	3.043848439455805	
i 1	583.2520068027211	1.2625	74	701	4	24	12	17	5005	1	17	0	0	6.419419833319788	
i 1	583.2672585034013	0.7575000000000001	68	209	1	20	12	0	5005	-1	0	0	0	2.287845002869841	
i 1	583.4843469387755	0.2525	74	209	4	1	11	17	0	2	17	0	0	5.419419833319788	
i 1	583.4843469387755	0.505	71	209	3	3	15	8	0	-2	8	0	0	4.004062984616236	
i 1	583.4891632653062	0.2525	74	209	3	4	1	8	0	-2	8	0	0	4.004062984616236	
i 1	583.490768707483	4.545	71	209	1	24	16	0	0	-1	0	0	0	6.287845002869841	
i 1	583.509231292517	0.2525	74	209	4	24	11	17	0	1	17	0	0	6.419419833319788	
i 1	583.509231292517	0.2525	72	701	4	5	8	2	5005	1	2	0	0	3.043848439455805	
i 1	583.7311360544218	0.2525	74	209	5	1	15	16	0	1	16	0	0	5.419419833319788	
i 1	583.7447823129252	0.7575000000000001	71	209	4	9	2	2	0	-1	2	0	0	3.004062984616236	
i 1	583.7536122448979	0.2525	77	1093	6	1	7	17	0	1	17	0	0	5.419419833319788	
i 1	583.7552176870748	0.505	72	209	5	5	11	2	0	1	2	0	0	3.043848439455805	
i 1	583.983544217687	0.505	72	209	3	5	1	2	0	-2	2	0	0	3.043848439455805	
i 1	583.985149659864	0.2525	71	701	2	24	10	0	5005	0	0	0	0	6.287845002869841	
i 1	584.0004013605442	0.2525	68	701	2	20	8	1	5005	-1	1	0	0	2.287845002869841	
i 1	584.0100340136055	0.2525	71	1093	5	2	7	2	0	-1	2	0	0	4.004062984616236	
i 1	584.2327414965987	0.7575000000000001	71	1093	5	2	5	8	0	-2	8	0	0	4.004062984616236	
i 1	584.2343469387755	0.2525	75	1093	4	5	5	8	0	1	8	0	0	3.043848439455805	
i 1	584.2367551020408	0.7575000000000001	68	209	1	24	3	1	5005	-1	1	0	0	6.287845002869841	
i 1	584.2487959183674	0.2525	74	209	3	4	16	8	0	-2	8	0	0	4.004062984616236	
i 1	584.2504013605442	0.7575000000000001	71	209	1	20	12	1	5005	0	1	0	0	2.287845002869841	
i 1	584.2624421768708	2.525	77	1093	6	1	11	17	0	1	17	0	0	5.419419833319788	
i 1	584.4811360544218	2.7775	72	701	4	5	12	2	5005	1	2	0	0	3.043848439455805	
i 1	584.4891632653062	1.5150000000000001	74	701	4	4	10	8	5005	-1	8	0	0	4.004062984616236	
i 1	584.5052176870748	0.505	74	701	4	24	3	17	5005	1	17	0	0	6.419419833319788	
i 1	584.5156530612245	12.120000000000001	66	701	5	17	12	6	5005	0	6	0	0	2.5046176726734664	
i 1	584.5156530612245	0.7575000000000001	72	209	4	5	5	2	0	1	2	0	0	3.043848439455805	
i 1	584.7383605442177	0.505	74	209	4	1	7	17	0	2	17	0	0	5.419419833319788	
i 1	584.7431768707482	0.2525	72	1093	4	5	5	2	0	1	2	0	0	3.043848439455805	
i 1	584.7439795918367	0.2525	74	209	4	24	13	17	0	1	17	0	0	6.419419833319788	
i 1	584.7479931972789	0.2525	71	209	3	3	15	8	0	-2	8	0	0	4.004062984616236	
i 1	584.764850340136	0.505	71	209	4	9	6	8	0	-1	8	0	0	3.004062984616236	
i 1	584.9843469387755	1.5150000000000001	72	209	5	5	15	2	0	1	2	0	0	3.043848439455805	
i 1	584.9875578231292	0.2525	71	701	2	20	9	0	5005	-1	0	0	0	2.287845002869841	
i 1	585.0020068027211	0.505	74	1093	6	1	3	16	0	1	16	0	0	5.419419833319788	
i 1	585.0100340136055	0.2525	68	701	2	24	11	0	5005	-1	0	0	0	6.287845002869841	
i 1	585.0196666666667	1.2625	74	701	5	3	14	2	5005	-1	2	0	0	4.004062984616236	
i 1	585.2399659863945	0.2525	68	209	1	20	4	1	5005	-1	1	0	0	2.287845002869841	
i 1	585.2487959183674	0.505	75	1093	4	5	6	8	0	1	8	0	0	3.043848439455805	
i 1	585.2544149659864	0.2525	71	209	1	24	12	0	5005	-1	0	0	0	6.287845002869841	
i 1	585.2584285714286	0.505	71	1093	5	2	4	8	0	-2	8	0	0	4.004062984616236	
i 1	585.266455782313	0.505	74	701	6	1	14	16	5005	2	16	0	0	5.419419833319788	
i 1	585.2672585034013	3.2825	71	1093	5	2	10	2	0	-1	2	0	0	4.004062984616236	
i 1	585.4819387755102	0.2525	72	209	4	5	3	2	0	1	2	0	0	3.043848439455805	
i 1	585.490768707483	0.505	74	209	4	24	14	17	0	1	17	0	0	6.419419833319788	
i 1	585.5004013605442	0.2525	77	209	5	1	10	16	0	2	16	0	0	5.419419833319788	
i 1	585.7399659863945	0.505	74	1093	6	1	7	16	0	1	16	0	0	5.419419833319788	
i 1	585.7423741496599	0.2525	72	701	4	5	6	2	5005	-2	2	0	0	3.043848439455805	
i 1	585.7495986394558	2.7775	74	701	4	24	4	17	5005	1	17	0	0	6.419419833319788	
i 1	585.7656530612245	0.505	71	209	6	9	15	2	0	-1	2	0	0	3.004062984616236	
i 1	585.9819387755102	0.2525	71	209	4	9	10	8	0	-1	8	0	0	3.004062984616236	
i 1	585.9947823129252	0.2525	71	701	2	24	4	1	5005	-1	1	0	0	6.287845002869841	
i 1	585.9995986394558	0.2525	68	701	2	20	5	1	5005	0	1	0	0	2.287845002869841	
i 1	586.0004013605442	0.2525	72	209	4	5	7	2	0	1	2	0	0	3.043848439455805	
i 1	586.0036122448979	0.7575000000000001	77	209	5	1	3	16	0	2	16	0	0	5.419419833319788	
i 1	586.0116394557823	1.5150000000000001	72	1093	4	5	14	2	0	1	2	0	0	3.043848439455805	
i 1	586.2431768707482	1.01	71	209	1	24	5	1	5005	0	1	0	0	6.287845002869841	
i 1	586.2455850340136	1.01	68	209	1	20	1	1	5005	-1	1	0	0	2.287845002869841	
i 1	586.2487959183674	0.2525	74	209	6	1	13	16	0	1	16	0	0	5.419419833319788	
i 1	586.259231292517	0.2525	71	209	3	3	12	8	0	-2	8	0	0	4.004062984616236	
i 1	586.2680612244898	1.01	74	209	3	4	8	8	0	-2	8	0	0	4.004062984616236	
i 1	586.2680612244898	3.2825	72	701	4	5	4	2	5005	-2	2	0	0	3.043848439455805	
i 1	586.483544217687	2.7775	74	701	5	3	1	2	5005	-1	2	0	0	4.004062984616236	
i 1	586.483544217687	0.2525	72	209	3	5	7	2	0	-2	2	0	0	3.043848439455805	
i 1	586.509231292517	0.2525	74	209	4	24	11	17	0	1	17	0	0	6.419419833319788	
i 1	586.7367551020408	0.2525	72	209	4	5	6	2	0	1	2	0	0	3.043848439455805	
i 1	586.7463877551021	0.505	74	209	4	1	12	17	0	2	17	0	0	5.419419833319788	
i 1	586.9859523809524	0.505	74	1093	6	1	6	16	0	1	16	0	0	5.419419833319788	
i 1	586.9891632653062	0.505	72	209	3	5	4	2	0	-2	2	0	0	3.043848439455805	
i 1	587.235149659864	0.2525	68	701	2	24	14	1	5005	0	1	0	0	6.287845002869841	
i 1	587.240768707483	0.2525	68	701	2	20	5	0	5005	-1	0	0	0	2.287845002869841	
i 1	587.2479931972789	0.2525	72	209	5	5	16	2	0	1	2	0	0	3.043848439455805	
i 1	587.2536122448979	1.5150000000000001	74	701	6	1	5	16	5005	2	16	0	0	5.419419833319788	
i 1	587.4819387755102	0.2525	75	1093	4	5	13	8	0	1	8	0	0	3.043848439455805	
i 1	587.4827414965987	1.01	71	209	1	24	9	1	5005	0	1	0	0	6.287845002869841	
i 1	587.4867551020408	0.505	71	209	1	20	8	1	5005	0	1	0	0	2.287845002869841	
i 1	587.4875578231292	9.09	61	209	5	18	10	6	0	1	6	0	0	2.5046176726734664	
i 1	587.4883605442177	0.2525	71	1093	5	2	1	8	0	-2	8	0	0	4.004062984616236	
i 1	587.4947823129252	3.0300000000000002	77	1093	6	1	7	17	0	1	17	0	0	5.419419833319788	
i 1	587.5028095238096	0.2525	75	209	4	5	14	8	0	1	8	0	0	3.043848439455805	
i 1	587.509231292517	0.2525	72	209	4	5	1	2	0	-2	2	0	0	3.043848439455805	
i 1	587.5172585034013	0.505	74	701	4	4	11	8	5005	-1	8	0	0	4.004062984616236	
i 1	587.7391632653062	0.505	72	701	4	5	12	2	5005	1	2	0	0	3.043848439455805	
i 1	587.7455850340136	0.505	71	209	6	9	1	8	0	-1	8	0	0	3.004062984616236	
i 1	587.9811360544218	0.7575000000000001	72	209	4	5	13	2	0	1	2	0	0	3.043848439455805	
i 1	587.9955850340136	0.2525	71	1093	5	2	5	8	0	-2	8	0	0	4.004062984616236	
i 1	588.0060204081633	0.505	68	209	2	20	15	0	0	0	0	0	0	2.287845002869841	
i 1	588.0060204081633	2.02	71	209	2	20	14	1	0	-1	1	0	0	2.287845002869841	
i 1	588.2375578231292	3.2825	74	701	4	4	15	8	5005	-1	8	0	0	4.004062984616236	
i 1	588.2391632653062	5.05	72	1093	4	5	10	2	0	1	2	0	0	3.043848439455805	
i 1	588.2528095238096	0.2525	71	209	1	20	7	1	0	0	1	0	0	2.287845002869841	
i 1	588.2608367346938	0.2525	74	209	3	4	2	8	0	-2	8	0	0	4.004062984616236	
i 1	588.2616394557823	0.2525	74	209	7	1	16	16	0	1	16	0	0	5.419419833319788	
i 1	588.264850340136	0.2525	72	209	4	5	12	2	0	-2	2	0	0	3.043848439455805	
i 1	588.4819387755102	0.505	72	701	4	5	5	2	5005	1	2	0	0	3.043848439455805	
i 1	588.5028095238096	0.2525	71	1093	2	20	2	1	0	0	1	0	0	2.287845002869841	
i 1	588.5084285714286	0.505	74	209	4	1	16	17	0	2	17	0	0	5.419419833319788	
i 1	588.5156530612245	0.2525	71	1093	1	20	12	1	0	-1	1	0	0	2.287845002869841	
i 1	588.5172585034013	1.2625	74	1093	6	1	10	16	0	1	16	0	0	5.419419833319788	
i 1	588.5172585034013	0.2525	68	701	2	24	15	0	5005	-1	0	0	0	6.287845002869841	
i 1	588.7439795918367	1.7675	71	209	2	20	9	1	0	-1	1	0	0	2.287845002869841	
i 1	588.7439795918367	0.2525	68	209	1	24	12	1	5005	0	1	0	0	6.287845002869841	
i 1	588.7455850340136	0.2525	75	1093	4	5	6	8	0	1	8	0	0	3.043848439455805	
i 1	588.7504013605442	0.505	74	701	4	24	7	17	5005	1	17	0	0	6.419419833319788	
i 1	588.7640476190476	1.2625	71	209	1	20	2	0	0	0	0	0	0	2.287845002869841	
i 1	588.9803333333333	1.7675	71	209	1	24	14	0	0	-1	0	0	0	6.287845002869841	
i 1	588.9931768707482	0.2525	72	209	4	5	3	2	0	-2	2	0	0	3.043848439455805	
i 1	588.9979931972789	1.01	77	209	6	1	14	16	0	2	16	0	0	5.419419833319788	
i 1	589.0060204081633	0.505	71	209	3	3	1	8	0	-2	8	0	0	4.004062984616236	
i 1	589.0132448979592	0.2525	72	209	4	5	13	2	0	1	2	0	0	3.043848439455805	
i 1	589.2319387755102	0.505	72	209	4	5	11	2	0	1	2	0	0	3.043848439455805	
i 1	589.2471904761904	0.2525	74	209	7	1	16	16	0	1	16	0	0	5.419419833319788	
i 1	589.2479931972789	0.7575000000000001	71	209	5	9	12	2	0	-1	2	0	0	3.004062984616236	
i 1	589.4915714285714	2.525	74	701	6	1	15	16	5005	2	16	0	0	5.419419833319788	
i 1	589.4915714285714	0.7575000000000001	72	209	4	5	7	2	0	-2	2	0	0	3.043848439455805	
i 1	589.7311360544218	0.505	71	1093	5	2	14	8	0	-2	8	0	0	4.004062984616236	
i 1	589.7423741496599	0.2525	74	701	4	24	16	17	5005	1	17	0	0	6.419419833319788	
i 1	589.7487959183674	0.2525	71	209	3	3	3	8	0	-2	8	0	0	4.004062984616236	
i 1	589.7560204081633	2.02	72	701	4	5	7	2	5005	-2	2	0	0	3.043848439455805	
i 1	589.7568231292518	1.7675	68	209	1	20	5	0	5005	0	0	0	0	2.287845002869841	
i 1	589.764850340136	1.7675	68	209	1	20	16	1	0	-1	1	0	0	2.287845002869841	
i 1	589.990768707483	0.7575000000000001	74	1093	6	1	16	16	0	1	16	0	0	5.419419833319788	
i 1	589.9923741496599	1.01	74	209	7	1	13	16	0	1	16	0	0	5.419419833319788	
i 1	590.009231292517	0.505	71	1093	5	2	7	2	0	-1	2	0	0	4.004062984616236	
i 1	590.2439795918367	0.2525	71	209	5	9	4	2	0	-1	2	0	0	3.004062984616236	
i 1	590.2680612244898	0.505	72	209	4	5	2	2	0	1	2	0	0	3.043848439455805	
i 1	590.4843469387755	3.535	68	209	1	24	14	1	5005	0	1	0	0	6.287845002869841	
i 1	590.4875578231292	0.7575000000000001	71	209	5	9	1	8	0	-1	8	0	0	3.004062984616236	
i 1	590.4939795918367	0.2525	74	209	4	24	12	17	0	1	17	0	0	6.419419833319788	
i 1	590.4979931972789	2.525	71	1093	5	2	14	8	0	-2	8	0	0	4.004062984616236	
i 1	590.5020068027211	3.535	71	209	2	24	15	1	0	0	1	0	0	6.287845002869841	
i 1	590.5116394557823	6.0600000000000005	61	209	5	18	7	9	0	1	9	0	0	2.5046176726734664	
i 1	590.5124421768708	0.2525	71	209	1	20	13	1	0	-1	1	0	0	2.287845002869841	
i 1	590.735149659864	0.2525	77	209	7	1	5	16	0	2	16	0	0	5.419419833319788	
i 1	590.7479931972789	0.2525	74	701	5	3	14	2	5005	-1	2	0	0	4.004062984616236	
i 1	590.7688639455782	0.2525	77	1093	6	1	5	17	0	1	17	0	0	5.419419833319788	
i 1	591.0028095238096	0.7575000000000001	71	209	6	3	7	8	0	-2	8	0	0	4.004062984616236	
i 1	591.009231292517	3.0300000000000002	74	701	4	24	9	17	5005	1	17	0	0	6.419419833319788	
i 1	591.2447823129252	0.2525	71	1093	5	2	2	2	0	-1	2	0	0	4.004062984616236	
i 1	591.2640476190476	0.505	77	1093	6	1	16	17	0	1	17	0	0	5.419419833319788	
i 1	591.4843469387755	0.2525	72	701	4	5	7	2	5005	1	2	0	0	3.043848439455805	
i 1	591.4867551020408	0.2525	71	209	5	9	12	2	0	-1	2	0	0	3.004062984616236	
i 1	591.5028095238096	0.505	75	1093	4	5	16	8	0	1	8	0	0	3.043848439455805	
i 1	591.5044149659864	0.505	74	209	3	4	16	8	0	-2	8	0	0	4.004062984616236	
i 1	591.5044149659864	0.2525	71	209	2	20	10	1	0	-1	1	0	0	2.287845002869841	
i 1	591.5060204081633	0.2525	71	209	1	24	4	0	0	-1	0	0	0	6.287845002869841	
i 1	591.7311360544218	0.2525	68	209	1	20	15	1	0	-1	1	0	0	2.287845002869841	
i 1	591.7423741496599	0.7575000000000001	75	209	3	5	13	8	0	1	8	0	0	3.043848439455805	
i 1	591.7504013605442	0.505	72	209	4	5	10	2	0	-2	2	0	0	3.043848439455805	
i 1	591.7544149659864	0.505	74	701	5	3	11	2	5005	-1	2	0	0	4.004062984616236	
i 1	591.7560204081633	0.505	74	209	7	1	2	16	0	1	16	0	0	5.419419833319788	
i 1	591.7688639455782	0.2525	71	209	1	20	11	0	0	0	0	0	0	2.287845002869841	
i 1	591.9867551020408	0.7575000000000001	77	209	7	1	16	16	0	2	16	0	0	5.419419833319788	
i 1	591.9891632653062	1.5150000000000001	72	701	4	5	10	2	5005	-2	2	0	0	3.043848439455805	
i 1	591.9915714285714	3.0300000000000002	74	701	4	4	10	8	5005	-1	8	0	0	4.004062984616236	
i 1	592.2319387755102	0.7575000000000001	71	209	1	20	5	0	0	0	0	0	0	2.287845002869841	
i 1	592.2431768707482	1.5150000000000001	77	1093	6	1	5	17	0	1	17	0	0	5.419419833319788	
i 1	592.2504013605442	0.505	71	209	5	9	8	8	0	-1	8	0	0	3.004062984616236	
i 1	592.2632448979592	0.505	72	209	4	5	16	2	0	1	2	0	0	3.043848439455805	
i 1	592.5140476190476	2.02	72	701	4	5	5	2	5005	1	2	0	0	3.043848439455805	
i 1	592.7423741496599	0.2525	71	209	2	20	4	1	0	-1	1	0	0	2.287845002869841	
i 1	592.759231292517	0.505	71	1093	5	2	6	2	0	-1	2	0	0	4.004062984616236	
i 1	592.7688639455782	0.2525	75	209	3	5	4	8	0	1	8	0	0	3.043848439455805	
i 1	592.985149659864	2.02	68	209	1	20	1	1	0	-1	1	0	0	2.287845002869841	
i 1	592.9883605442177	0.2525	75	1093	4	5	8	8	0	1	8	0	0	3.043848439455805	
i 1	592.9915714285714	0.505	74	701	6	1	1	16	5005	2	16	0	0	5.419419833319788	
i 1	592.9931768707482	0.505	71	209	5	9	12	8	0	-1	8	0	0	3.004062984616236	
i 1	593.0036122448979	0.505	68	209	1	20	11	0	5005	0	0	0	0	2.287845002869841	
i 1	593.2327414965987	0.505	75	209	3	5	10	8	0	1	8	0	0	3.043848439455805	
i 1	593.2431768707482	0.505	71	1093	5	2	11	8	0	-2	8	0	0	4.004062984616236	
i 1	593.2520068027211	0.2525	72	209	4	5	12	2	0	-2	2	0	0	3.043848439455805	
i 1	593.4811360544218	1.5150000000000001	61	209	4	19	7	9	0	1	9	0	0	2.5046176726734664	
i 1	593.4875578231292	2.02	74	701	6	1	5	16	5005	2	16	0	0	5.419419833319788	
i 1	593.4891632653062	0.505	72	209	4	5	3	2	0	1	2	0	0	3.043848439455805	
i 1	593.5012040816326	2.7775	74	701	5	3	7	2	5005	-1	2	0	0	4.004062984616236	
i 1	593.5068231292518	1.5150000000000001	72	1093	5	5	1	2	0	1	2	0	0	3.043848439455805	
i 1	593.7327414965987	0.2525	71	209	5	9	2	8	0	-1	8	0	0	3.004062984616236	
i 1	593.733544217687	0.2525	72	701	4	5	6	2	5005	-2	2	0	0	3.043848439455805	
i 1	593.7512040816326	0.505	71	1093	6	2	2	2	0	-1	2	0	0	4.004062984616236	
i 1	593.7640476190476	0.505	77	209	7	1	14	16	0	2	16	0	0	5.419419833319788	
i 1	593.764850340136	0.2525	74	209	7	1	12	16	0	1	16	0	0	5.419419833319788	
i 1	593.985149659864	0.2525	71	209	2	20	15	1	0	-1	1	0	0	2.287845002869841	
i 1	593.9947823129252	0.2525	72	209	4	5	12	2	0	1	2	0	0	3.043848439455805	
i 1	593.9971904761904	0.505	74	209	5	24	2	17	0	1	17	0	0	6.419419833319788	
i 1	594.0028095238096	0.7575000000000001	71	209	5	9	15	2	0	-1	2	0	0	3.004062984616236	
i 1	594.0036122448979	0.2525	71	209	1	24	16	0	0	-1	0	0	0	6.287845002869841	
i 1	594.0156530612245	0.2525	72	209	3	5	8	2	0	-2	2	0	0	3.043848439455805	
i 1	594.2391632653062	0.2525	71	209	1	20	4	0	0	0	0	0	0	2.287845002869841	
i 1	594.2415714285714	0.2525	71	209	5	9	14	8	0	-1	8	0	0	3.004062984616236	
i 1	594.2479931972789	0.2525	74	701	4	24	7	17	5005	1	17	0	0	6.419419833319788	
i 1	594.2495986394558	0.505	72	209	4	5	5	2	0	1	2	0	0	3.043848439455805	
i 1	594.2520068027211	0.2525	71	209	2	24	10	1	0	0	1	0	0	6.287845002869841	
i 1	594.2576258503401	0.7575000000000001	74	209	7	1	6	17	0	2	17	0	0	5.419419833319788	
i 1	594.4883605442177	2.02	72	701	4	5	6	2	5005	-2	2	0	0	3.043848439455805	
i 1	594.490768707483	0.505	71	209	1	24	15	0	0	-1	0	0	0	6.287845002869841	
i 1	594.4955850340136	0.505	71	1093	6	2	9	2	0	-1	2	0	0	4.004062984616236	
i 1	594.4979931972789	0.505	77	1093	6	1	14	17	0	1	17	0	0	5.419419833319788	
i 1	594.4987959183674	1.01	71	209	1	20	16	1	0	-1	1	0	0	2.287845002869841	
i 1	594.5156530612245	0.505	74	1093	6	1	1	16	0	1	16	0	0	5.419419833319788	
i 1	594.7319387755102	0.2525	74	209	5	4	6	8	0	-2	8	0	0	4.004062984616236	
i 1	594.9819387755102	1.5150000000000001	61	911	5	17	12	9	0	1	9	0	0	2.5046176726734664	
i 1	594.9827414965987	0.505	71	209	1	20	15	0	0	0	0	0	0	2.287845002869841	
i 1	594.9843469387755	1.5150000000000001	66	911	5	17	2	6	0	1	6	0	0	2.5046176726734664	
i 1	594.9883605442177	0.2525	74	209	5	4	14	8	0	-2	8	0	0	4.004062984616236	
i 1	594.9915714285714	0.505	75	911	5	5	5	8	0	-2	8	0	0	3.043848439455805	
i 1	594.9955850340136	0.2525	77	209	7	1	8	16	0	2	16	0	0	5.419419833319788	
i 1	594.9995986394558	0.2525	71	209	5	9	13	2	0	-1	2	0	0	3.004062984616236	
i 1	595.0012040816326	1.5150000000000001	77	911	6	1	9	16	0	1	16	0	0	5.419419833319788	
i 1	595.0028095238096	1.5150000000000001	61	209	5	19	6	9	0	1	9	0	0	2.5046176726734664	
i 1	595.009231292517	0.505	74	911	5	2	13	2	0	-2	2	0	0	4.004062984616236	
i 1	595.0132448979592	1.5150000000000001	71	209	2	24	3	1	0	0	1	0	0	6.287845002869841	
i 1	595.016455782313	1.5150000000000001	61	209	3	19	7	9	0	1	9	0	0	2.5046176726734664	
i 1	595.0180612244898	0.2525	74	911	6	1	9	17	0	1	17	0	0	5.419419833319788	
i 1	595.2327414965987	1.2625	74	701	4	4	10	8	5005	-1	8	0	0	4.004062984616236	
i 1	595.2375578231292	0.7575000000000001	72	209	4	5	3	2	0	1	2	0	0	3.043848439455805	
i 1	595.2399659863945	0.2525	74	701	4	24	5	17	5005	1	17	0	0	6.419419833319788	
i 1	595.2688639455782	0.2525	74	209	7	1	4	16	0	1	16	0	0	5.419419833319788	
i 1	595.485149659864	0.505	74	911	6	1	12	17	0	1	17	0	0	5.419419833319788	
i 1	595.490768707483	0.2525	74	209	4	24	3	17	0	1	17	0	0	6.419419833319788	
i 1	595.4923741496599	0.2525	71	911	1	20	5	1	0	0	1	0	0	2.287845002869841	
i 1	595.4987959183674	0.2525	71	911	1	20	15	0	0	0	0	0	0	2.287845002869841	
i 1	595.5004013605442	0.7575000000000001	77	209	7	1	12	16	0	2	16	0	0	5.419419833319788	
i 1	595.5076258503401	0.2525	72	209	4	5	4	2	0	1	2	0	0	3.043848439455805	
i 1	595.5180612244898	0.505	72	209	3	5	11	2	0	-2	2	0	0	3.043848439455805	
i 1	595.5180612244898	0.2525	71	701	1	20	6	1	5005	-1	1	0	0	2.287845002869841	
i 1	595.7367551020408	0.2525	71	209	1	20	10	1	0	-1	1	0	0	2.287845002869841	
i 1	595.7423741496599	0.2525	71	209	5	9	5	2	0	-1	2	0	0	3.004062984616236	
i 1	595.7423741496599	0.505	71	209	1	20	14	0	0	-1	0	0	0	2.287845002869841	
i 1	595.7560204081633	0.505	75	209	2	5	12	8	0	1	8	0	0	3.043848439455805	
i 1	595.7616394557823	0.2525	74	911	5	2	15	2	0	-2	2	0	0	4.004062984616236	
i 1	595.983544217687	0.505	74	701	6	1	5	16	5005	2	16	0	0	5.419419833319788	
i 1	595.9867551020408	0.505	74	911	6	2	6	8	0	-1	8	0	0	4.004062984616236	
i 1	595.9891632653062	0.505	72	701	4	5	6	2	5005	1	2	0	0	3.043848439455805	
i 1	595.990768707483	0.2525	74	701	4	24	2	17	5005	1	17	0	0	6.419419833319788	
i 1	596.0052176870748	0.505	75	911	5	5	9	8	0	-2	8	0	0	3.043848439455805	
i 1	596.235149659864	0.2525	74	209	6	1	10	17	0	2	17	0	0	5.419419833319788	
i 1	596.2431768707482	0.2525	71	209	5	9	11	8	0	-1	8	0	0	3.004062984616236	
i 1	596.2600340136055	0.2525	72	209	3	5	3	2	0	-2	2	0	0	3.043848439455805	
i 1	596.2696666666667	0.2525	71	209	1	20	4	1	0	-1	1	0	0	2.287845002869841	
i 1	596.4811360544218	6.8175	61	209	3	19	6	9	0	1	9	0	0	4.007388276277546	
i 1	596.4859523809524	0.7575000000000001	74	911	6	2	10	8	0	-1	8	0	0	4.0	
i 1	596.4875578231292	0.7575000000000001	74	911	6	2	11	2	0	-2	2	0	0	4.0	
i 1	596.490768707483	0.2525	71	209	5	9	2	2	0	-1	2	0	0	3.0	
i 1	596.4923741496599	3.0300000000000002	66	209	4	27	9	6	0	1	6	0	0	12.926105448427196	
i 1	596.4939795918367	4.04	61	701	5	25	14	9	5005	1	9	0	0	0.5795377403358183	
i 1	596.4955850340136	6.0600000000000005	61	911	5	17	9	9	0	1	9	0	0	4.007388276277546	
i 1	596.4979931972789	4.04	66	701	5	17	6	6	5005	1	6	0	0	4.007388276277546	
i 1	596.4987959183674	2.02	74	701	6	1	1	16	5005	2	16	0	0	2.39300230301072	
i 1	596.4995986394558	1.7675	75	911	5	5	6	8	0	-2	8	0	0	3.3506708850691216	
i 1	596.5004013605442	0.7575000000000001	77	911	6	1	15	16	0	1	16	0	0	2.39300230301072	
i 1	596.5004013605442	3.0300000000000002	66	911	5	25	10	6	0	0	6	0	0	0.5795377403358183	
i 1	596.5020068027211	4.04	74	701	4	4	10	8	5005	-1	8	0	0	4.0	
i 1	596.5020068027211	4.04	66	701	5	17	15	6	5005	0	6	0	0	4.007388276277546	
i 1	596.5028095238096	4.04	66	701	5	25	11	9	5005	0	9	0	0	0.5795377403358183	
i 1	596.5044149659864	6.8175	61	209	5	18	10	6	0	1	6	0	0	4.007388276277546	
i 1	596.5052176870748	0.2525	71	209	2	20	14	1	0	-1	1	0	0	2.287845002869841	
i 1	596.5060204081633	0.7575000000000001	72	209	3	5	7	2	0	-2	2	0	0	3.3506708850691216	
i 1	596.5084285714286	6.8175	61	209	5	26	3	9	0	1	9	0	0	0.5795377403358183	
i 1	596.509231292517	6.0600000000000005	61	911	5	25	5	9	0	0	9	0	0	0.5795377403358183	
i 1	596.509231292517	6.8175	61	209	5	26	6	9	0	0	9	0	0	0.5795377403358183	
i 1	596.5100340136055	6.8175	61	209	4	27	10	6	0	1	6	0	0	12.926105448427196	
i 1	596.5108367346938	0.2525	72	911	5	5	7	2	0	1	2	0	0	3.3506708850691216	
i 1	596.5116394557823	6.8175	61	209	3	19	13	9	0	1	9	0	0	4.007388276277546	
i 1	596.5132448979592	3.0300000000000002	72	701	4	5	7	2	5005	-2	2	0	0	3.3506708850691216	
i 1	596.5156530612245	6.8175	61	209	5	18	8	9	0	1	9	0	0	4.007388276277546	
i 1	596.5196666666667	9.09	66	911	5	17	13	6	0	1	6	0	0	4.007388276277546	
i 1	596.7399659863945	0.7575000000000001	71	209	1	20	12	0	0	-1	0	0	0	2.287845002869841	
i 1	596.7528095238096	0.2525	72	701	4	5	10	2	5005	1	2	0	0	3.3506708850691216	
i 1	596.7672585034013	0.7575000000000001	74	701	5	3	8	2	5005	-1	2	0	0	4.0	
i 1	596.9995986394558	3.2825	74	701	4	24	3	17	5005	1	17	0	0	3.39300230301072	
i 1	597.2439795918367	0.2525	72	701	4	5	2	2	5005	1	2	0	0	3.3506708850691216	
i 1	597.2455850340136	0.505	74	911	6	1	7	17	0	1	17	0	0	2.39300230301072	
i 1	597.2471904761904	0.7575000000000001	74	209	3	4	15	8	0	-2	8	0	0	4.0	
i 1	597.2487959183674	0.2525	75	209	2	5	9	8	0	1	8	0	0	3.3506708850691216	
i 1	597.2495986394558	0.2525	74	209	7	1	4	16	0	1	16	0	0	2.39300230301072	
i 1	597.2584285714286	0.505	71	209	5	9	1	8	0	-1	8	0	0	3.0	
i 1	597.2632448979592	0.2525	71	209	2	20	4	1	0	-1	1	0	0	2.287845002869841	
i 1	597.4899659863945	0.505	72	209	4	5	6	2	0	1	2	0	0	3.3506708850691216	
i 1	597.4939795918367	0.7575000000000001	74	209	5	24	2	17	0	1	17	0	0	3.39300230301072	
i 1	597.4963877551021	2.02	71	209	2	24	13	1	0	0	1	0	0	6.287845002869841	
i 1	597.5124421768708	0.505	72	911	5	5	14	2	0	1	2	0	0	3.3506708850691216	
i 1	597.5188639455782	0.505	74	911	6	2	2	2	0	-2	2	0	0	4.0	
i 1	597.7375578231292	1.7675	77	911	6	1	10	16	0	1	16	0	0	2.39300230301072	
i 1	597.7415714285714	0.2525	74	911	6	2	1	8	0	-1	8	0	0	4.0	
i 1	597.9883605442177	0.505	72	701	4	5	8	2	5005	1	2	0	0	3.3506708850691216	
i 1	598.0124421768708	0.505	72	209	4	5	9	2	0	1	2	0	0	3.3506708850691216	
i 1	598.0132448979592	0.2525	71	209	3	3	9	8	0	-2	8	0	0	4.0	
i 1	598.0172585034013	0.2525	71	209	5	9	7	8	0	-1	8	0	0	3.0	
i 1	598.0180612244898	0.2525	74	701	5	3	7	2	5005	-1	2	0	0	4.0	
i 1	598.2303333333333	0.505	74	209	6	1	9	17	0	2	17	0	0	2.39300230301072	
i 1	598.233544217687	0.505	71	209	5	9	13	2	0	-1	2	0	0	3.0	
i 1	598.2447823129252	0.7575000000000001	72	911	5	5	3	2	0	1	2	0	0	3.3506708850691216	
i 1	598.2624421768708	0.2525	74	911	6	2	11	8	0	-1	8	0	0	4.0	
i 1	598.2680612244898	1.7675	74	911	6	2	4	2	0	-2	2	0	0	4.0	
i 1	598.4875578231292	0.2525	72	209	3	5	4	2	0	-2	2	0	0	3.3506708850691216	
i 1	598.490768707483	4.04	71	209	2	20	4	1	0	-1	1	0	0	2.287845002869841	
i 1	598.5004013605442	0.2525	74	911	6	1	6	17	0	1	17	0	0	2.39300230301072	
i 1	598.5012040816326	0.505	71	209	1	20	11	1	0	-1	1	0	0	2.287845002869841	
i 1	598.5020068027211	1.01	75	911	5	5	9	8	0	-2	8	0	0	3.3506708850691216	
i 1	598.5100340136055	0.505	71	209	3	3	2	8	0	-2	8	0	0	4.0	
i 1	598.7343469387755	0.2525	74	209	5	24	3	17	0	1	17	0	0	3.39300230301072	
i 1	598.7359523809524	0.2525	77	209	7	1	2	16	0	2	16	0	0	2.39300230301072	
i 1	598.7359523809524	0.2525	75	209	2	5	6	8	0	1	8	0	0	3.3506708850691216	
i 1	598.7383605442177	0.505	74	209	3	4	12	8	0	-2	8	0	0	4.0	
i 1	598.9859523809524	0.505	68	911	1	20	5	0	0	-1	0	0	0	2.287845002869841	
i 1	598.9891632653062	0.505	72	209	3	5	9	2	0	-2	2	0	0	3.3506708850691216	
i 1	598.9939795918367	0.505	68	701	1	24	10	0	5005	0	0	0	0	6.287845002869841	
i 1	599.0124421768708	0.2525	71	209	5	9	7	8	0	-1	8	0	0	3.0	
i 1	599.0188639455782	0.505	68	911	1	20	16	0	0	-1	0	0	0	2.287845002869841	
i 1	599.0196666666667	1.5150000000000001	74	701	6	1	6	16	5005	2	16	0	0	2.39300230301072	
i 1	599.2471904761904	0.2525	74	701	5	3	5	2	5005	-1	2	0	0	4.0	
i 1	599.2528095238096	0.2525	71	209	5	9	3	2	0	-1	2	0	0	3.0	
i 1	599.4811360544218	0.2525	75	911	4	5	7	8	0	-2	8	0	0	3.3506708850691216	
i 1	599.4859523809524	0.505	71	209	1	20	10	1	0	-1	1	0	0	2.287845002869841	
i 1	599.4867551020408	0.505	72	209	4	5	12	2	0	1	2	0	0	3.3506708850691216	
i 1	599.4875578231292	0.505	71	209	1	20	3	0	0	-1	0	0	0	2.287845002869841	
i 1	599.4883605442177	3.7875	66	209	4	27	1	6	0	1	6	0	0	12.926105448427196	
i 1	599.4931768707482	6.0600000000000005	61	911	5	14	4	6	0	0	6	0	0	7.205152875419933	
i 1	599.4931768707482	1.01	72	701	4	5	6	2	5005	1	2	0	0	3.3506708850691216	
i 1	599.4979931972789	0.505	74	209	3	4	10	8	0	-2	8	0	0	4.0	
i 1	599.5052176870748	1.01	72	701	5	5	10	2	5005	-2	2	0	0	3.3506708850691216	
i 1	599.5084285714286	3.7875	71	209	1	24	4	1	0	252	1	307	0	6.287845002869841	
i 1	599.5132448979592	0.2525	77	209	7	1	12	16	0	2	16	0	0	2.39300230301072	
i 1	599.516455782313	0.2525	74	209	6	1	14	17	0	2	17	0	0	2.39300230301072	
i 1	599.5196666666667	8.08	66	911	5	25	16	6	0	0	6	0	0	0.5795377403358183	
i 1	599.7311360544218	0.505	72	209	4	5	6	2	0	1	2	0	0	3.3506708850691216	
i 1	599.733544217687	0.505	74	209	5	24	12	17	0	1	17	0	0	3.39300230301072	
i 1	599.7552176870748	0.505	71	209	3	3	16	8	0	-2	8	0	0	4.0	
i 1	599.759231292517	0.505	77	911	6	1	13	16	0	1	16	0	0	2.39300230301072	
i 1	599.9803333333333	0.505	71	209	5	9	1	8	0	-1	8	0	0	3.0	
i 1	599.9955850340136	0.505	74	701	5	3	11	2	5005	-1	2	0	0	4.0	
i 1	600.0020068027211	0.505	71	701	1	20	1	1	5005	-1	1	0	0	2.287845002869841	
i 1	600.0108367346938	0.7575000000000001	71	911	1	20	1	0	0	-1	0	0	0	2.287845002869841	
i 1	600.0180612244898	2.525	72	911	5	5	13	2	0	1	2	0	0	3.3506708850691216	
i 1	600.2303333333333	1.7675	74	209	7	1	7	16	0	1	16	0	0	2.39300230301072	
i 1	600.2520068027211	0.2525	74	209	6	1	13	17	0	2	17	0	0	2.39300230301072	
i 1	600.2584285714286	0.505	74	911	6	1	6	17	0	1	17	0	0	2.39300230301072	
i 1	600.2584285714286	0.505	68	911	1	20	2	1	0	-1	1	0	0	2.287845002869841	
i 1	600.2640476190476	1.2625	74	209	3	4	13	8	0	-2	8	0	0	4.0	
i 1	600.2696666666667	0.2525	72	209	3	5	6	2	0	-2	2	0	0	3.3506708850691216	
i 1	600.4803333333333	7.07	61	595	5	25	3	9	0	1	9	0	0	0.5795377403358183	
i 1	600.4859523809524	0.505	75	595	5	5	1	2	0	-2	2	0	0	3.3506708850691216	
i 1	600.4923741496599	2.2725	74	595	6	1	7	17	0	1	17	0	0	2.39300230301072	
i 1	600.4931768707482	4.2925	71	595	5	3	1	2	0	-2	2	0	0	4.0	
i 1	600.4931768707482	0.2525	71	209	3	3	14	8	0	-2	8	0	0	4.0	
i 1	600.5060204081633	0.2525	72	209	4	5	5	2	0	1	2	0	0	3.3506708850691216	
i 1	600.5068231292518	5.05	66	595	5	25	9	9	0	0	9	0	0	0.5795377403358183	
i 1	600.5084285714286	0.505	74	595	4	4	6	8	0	-1	8	0	0	4.0	
i 1	600.5084285714286	7.07	61	595	5	17	9	6	0	0	6	0	0	4.007388276277546	
i 1	600.5084285714286	0.2525	68	595	1	20	5	0	0	0	0	0	0	2.287845002869841	
i 1	600.509231292517	0.2525	77	209	7	1	14	16	0	2	16	0	0	2.39300230301072	
i 1	600.509231292517	0.505	72	595	4	5	9	2	0	1	2	0	0	3.3506708850691216	
i 1	600.5124421768708	7.07	61	595	5	17	10	9	0	0	9	0	0	4.007388276277546	
i 1	600.733544217687	0.505	74	209	6	1	4	17	0	2	17	0	0	2.39300230301072	
i 1	600.740768707483	1.01	71	209	1	24	7	0	0	252	0	307	0	6.287845002869841	
i 1	600.7471904761904	1.01	68	209	1	20	6	1	0	0	1	0	0	2.287845002869841	
i 1	600.7479931972789	0.2525	71	209	5	9	12	8	0	-1	8	0	0	3.0	
i 1	600.7568231292518	1.01	71	209	1	20	15	0	0	-1	0	0	0	2.287845002869841	
i 1	600.759231292517	0.7575000000000001	77	911	6	1	3	16	0	1	16	0	0	2.39300230301072	
i 1	600.7608367346938	0.2525	75	911	4	5	1	8	0	-2	8	0	0	3.3506708850691216	
i 1	601.0004013605442	0.505	72	209	3	5	3	2	0	-2	2	0	0	3.3506708850691216	
i 1	601.0060204081633	2.525	74	911	6	2	16	8	0	-1	8	0	0	4.0	
i 1	601.0188639455782	0.505	75	209	2	5	1	8	0	1	8	0	0	3.3506708850691216	
i 1	601.2375578231292	0.2525	77	595	4	24	6	17	0	2	17	0	0	3.39300230301072	
i 1	601.483544217687	1.01	72	209	4	5	12	2	0	1	2	0	0	3.3506708850691216	
i 1	601.4915714285714	0.2525	74	911	6	2	12	2	0	-2	2	0	0	4.0	
i 1	601.4931768707482	0.2525	74	209	5	24	16	17	0	1	17	0	0	3.39300230301072	
i 1	601.4995986394558	0.2525	74	911	6	1	7	17	0	1	17	0	0	2.39300230301072	
i 1	601.5004013605442	2.2725	75	595	5	5	12	2	0	-2	2	0	0	3.3506708850691216	
i 1	601.5060204081633	0.2525	72	595	4	5	4	2	0	1	2	0	0	3.3506708850691216	
i 1	601.5140476190476	0.2525	71	209	5	9	8	8	0	-1	8	0	0	3.0	
i 1	601.7447823129252	0.505	68	911	1	20	11	1	0	0	1	0	0	2.287845002869841	
i 1	601.7463877551021	0.505	71	595	1	24	2	0	0	0	0	0	0	6.287845002869841	
i 1	601.7495986394558	3.0300000000000002	77	595	4	24	1	17	0	2	17	0	0	3.39300230301072	
i 1	601.7608367346938	0.2525	75	911	4	5	12	8	0	-2	8	0	0	3.3506708850691216	
i 1	601.764850340136	0.505	71	209	5	9	3	2	0	-1	2	0	0	3.0	
i 1	601.7672585034013	0.505	68	911	1	20	2	1	0	-1	1	0	0	2.287845002869841	
i 1	601.9963877551021	0.505	77	911	6	1	1	16	0	1	16	0	0	2.39300230301072	
i 1	602.0108367346938	0.2525	74	209	5	24	3	17	0	1	17	0	0	3.39300230301072	
i 1	602.0188639455782	0.505	74	911	6	2	8	2	0	-2	2	0	0	4.0	
i 1	602.2319387755102	0.505	71	209	3	3	15	8	0	-2	8	0	0	4.0	
i 1	602.2319387755102	1.01	68	209	1	20	14	0	0	0	0	0	0	2.287845002869841	
i 1	602.2375578231292	1.01	68	209	1	24	11	0	0	248	0	308	0	6.287845002869841	
i 1	602.2520068027211	0.505	74	911	6	1	9	17	0	1	17	0	0	2.39300230301072	
i 1	602.4803333333333	5.05	61	911	5	13	7	9	0	1	9	0	0	4.817213742015223	
i 1	602.5068231292518	5.05	61	911	5	25	6	9	0	0	9	0	0	0.5795377403358183	
i 1	602.5076258503401	4.04	75	911	5	5	7	8	0	-2	8	0	0	3.3506708850691216	
i 1	602.5116394557823	0.7575000000000001	71	209	1	20	7	1	0	-1	1	0	0	2.287845002869841	
i 1	602.5132448979592	1.5150000000000001	77	911	6	1	12	16	0	1	16	0	0	2.39300230301072	
i 1	602.5156530612245	0.2525	71	209	5	9	16	8	0	-1	8	0	0	3.0	
i 1	602.7504013605442	0.2525	74	209	6	1	4	17	0	2	17	0	0	2.39300230301072	
i 1	602.7504013605442	0.2525	74	209	3	4	7	8	0	-2	8	0	0	4.0	
i 1	602.7544149659864	0.2525	74	209	7	1	4	16	0	1	16	0	0	2.39300230301072	
i 1	602.759231292517	0.2525	74	911	6	2	13	2	0	-2	2	0	0	4.0	
i 1	602.9843469387755	0.505	74	595	6	1	6	17	0	1	17	0	0	2.39300230301072	
i 1	602.9843469387755	0.505	72	911	4	5	10	2	0	1	2	0	0	3.3506708850691216	
i 1	602.9963877551021	0.2525	75	209	2	5	9	8	0	1	8	0	0	3.3506708850691216	
i 1	603.0172585034013	0.2525	74	911	6	1	7	17	0	1	17	0	0	2.39300230301072	
i 1	603.2303333333333	4.2925	66	1177	4	26	12	9	0	1	9	0	0	0.5795377403358183	
i 1	603.2303333333333	4.2925	61	208	4	27	14	9	0	1	9	0	0	12.926105448427196	
i 1	603.2359523809524	4.2925	61	1177	4	26	6	9	0	1	9	0	0	0.5795377403358183	
i 1	603.2367551020408	0.505	72	1177	4	5	16	2	0	1	2	0	0	3.3506708850691216	
i 1	603.2431768707482	4.2925	61	208	3	19	2	6	0	0	6	0	0	4.007388276277546	
i 1	603.2471904761904	4.2925	61	1177	4	18	4	9	0	0	9	0	0	4.007388276277546	
i 1	603.2512040816326	4.2925	61	208	3	19	5	9	0	0	9	0	0	4.007388276277546	
i 1	603.2528095238096	4.2925	66	1177	4	18	5	9	0	1	9	0	0	4.007388276277546	
i 1	603.2544149659864	1.2625	68	1177	1	20	6	1	0	0	1	0	0	2.287845002869841	
i 1	603.2624421768708	1.2625	71	1177	1	20	7	1	0	-1	1	0	0	2.287845002869841	
i 1	603.266455782313	4.2925	66	208	4	27	11	9	0	1	9	0	0	12.926105448427196	
i 1	603.5084285714286	1.5150000000000001	74	1177	5	9	6	2	0	-2	2	0	0	3.0	
i 1	603.5100340136055	1.01	72	208	2	5	16	2	0	-2	2	0	0	3.3506708850691216	
i 1	603.733544217687	1.7675	74	595	6	1	16	17	0	1	17	0	0	2.39300230301072	
i 1	603.7447823129252	0.2525	72	595	5	5	12	2	0	1	2	0	0	3.3506708850691216	
i 1	603.7512040816326	0.7575000000000001	68	1177	1	20	5	1	0	-1	1	0	0	2.287845002869841	
i 1	603.759231292517	3.7875	74	595	4	4	5	8	0	-1	8	0	0	4.0	
i 1	603.7696666666667	0.2525	72	911	4	5	2	2	0	1	2	0	0	3.3506708850691216	
i 1	603.9803333333333	1.5150000000000001	75	595	5	5	15	2	0	-2	2	0	0	3.3506708850691216	
i 1	603.9971904761904	2.02	71	1177	1	24	12	0	0	-1	0	0	0	6.287845002869841	
i 1	604.0100340136055	0.2525	75	1177	4	5	2	8	0	1	8	0	0	3.3506708850691216	
i 1	604.2431768707482	0.505	72	1177	4	5	1	2	0	1	2	0	0	3.3506708850691216	
i 1	604.4843469387755	0.2525	68	595	1	20	2	1	0	-1	1	0	0	2.287845002869841	
i 1	604.4875578231292	0.505	77	1177	6	1	10	16	0	1	16	0	0	2.39300230301072	
i 1	604.4931768707482	0.2525	71	911	1	20	4	0	0	0	0	0	0	2.287845002869841	
i 1	604.4971904761904	0.2525	71	595	1	24	12	0	0	-1	0	0	0	6.287845002869841	
i 1	604.5028095238096	0.2525	71	911	1	20	14	0	0	-1	0	0	0	2.287845002869841	
i 1	604.5100340136055	0.2525	72	595	5	5	3	2	0	1	2	0	0	3.3506708850691216	
i 1	604.7303333333333	0.2525	77	911	6	1	1	16	0	1	16	0	0	2.39300230301072	
i 1	604.7399659863945	0.2525	72	911	4	5	2	2	0	1	2	0	0	3.3506708850691216	
i 1	604.740768707483	1.01	74	1177	5	9	10	8	0	-2	8	0	0	3.0	
i 1	604.7415714285714	0.2525	75	1177	4	5	10	8	0	1	8	0	0	3.3506708850691216	
i 1	604.7439795918367	0.505	71	1177	1	20	14	0	0	0	0	0	0	2.287845002869841	
i 1	604.7479931972789	1.01	77	1177	6	1	9	17	0	1	17	0	0	2.39300230301072	
i 1	604.7616394557823	0.2525	68	1177	1	20	15	0	0	-1	0	0	0	2.287845002869841	
i 1	604.9819387755102	0.505	74	911	6	1	10	17	0	1	17	0	0	2.39300230301072	
i 1	604.9891632653062	0.505	74	208	3	4	3	2	0	-1	2	0	0	4.0	
i 1	605.2584285714286	0.2525	77	208	6	1	1	16	0	2	16	0	0	2.39300230301072	
i 1	605.4859523809524	2.02	74	911	6	2	1	2	0	-2	2	0	0	4.0	
i 1	605.4947823129252	0.2525	71	208	3	3	13	8	0	-1	8	0	0	4.0	
i 1	605.4971904761904	2.02	74	595	6	1	3	17	0	1	17	0	0	2.39300230301072	
i 1	605.4971904761904	0.2525	74	208	5	24	14	17	0	2	17	0	0	3.39300230301072	
i 1	605.5068231292518	2.02	61	595	5	15	8	9	0	1	9	0	0	5.613193453150127	
i 1	605.5076258503401	2.02	61	911	5	14	6	6	0	0	6	0	0	7.205152875419933	
i 1	605.5116394557823	2.02	75	595	4	5	8	2	0	-2	2	0	0	3.3506708850691216	
i 1	605.5172585034013	0.7575000000000001	77	595	4	24	14	17	0	2	17	0	0	3.39300230301072	
i 1	605.5196666666667	2.02	66	595	5	25	1	9	0	0	9	0	0	0.5795377403358183	
i 1	605.735149659864	0.7575000000000001	77	208	5	1	8	16	0	2	16	0	0	2.39300230301072	
i 1	605.7423741496599	0.7575000000000001	74	208	3	4	7	2	0	-1	2	0	0	4.0	
i 1	605.7528095238096	0.7575000000000001	72	208	2	5	1	2	0	-2	2	0	0	3.3506708850691216	
i 1	605.7544149659864	0.7575000000000001	74	911	6	1	3	17	0	1	17	0	0	2.39300230301072	
i 1	605.7672585034013	0.505	71	595	5	3	1	2	0	-2	2	0	0	4.0	
i 1	606.2383605442177	0.2525	74	911	6	2	12	8	0	-1	8	0	0	4.0	
i 1	606.2415714285714	1.2625	71	1177	1	24	15	0	0	-1	0	0	0	6.287845002869841	
i 1	606.2560204081633	0.2525	74	208	5	24	4	17	0	2	17	0	0	3.39300230301072	
i 1	606.4827414965987	0.2525	75	1177	5	5	11	8	0	1	8	0	0	3.3506708850691216	
i 1	606.4867551020408	0.2525	77	1177	6	1	5	16	0	1	16	0	0	2.39300230301072	
i 1	606.4923741496599	0.505	71	208	3	3	13	8	0	-1	8	0	0	4.0	
i 1	606.4955850340136	0.2525	68	595	1	24	15	0	0	0	0	0	0	6.287845002869841	
i 1	606.4987959183674	0.2525	68	595	1	20	16	1	0	-1	1	0	0	2.287845002869841	
i 1	606.5004013605442	0.2525	71	595	5	3	4	2	0	-2	2	0	0	4.0	
i 1	606.5052176870748	0.2525	77	595	4	24	9	17	0	2	17	0	0	3.39300230301072	
i 1	606.5100340136055	0.2525	71	911	1	20	15	0	0	-1	0	0	0	2.287845002869841	
i 1	606.5124421768708	0.2525	72	208	3	5	5	2	0	1	2	0	0	3.3506708850691216	
i 1	606.5124421768708	1.01	71	1177	1	20	15	1	0	-1	1	0	0	2.287845002869841	
i 1	606.5132448979592	1.01	72	595	5	5	3	2	0	1	2	0	0	3.3506708850691216	
i 1	606.5180612244898	0.2525	77	1177	6	1	11	17	0	1	17	0	0	2.39300230301072	
i 1	606.7303333333333	0.505	74	911	6	1	16	17	0	1	17	0	0	2.39300230301072	
i 1	606.7359523809524	0.7575000000000001	77	911	6	1	3	16	0	1	16	0	0	2.39300230301072	
i 1	606.7375578231292	0.7575000000000001	72	911	5	5	15	2	0	1	2	0	0	3.3506708850691216	
i 1	606.7399659863945	0.505	77	208	5	1	10	16	0	2	16	0	0	2.39300230301072	
i 1	606.7616394557823	0.7575000000000001	71	1177	1	20	11	0	0	0	0	0	0	2.287845002869841	
i 1	607.2479931972789	0.2525	77	1177	6	1	6	16	0	1	16	0	0	2.39300230301072	
i 1	607.2520068027211	0.2525	72	1177	4	5	16	2	0	1	2	0	0	3.3506708850691216	
i 1	607.2616394557823	0.2525	77	595	4	24	7	17	0	2	17	0	0	3.39300230301072	
i 1	607.4803333333333	4.04	61	702	5	25	2	6	0	0	6	0	0	0.5795377403358183	
i 1	607.4811360544218	16.16	61	702	5	14	3	9	0	0	9	0	0	7.205152875419933	
i 1	607.4843469387755	1.01	66	702	5	13	1	9	0	0	9	0	0	4.817213742015223	
i 1	607.4843469387755	13.13	61	702	3	27	10	6	0	1	6	0	0	12.926105448427196	
i 1	607.485149659864	0.505	74	702	6	2	9	8	0	-2	8	0	0	4.0	
i 1	607.485149659864	0.505	72	1088	4	5	7	2	0	-2	2	0	0	3.3506708850691216	
i 1	607.4875578231292	10.1	66	1088	4	18	7	6	0	1	6	0	0	4.007388276277546	
i 1	607.4891632653062	7.07	61	1088	4	26	8	9	0	1	9	0	0	0.5795377403358183	
i 1	607.4915714285714	7.07	61	702	5	25	8	9	0	1	9	0	0	0.5795377403358183	
i 1	607.4939795918367	0.505	77	702	6	1	8	17	0	1	17	0	0	2.39300230301072	
i 1	607.4939795918367	1.01	74	204	7	1	10	16	0	1	16	0	0	2.39300230301072	
i 1	607.4939795918367	1.01	66	204	5	17	3	6	0	1	6	0	0	4.007388276277546	
i 1	607.4955850340136	0.505	75	204	5	5	5	2	0	-2	2	0	0	3.3506708850691216	
i 1	607.4971904761904	13.13	61	702	3	19	11	6	0	1	6	0	0	4.007388276277546	
i 1	607.4987959183674	1.01	61	204	6	25	13	9	0	1	9	0	0	0.5795377403358183	
i 1	607.4995986394558	4.04	66	1088	4	26	11	9	0	0	9	0	0	0.5795377403358183	
i 1	607.5020068027211	0.2525	74	702	6	2	6	2	0	-2	2	0	0	4.0	
i 1	607.5036122448979	0.2525	77	702	5	1	7	16	0	2	16	0	0	2.39300230301072	
i 1	607.5060204081633	0.7575000000000001	71	1088	5	9	3	2	0	-1	2	0	0	3.0	
i 1	607.5060204081633	0.2525	72	204	4	5	4	8	0	1	8	0	0	3.3506708850691216	
i 1	607.5068231292518	7.07	66	1088	4	18	11	6	0	1	6	0	0	4.007388276277546	
i 1	607.509231292517	4.2925	71	204	5	4	5	2	0	-2	2	0	0	4.0	
i 1	607.5108367346938	4.04	66	204	5	15	6	9	0	0	9	0	0	5.613193453150127	
i 1	607.5116394557823	10.1	66	204	5	25	5	9	0	0	9	0	0	0.5795377403358183	
i 1	607.5124421768708	4.04	61	204	5	17	5	9	0	1	9	0	0	4.007388276277546	
i 1	607.5140476190476	16.16	66	702	3	19	3	9	0	0	9	0	0	4.007388276277546	
i 1	607.5140476190476	10.1	66	702	3	27	2	9	0	0	9	0	0	12.926105448427196	
i 1	607.5140476190476	1.7675	75	702	5	5	14	2	0	1	2	0	0	3.3506708850691216	
i 1	607.516455782313	1.01	77	204	5	24	1	16	0	2	16	0	0	3.39300230301072	
i 1	607.7495986394558	0.505	77	1088	6	1	12	17	0	1	17	0	0	2.39300230301072	
i 1	607.7512040816326	0.505	71	1088	4	9	4	8	0	-1	8	0	0	3.0	
i 1	607.7544149659864	0.505	75	702	2	5	6	2	0	-2	2	0	0	3.3506708850691216	
i 1	607.9827414965987	0.2525	77	702	4	24	16	16	0	2	16	0	0	3.39300230301072	
i 1	608.0036122448979	0.2525	75	702	5	5	14	2	0	1	2	0	0	3.3506708850691216	
i 1	608.0076258503401	2.2725	74	204	6	3	8	2	0	-2	2	0	0	4.0	
i 1	608.0196666666667	0.505	72	204	4	5	5	8	0	1	8	0	0	3.3506708850691216	
i 1	608.2359523809524	0.2525	74	702	6	2	13	2	0	-2	2	0	0	4.0	
i 1	608.2375578231292	0.2525	74	1088	6	1	14	16	0	2	16	0	0	2.39300230301072	
i 1	608.2383605442177	0.2525	68	204	1	24	14	1	0	-1	1	0	0	6.287845002869841	
i 1	608.2455850340136	0.2525	75	204	5	5	2	2	0	-2	2	0	0	3.3506708850691216	
i 1	608.2487959183674	0.2525	74	702	3	4	7	8	0	-1	8	0	0	4.0	
i 1	608.2495986394558	0.2525	72	1088	4	5	16	2	0	-2	2	0	0	3.3506708850691216	
i 1	608.2520068027211	1.7675	77	702	6	1	1	17	0	1	17	0	0	2.39300230301072	
i 1	608.266455782313	0.2525	71	204	1	20	15	0	0	-1	0	0	0	2.287845002869841	
i 1	608.2672585034013	0.2525	71	702	1	20	6	0	0	0	0	0	0	2.287845002869841	
i 1	608.490768707483	3.0300000000000002	77	204	5	24	15	16	0	2	16	0	0	3.39300230301072	
i 1	608.4931768707482	0.505	74	702	6	1	12	16	0	1	16	0	0	2.39300230301072	
i 1	608.5052176870748	0.2525	77	1088	6	1	1	17	0	1	17	0	0	2.39300230301072	
i 1	608.5076258503401	6.0600000000000005	61	204	5	15	9	9	0	1	9	0	0	5.613193453150127	
i 1	608.5100340136055	3.2825	72	204	5	5	2	8	0	1	8	0	0	3.3506708850691216	
i 1	608.5124421768708	0.505	74	702	5	2	7	2	0	-2	2	0	0	4.0	
i 1	608.5124421768708	12.120000000000001	61	204	5	25	10	9	0	1	9	0	0	0.5795377403358183	
i 1	608.5140476190476	18.18	66	702	5	13	13	9	0	0	9	0	0	4.817213742015223	
i 1	608.5140476190476	0.2525	71	1088	5	9	6	8	0	-1	8	0	0	3.0	
i 1	608.7303333333333	0.2525	72	1088	4	5	7	2	0	-2	2	0	0	3.3506708850691216	
i 1	608.7311360544218	0.505	77	702	5	1	14	16	0	2	16	0	0	2.39300230301072	
i 1	608.735149659864	0.7575000000000001	75	204	4	5	9	2	0	-2	2	0	0	3.3506708850691216	
i 1	608.9811360544218	0.505	74	702	6	2	12	8	0	-2	8	0	0	4.0	
i 1	608.9819387755102	0.2525	74	702	3	3	6	8	0	-1	8	0	0	4.0	
i 1	608.985149659864	0.505	75	702	3	5	12	2	0	-2	2	0	0	3.3506708850691216	
i 1	609.0156530612245	0.2525	74	204	7	1	12	16	0	1	16	0	0	2.39300230301072	
i 1	609.2327414965987	1.2625	77	1088	6	1	12	17	0	1	17	0	0	2.39300230301072	
i 1	609.2504013605442	0.505	74	702	3	4	2	8	0	-1	8	0	0	4.0	
i 1	609.2512040816326	0.2525	74	1088	6	1	1	16	0	2	16	0	0	2.39300230301072	
i 1	609.2512040816326	4.04	75	702	5	5	9	2	0	1	2	0	0	3.3506708850691216	
i 1	609.483544217687	0.2525	72	1088	4	5	15	2	0	-2	2	0	0	3.3506708850691216	
i 1	609.4891632653062	0.2525	74	204	7	1	2	16	0	1	16	0	0	2.39300230301072	
i 1	609.5012040816326	0.2525	72	1088	4	5	8	2	0	1	2	0	0	3.3506708850691216	
i 1	609.514850340136	0.505	74	702	3	3	9	8	0	-1	8	0	0	4.0	
i 1	609.7327414965987	0.7575000000000001	74	702	5	2	5	2	0	-2	2	0	0	4.0	
i 1	609.7471904761904	0.2525	75	702	2	5	8	2	0	-2	2	0	0	3.3506708850691216	
i 1	609.7696666666667	0.2525	75	702	5	5	9	2	0	1	2	0	0	3.3506708850691216	
i 1	609.9843469387755	0.2525	74	702	6	1	9	16	0	1	16	0	0	2.39300230301072	
i 1	609.9859523809524	0.505	72	1088	4	5	8	2	0	1	2	0	0	3.3506708850691216	
i 1	609.9923741496599	0.2525	68	702	1	20	5	1	0	-1	1	0	0	2.287845002869841	
i 1	610.0124421768708	0.2525	71	204	1	24	1	0	0	-1	0	0	0	6.287845002869841	
i 1	610.014850340136	0.2525	71	1088	5	9	2	8	0	-1	8	0	0	3.0	
i 1	610.0172585034013	0.2525	77	702	5	1	13	16	0	2	16	0	0	2.39300230301072	
i 1	610.0180612244898	0.2525	68	204	1	20	12	0	0	0	0	0	0	2.287845002869841	
i 1	610.2383605442177	0.505	71	1088	5	9	9	2	0	-1	2	0	0	3.0	
i 1	610.2391632653062	0.2525	74	702	6	2	7	8	0	-2	8	0	0	4.0	
i 1	610.2568231292518	0.2525	74	1088	6	1	5	16	0	2	16	0	0	2.39300230301072	
i 1	610.2640476190476	0.2525	77	702	6	1	7	17	0	1	17	0	0	2.39300230301072	
i 1	610.4891632653062	0.7575000000000001	74	702	3	4	6	8	0	-1	8	0	0	4.0	
i 1	610.4931768707482	3.2825	74	204	6	3	5	2	0	-2	2	0	0	4.0	
i 1	610.5020068027211	5.05	74	204	7	1	12	16	0	1	16	0	0	2.39300230301072	
i 1	610.5076258503401	1.01	77	702	5	1	16	16	0	2	16	0	0	2.39300230301072	
i 1	610.5180612244898	1.2625	75	702	3	5	1	2	0	-2	2	0	0	3.3506708850691216	
i 1	610.7624421768708	0.2525	74	702	6	2	4	8	0	-2	8	0	0	4.0	
i 1	610.9859523809524	0.7575000000000001	71	1088	5	9	4	2	0	-1	2	0	0	3.0	
i 1	611.2303333333333	0.7575000000000001	71	1088	5	9	15	8	0	-1	8	0	0	3.0	
i 1	611.2696666666667	0.2525	75	702	5	5	11	2	0	1	2	0	0	3.3506708850691216	
i 1	611.483544217687	6.0600000000000005	61	1088	4	16	15	6	0	0	6	0	0	6.40917316428503	
i 1	611.4883605442177	1.2625	74	1088	6	1	12	16	0	2	16	0	0	2.39300230301072	
i 1	611.5012040816326	0.505	72	1088	4	5	6	2	0	1	2	0	0	3.3506708850691216	
i 1	611.5084285714286	12.120000000000001	66	1088	4	26	14	9	0	0	9	0	0	0.5795377403358183	
i 1	611.5100340136055	18.18	66	204	6	15	6	9	0	0	9	0	0	5.613193453150127	
i 1	611.7423741496599	0.2525	75	204	5	5	10	2	0	-2	2	0	0	3.3506708850691216	
i 1	611.7487959183674	0.2525	74	702	5	2	8	2	0	-2	2	0	0	4.0	
i 1	611.7504013605442	0.505	77	204	5	24	4	16	0	2	16	0	0	3.39300230301072	
i 1	611.7616394557823	1.01	75	702	5	5	6	2	0	1	2	0	0	3.3506708850691216	
i 1	611.7624421768708	0.505	74	702	3	4	13	8	0	-1	8	0	0	4.0	
i 1	611.9811360544218	0.2525	74	702	6	1	4	16	0	1	16	0	0	2.39300230301072	
i 1	611.9827414965987	2.7775	72	204	5	5	8	8	0	1	8	0	0	3.3506708850691216	
i 1	611.9955850340136	0.505	74	702	5	2	3	8	0	-2	8	0	0	4.0	
i 1	612.0028095238096	1.2625	74	702	5	3	8	8	0	-1	8	0	0	4.0	
i 1	612.0052176870748	0.2525	75	702	3	5	11	2	0	-2	2	0	0	3.3506708850691216	
i 1	612.2343469387755	0.505	77	702	5	1	10	16	0	2	16	0	0	2.39300230301072	
i 1	612.2495986394558	0.2525	72	1088	3	5	8	2	0	-2	2	0	0	3.3506708850691216	
i 1	612.2576258503401	1.2625	77	702	6	1	6	17	0	1	17	0	0	2.39300230301072	
i 1	612.2616394557823	2.7775	71	204	5	4	1	2	0	-2	2	0	0	4.0	
i 1	612.4827414965987	0.2525	71	1088	5	9	13	2	0	-1	2	0	0	3.0	
i 1	612.5036122448979	0.7575000000000001	75	702	3	5	6	2	0	-2	2	0	0	3.3506708850691216	
i 1	612.733544217687	0.2525	71	1088	5	9	2	8	0	-1	8	0	0	3.0	
i 1	612.7423741496599	0.2525	77	1088	6	1	15	17	0	1	17	0	0	2.39300230301072	
i 1	612.7471904761904	0.7575000000000001	72	1088	3	5	5	2	0	-2	2	0	0	3.3506708850691216	
i 1	612.7672585034013	0.2525	74	702	6	1	10	16	0	1	16	0	0	2.39300230301072	
i 1	612.9819387755102	0.2525	77	702	4	24	6	16	0	2	16	0	0	3.39300230301072	
i 1	613.0012040816326	0.505	77	204	5	24	12	16	0	2	16	0	0	3.39300230301072	
i 1	613.2447823129252	0.505	72	1088	4	5	14	2	0	1	2	0	0	3.3506708850691216	
i 1	613.2544149659864	2.7775	75	204	5	5	14	2	0	-2	2	0	0	3.3506708850691216	
i 1	613.2552176870748	0.505	74	702	3	4	5	8	0	-1	8	0	0	4.0	
i 1	613.2656530612245	0.2525	71	1088	5	9	9	2	0	-1	2	0	0	3.0	
i 1	613.4803333333333	0.505	77	702	5	1	15	16	0	2	16	0	0	2.39300230301072	
i 1	613.4859523809524	1.01	74	1088	6	1	5	16	0	2	16	0	0	2.39300230301072	
i 1	613.490768707483	0.505	75	702	3	5	4	2	0	-2	2	0	0	3.3506708850691216	
i 1	613.4931768707482	0.7575000000000001	74	702	5	2	3	2	0	-2	2	0	0	4.0	
i 1	613.4955850340136	0.2525	77	1088	6	1	1	17	0	1	17	0	0	2.39300230301072	
i 1	613.7303333333333	0.2525	72	1088	3	5	15	2	0	-2	2	0	0	3.3506708850691216	
i 1	613.7479931972789	0.505	77	702	6	1	15	17	0	1	17	0	0	2.39300230301072	
i 1	613.7528095238096	0.2525	71	1088	5	9	6	8	0	-1	8	0	0	3.0	
i 1	613.7536122448979	0.7575000000000001	71	1088	5	9	9	2	0	-1	2	0	0	3.0	
i 1	613.9891632653062	0.505	72	1088	4	5	10	2	0	1	2	0	0	3.3506708850691216	
i 1	613.9947823129252	0.2525	74	702	6	1	8	16	0	1	16	0	0	2.39300230301072	
i 1	613.9955850340136	0.2525	75	702	5	5	6	2	0	1	2	0	0	3.3506708850691216	
i 1	613.9971904761904	2.525	74	702	5	2	1	8	0	-2	8	0	0	4.0	
i 1	614.2399659863945	0.2525	77	702	4	24	1	16	0	2	16	0	0	3.39300230301072	
i 1	614.2568231292518	0.505	74	702	5	3	2	8	0	-1	8	0	0	4.0	
i 1	614.2680612244898	2.525	77	204	5	24	8	16	0	2	16	0	0	3.39300230301072	
i 1	614.5036122448979	6.0600000000000005	66	1088	4	16	6	6	0	0	6	0	0	6.40917316428503	
i 1	614.5052176870748	0.7575000000000001	75	702	3	5	9	2	0	-2	2	0	0	3.3506708850691216	
i 1	614.5060204081633	18.18	61	204	6	15	2	9	0	1	9	0	0	5.613193453150127	
i 1	614.5060204081633	0.2525	71	1088	5	9	13	8	0	-1	8	0	0	3.0	
i 1	614.5172585034013	12.120000000000001	61	1088	4	26	16	9	0	1	9	0	0	0.5795377403358183	
i 1	614.7463877551021	0.2525	74	702	6	1	15	16	0	1	16	0	0	2.39300230301072	
i 1	614.7463877551021	0.2525	74	1088	6	1	3	16	0	2	16	0	0	2.39300230301072	
i 1	614.7495986394558	1.5150000000000001	74	702	4	4	13	8	0	-1	8	0	0	4.0	
i 1	614.7520068027211	0.2525	71	1088	5	9	10	2	0	-1	2	0	0	3.0	
i 1	614.7600340136055	0.2525	72	1088	4	5	8	2	0	-2	2	0	0	3.3506708850691216	
i 1	614.7616394557823	5.3025	75	702	5	5	8	2	0	1	2	0	0	3.3506708850691216	
i 1	614.9891632653062	0.7575000000000001	77	702	5	1	6	16	0	2	16	0	0	2.39300230301072	
i 1	615.0028095238096	0.2525	68	204	1	20	8	1	0	0	1	0	0	2.287845002869841	
i 1	615.0044149659864	0.2525	68	204	1	24	14	0	0	0	0	0	0	6.287845002869841	
i 1	615.0052176870748	0.7575000000000001	72	1088	3	5	14	2	0	1	2	0	0	3.3506708850691216	
i 1	615.016455782313	0.2525	68	702	1	20	7	0	0	0	0	0	0	2.287845002869841	
i 1	615.2431768707482	1.2625	72	1088	4	5	13	2	0	-2	2	0	0	3.3506708850691216	
i 1	615.2463877551021	0.2525	77	702	4	24	16	16	0	2	16	0	0	3.39300230301072	
i 1	615.2584285714286	0.2525	74	702	6	2	14	2	0	-2	2	0	0	4.0	
i 1	615.2624421768708	0.505	71	1088	5	9	12	2	0	-1	2	0	0	3.0	
i 1	615.5004013605442	2.02	71	204	5	4	15	2	0	-2	2	0	0	4.0	
i 1	615.5068231292518	1.5150000000000001	74	702	6	1	14	16	0	1	16	0	0	2.39300230301072	
i 1	615.5100340136055	0.2525	77	1088	6	1	3	17	0	1	17	0	0	2.39300230301072	
i 1	615.7311360544218	4.7975	77	702	6	1	7	17	0	1	17	0	0	2.39300230301072	
i 1	615.7311360544218	0.2525	75	702	3	5	13	2	0	-2	2	0	0	3.3506708850691216	
i 1	615.7327414965987	0.2525	71	204	1	24	13	0	0	-1	0	0	0	6.287845002869841	
i 1	615.733544217687	0.2525	74	204	7	1	6	16	0	1	16	0	0	2.39300230301072	
i 1	615.7455850340136	0.2525	71	1088	5	9	3	8	0	-1	8	0	0	3.0	
i 1	615.7504013605442	0.2525	71	204	1	20	8	0	0	-1	0	0	0	2.287845002869841	
i 1	615.9819387755102	1.5150000000000001	75	702	5	5	3	2	0	1	2	0	0	3.3506708850691216	
i 1	615.985149659864	0.2525	72	1088	3	5	6	2	0	1	2	0	0	3.3506708850691216	
i 1	615.9947823129252	0.2525	71	1088	5	9	6	2	0	-1	2	0	0	3.0	
i 1	616.0140476190476	0.7575000000000001	77	702	5	1	14	16	0	2	16	0	0	2.39300230301072	
i 1	616.2520068027211	0.505	71	1088	5	9	9	8	0	-1	8	0	0	3.0	
i 1	616.2672585034013	0.505	75	702	3	5	13	2	0	-2	2	0	0	3.3506708850691216	
i 1	616.4979931972789	2.02	72	204	5	5	3	8	0	1	8	0	0	3.3506708850691216	
i 1	616.5044149659864	1.2625	74	702	6	2	11	2	0	-2	2	0	0	4.0	
i 1	616.7375578231292	0.2525	75	204	5	5	8	2	0	-2	2	0	0	3.3506708850691216	
i 1	616.7439795918367	0.2525	74	1088	6	1	7	16	0	2	16	0	0	2.39300230301072	
i 1	616.7495986394558	0.2525	68	204	1	20	5	0	0	-1	0	0	0	2.287845002869841	
i 1	616.7536122448979	0.2525	71	204	1	24	2	0	0	-1	0	0	0	6.287845002869841	
i 1	616.7560204081633	0.505	74	702	5	2	7	8	0	-2	8	0	0	4.0	
i 1	616.7576258503401	0.505	77	1088	6	1	6	17	0	1	17	0	0	2.39300230301072	
i 1	616.7576258503401	0.2525	74	702	5	3	5	8	0	-1	8	0	0	4.0	
i 1	616.9819387755102	0.2525	72	1088	4	5	3	2	0	-2	2	0	0	3.3506708850691216	
i 1	616.990768707483	0.2525	74	204	7	1	11	16	0	1	16	0	0	2.39300230301072	
i 1	616.9995986394558	0.505	74	204	5	3	13	2	0	-2	2	0	0	4.0	
i 1	617.0012040816326	0.505	77	702	5	1	2	16	0	2	16	0	0	2.39300230301072	
i 1	617.2487959183674	1.2625	77	204	5	24	7	16	0	2	16	0	0	3.39300230301072	
i 1	617.2600340136055	0.2525	71	1088	5	9	12	8	0	-1	8	0	0	3.0	
i 1	617.485149659864	18.18	61	1088	4	16	7	6	0	0	6	0	0	6.40917316428503	
i 1	617.4939795918367	0.2525	77	702	4	24	8	16	0	2	16	0	0	3.39300230301072	
i 1	617.4947823129252	6.0600000000000005	74	204	7	1	12	16	0	1	16	0	0	2.39300230301072	
i 1	617.4971904761904	0.505	74	702	5	3	6	8	0	-1	8	0	0	4.0	
i 1	617.5028095238096	0.505	75	702	2	5	13	2	0	-2	2	0	0	3.3506708850691216	
i 1	617.5044149659864	0.2525	74	702	4	4	8	8	0	-1	8	0	0	4.0	
i 1	617.5084285714286	12.120000000000001	66	702	3	27	3	9	0	0	9	0	0	12.926105448427196	
i 1	617.5140476190476	6.0600000000000005	66	702	3	12	8	6	0	0	6	0	0	6.40917316428503	
i 1	617.5188639455782	1.2625	71	204	5	4	14	2	0	-2	2	0	0	4.0	
i 1	617.7303333333333	2.7775	74	204	5	3	2	2	0	-2	2	0	0	4.0	
i 1	617.7455850340136	0.7575000000000001	74	1088	6	1	8	16	0	2	16	0	0	2.39300230301072	
i 1	617.7568231292518	0.7575000000000001	74	702	6	2	1	8	0	-2	8	0	0	4.0	
i 1	617.9803333333333	0.2525	71	204	1	20	9	0	0	0	0	0	0	2.287845002869841	
i 1	617.9891632653062	0.505	71	1088	5	9	2	8	0	-1	8	0	0	3.0	
i 1	617.990768707483	0.505	75	702	3	5	1	2	0	-2	2	0	0	3.3506708850691216	
i 1	617.9963877551021	0.2525	72	1088	4	5	1	2	0	1	2	0	0	3.3506708850691216	
i 1	618.0172585034013	0.2525	71	204	1	24	9	1	0	0	1	0	0	6.287845002869841	
i 1	618.235149659864	0.505	75	204	5	5	5	2	0	-2	2	0	0	3.3506708850691216	
i 1	618.2359523809524	1.5150000000000001	71	702	1	24	16	0	0	248	0	308	0	6.287845002869841	
i 1	618.4883605442177	1.01	74	702	5	3	6	8	0	-1	8	0	0	4.0	
i 1	618.4963877551021	0.505	74	702	6	1	15	16	0	1	16	0	0	2.39300230301072	
i 1	618.4963877551021	0.2525	77	702	4	24	16	16	0	2	16	0	0	3.39300230301072	
i 1	618.4979931972789	0.505	75	702	5	5	3	2	0	1	2	0	0	3.3506708850691216	
i 1	618.5020068027211	0.7575000000000001	71	1088	5	9	6	2	0	-1	2	0	0	3.0	
i 1	618.5188639455782	0.505	75	702	2	5	13	2	0	-2	2	0	0	3.3506708850691216	
i 1	618.7319387755102	0.2525	77	702	6	1	6	16	0	2	16	0	0	2.39300230301072	
i 1	618.7319387755102	0.505	72	1088	4	5	13	2	0	1	2	0	0	3.3506708850691216	
i 1	618.7680612244898	0.2525	71	1088	5	9	10	8	0	-1	8	0	0	3.0	
i 1	618.9819387755102	0.505	77	702	4	24	3	16	0	2	16	0	0	3.39300230301072	
i 1	618.9819387755102	0.505	72	1088	4	5	16	2	0	-2	2	0	0	3.3506708850691216	
i 1	618.9947823129252	1.01	74	702	4	4	8	8	0	-1	8	0	0	4.0	
i 1	619.0124421768708	5.05	72	204	5	5	8	8	0	1	8	0	0	3.3506708850691216	
i 1	619.2327414965987	1.2625	71	204	5	4	16	2	0	-2	2	0	0	4.0	
i 1	619.2696666666667	0.2525	75	702	3	5	11	2	0	-2	2	0	0	3.3506708850691216	
i 1	619.4867551020408	0.7575000000000001	77	204	5	24	16	16	0	2	16	0	0	3.39300230301072	
i 1	619.4915714285714	0.7575000000000001	75	702	2	5	8	2	0	-2	2	0	0	3.3506708850691216	
i 1	619.4987959183674	0.2525	75	702	5	5	10	2	0	1	2	0	0	3.3506708850691216	
i 1	619.5172585034013	0.2525	74	702	6	2	15	2	0	-2	2	0	0	4.0	
i 1	619.7303333333333	0.7575000000000001	68	204	1	20	16	0	0	-1	0	0	0	2.287845002869841	
i 1	619.7375578231292	0.2525	77	1088	6	1	14	17	0	1	17	0	0	2.39300230301072	
i 1	619.7375578231292	0.7575000000000001	68	204	1	24	4	0	0	0	0	0	0	6.287845002869841	
i 1	619.7696666666667	0.2525	74	702	6	2	16	8	0	-2	8	0	0	4.0	
i 1	619.983544217687	0.505	74	1088	6	1	11	16	0	2	16	0	0	2.39300230301072	
i 1	619.9931768707482	0.505	71	1088	5	9	12	2	0	-1	2	0	0	3.0	
i 1	619.9979931972789	0.2525	75	702	5	5	11	2	0	1	2	0	0	3.3506708850691216	
i 1	620.0036122448979	0.505	71	1088	5	9	11	8	0	-1	8	0	0	3.0	
i 1	620.0044149659864	0.2525	75	204	5	5	1	2	0	-2	2	0	0	3.3506708850691216	
i 1	620.2367551020408	0.2525	77	702	4	24	1	16	0	2	16	0	0	3.39300230301072	
i 1	620.2383605442177	0.505	72	1088	4	5	11	2	0	1	2	0	0	3.3506708850691216	
i 1	620.2504013605442	2.2725	75	702	5	5	2	2	0	1	2	0	0	3.3506708850691216	
i 1	620.2512040816326	1.01	72	1088	4	5	9	2	0	-2	2	0	0	3.3506708850691216	
i 1	620.4819387755102	6.0600000000000005	61	702	3	12	7	9	0	1	9	0	0	6.40917316428503	
i 1	620.4867551020408	0.2525	74	702	6	2	4	2	0	-2	2	0	0	4.0	
i 1	620.4867551020408	0.2525	74	702	6	2	4	8	0	-2	8	0	0	4.0	
i 1	620.4883605442177	0.2525	77	204	5	24	7	16	0	2	16	0	0	3.39300230301072	
i 1	620.490768707483	18.18	66	1088	4	16	13	6	0	0	6	0	0	6.40917316428503	
i 1	620.4955850340136	0.505	77	702	6	1	1	17	0	1	17	0	0	2.39300230301072	
i 1	620.4979931972789	1.7675	74	204	6	3	2	2	0	-2	2	0	0	4.0	
i 1	620.4979931972789	0.505	74	702	5	3	10	8	0	-1	8	0	0	4.0	
i 1	620.5036122448979	0.2525	77	702	4	24	6	16	0	2	16	0	0	3.39300230301072	
i 1	620.5044149659864	12.120000000000001	61	702	3	27	9	6	0	1	6	0	0	12.926105448427196	
i 1	620.7383605442177	0.505	77	1088	6	1	1	17	0	1	17	0	0	2.39300230301072	
i 1	620.7552176870748	0.505	74	702	4	4	14	8	0	-1	8	0	0	4.0	
i 1	620.7552176870748	0.505	75	702	3	5	12	2	0	-2	2	0	0	3.3506708850691216	
i 1	620.759231292517	2.7775	71	204	5	4	2	2	0	-2	2	0	0	4.0	
i 1	620.7608367346938	0.2525	77	702	6	1	16	16	0	2	16	0	0	2.39300230301072	
i 1	620.990768707483	0.505	74	702	6	2	6	8	0	-2	8	0	0	4.0	
i 1	620.9979931972789	0.505	74	702	6	1	6	16	0	1	16	0	0	2.39300230301072	
i 1	621.2303333333333	0.2525	75	702	3	5	12	2	0	-2	2	0	0	3.3506708850691216	
i 1	621.235149659864	0.2525	71	1088	5	9	7	8	0	-1	8	0	0	3.0	
i 1	621.235149659864	0.2525	75	702	5	5	5	2	0	1	2	0	0	3.3506708850691216	
i 1	621.259231292517	0.505	77	702	6	1	15	16	0	2	16	0	0	2.39300230301072	
i 1	621.2608367346938	0.7575000000000001	77	702	6	1	11	17	0	1	17	0	0	2.39300230301072	
i 1	621.4939795918367	0.2525	72	1088	4	5	16	2	0	-2	2	0	0	3.3506708850691216	
i 1	621.4955850340136	0.505	74	702	5	3	13	8	0	-1	8	0	0	4.0	
i 1	621.4987959183674	0.2525	72	1088	4	5	2	2	0	1	2	0	0	3.3506708850691216	
i 1	621.5004013605442	0.2525	74	702	6	2	6	2	0	-2	2	0	0	4.0	
i 1	621.7391632653062	0.505	74	702	6	1	4	16	0	1	16	0	0	2.39300230301072	
i 1	621.7415714285714	1.7675	75	702	3	5	9	2	0	-2	2	0	0	3.3506708850691216	
i 1	621.7544149659864	0.505	77	1088	6	1	15	17	0	1	17	0	0	2.39300230301072	
i 1	621.7640476190476	0.2525	71	1088	4	9	4	2	0	-1	2	0	0	3.0	
i 1	621.9947823129252	0.505	71	1088	5	9	6	8	0	-1	8	0	0	3.0	
i 1	622.0044149659864	0.2525	77	702	4	24	11	16	0	2	16	0	0	3.39300230301072	
i 1	622.009231292517	0.2525	75	702	5	5	5	2	0	1	2	0	0	3.3506708850691216	
i 1	622.2367551020408	0.2525	74	1088	6	1	16	16	0	2	16	0	0	2.39300230301072	
i 1	622.2504013605442	0.505	74	702	5	3	6	8	0	-1	8	0	0	4.0	
i 1	622.2552176870748	0.7575000000000001	74	702	4	4	4	8	0	-1	8	0	0	4.0	
i 1	622.259231292517	0.2525	77	702	6	1	1	17	0	1	17	0	0	2.39300230301072	
i 1	622.2616394557823	0.505	75	702	3	5	5	2	0	-2	2	0	0	3.3506708850691216	
i 1	622.2672585034013	0.505	77	702	6	1	3	16	0	2	16	0	0	2.39300230301072	
i 1	622.4827414965987	0.2525	77	1088	6	1	10	17	0	1	17	0	0	2.39300230301072	
i 1	622.483544217687	2.525	77	204	5	24	7	16	0	2	16	0	0	3.39300230301072	
i 1	622.4939795918367	0.2525	74	702	6	2	14	2	0	-2	2	0	0	4.0	
i 1	622.4963877551021	0.2525	75	204	5	5	9	2	0	-2	2	0	0	3.3506708850691216	
i 1	622.7359523809524	0.505	71	1088	5	9	4	8	0	-1	8	0	0	3.0	
i 1	622.7431768707482	0.505	72	1088	4	5	11	2	0	-2	2	0	0	3.3506708850691216	
i 1	622.759231292517	0.2525	71	1088	4	9	10	2	0	-1	2	0	0	3.0	
i 1	622.7672585034013	1.7675	77	702	6	1	15	17	0	1	17	0	0	2.39300230301072	
i 1	622.7688639455782	0.2525	75	702	5	5	16	2	0	1	2	0	0	3.3506708850691216	
i 1	622.9811360544218	0.2525	74	204	6	3	14	2	0	-2	2	0	0	4.0	
i 1	622.9867551020408	1.5150000000000001	75	204	5	5	13	2	0	-2	2	0	0	3.3506708850691216	
i 1	623.0108367346938	3.2825	74	702	6	2	10	8	0	-2	8	0	0	4.0	
i 1	623.014850340136	0.2525	77	1088	6	1	7	17	0	1	17	0	0	2.39300230301072	
i 1	623.233544217687	0.505	74	702	4	4	1	8	0	-1	8	0	0	4.0	
i 1	623.2399659863945	2.02	75	702	5	5	1	2	0	1	2	0	0	3.3506708850691216	
i 1	623.2560204081633	0.505	74	702	5	3	12	8	0	-1	8	0	0	4.0	
i 1	623.2688639455782	0.7575000000000001	74	1088	6	1	13	16	0	2	16	0	0	2.39300230301072	
i 1	623.4811360544218	4.04	71	204	5	4	8	2	0	-2	2	0	0	4.0	
i 1	623.4827414965987	0.2525	71	204	1	24	9	1	0	0	1	0	0	7.760239205515506	
i 1	623.4867551020408	18.18	66	702	5	12	14	6	0	0	6	0	0	6.40917316428503	
i 1	623.4875578231292	0.2525	75	702	5	5	11	2	0	1	2	0	0	3.3506708850691216	
i 1	623.4939795918367	0.2525	71	204	1	20	10	1	0	-1	1	0	0	3.7602392055155063	
i 1	623.5084285714286	0.505	74	702	6	1	2	16	0	1	16	0	0	2.39300230301072	
i 1	623.5196666666667	18.18	61	702	5	14	13	9	0	0	9	0	0	7.205152875419933	
i 1	623.7375578231292	2.02	71	702	1	24	16	0	0	252	0	307	0	7.760239205515506	
i 1	623.7415714285714	0.505	75	702	3	5	2	2	0	-2	2	0	0	3.3506708850691216	
i 1	623.7624421768708	0.2525	74	204	6	3	8	2	0	-2	2	0	0	4.0	
i 1	623.7640476190476	0.2525	71	1088	4	9	7	8	0	-1	8	0	0	3.0	
i 1	623.9843469387755	0.2525	74	702	4	4	1	8	0	-1	8	0	0	4.0	
i 1	623.9955850340136	0.2525	72	1088	4	5	11	2	0	-2	2	0	0	3.3506708850691216	
i 1	624.0036122448979	0.505	71	1088	4	9	13	2	0	-1	2	0	0	3.0	
i 1	624.0116394557823	0.2525	77	702	4	24	9	16	0	2	16	0	0	3.39300230301072	
i 1	624.0172585034013	5.3025	74	204	6	1	6	16	0	1	16	0	0	2.39300230301072	
i 1	624.2431768707482	0.2525	77	1088	6	1	1	17	0	1	17	0	0	2.39300230301072	
i 1	624.2584285714286	2.525	75	702	5	5	6	2	0	1	2	0	0	3.3506708850691216	
i 1	624.2672585034013	0.2525	75	702	3	5	14	2	0	-2	2	0	0	3.3506708850691216	
i 1	624.4819387755102	0.2525	77	702	4	24	5	16	0	2	16	0	0	3.39300230301072	
i 1	624.490768707483	0.505	75	702	3	5	10	2	0	-2	2	0	0	3.3506708850691216	
i 1	624.5108367346938	0.505	74	1088	6	1	11	16	0	2	16	0	0	2.39300230301072	
i 1	624.7584285714286	0.7575000000000001	77	702	6	1	16	16	0	2	16	0	0	2.39300230301072	
i 1	624.9803333333333	0.2525	77	1088	6	1	11	17	0	1	17	0	0	2.39300230301072	
i 1	624.9843469387755	0.505	74	702	6	1	11	16	0	1	16	0	0	2.39300230301072	
i 1	624.9883605442177	0.505	74	702	6	2	15	2	0	-2	2	0	0	4.0	
i 1	625.0020068027211	0.2525	75	204	5	5	16	2	0	-2	2	0	0	3.3506708850691216	
i 1	625.009231292517	0.505	72	204	5	5	1	8	0	1	8	0	0	3.3506708850691216	
i 1	625.2423741496599	0.505	77	204	5	24	4	16	0	2	16	0	0	3.39300230301072	
i 1	625.2520068027211	1.01	75	702	3	5	3	2	0	-2	2	0	0	3.3506708850691216	
i 1	625.2568231292518	0.505	72	1088	4	5	7	2	0	-2	2	0	0	3.3506708850691216	
i 1	625.4899659863945	0.2525	77	702	4	24	11	16	0	2	16	0	0	3.39300230301072	
i 1	625.490768707483	0.7575000000000001	71	1088	4	9	7	2	0	-1	2	0	0	3.0	
i 1	625.5028095238096	0.505	74	1088	6	1	2	16	0	2	16	0	0	2.39300230301072	
i 1	625.5116394557823	0.2525	75	702	5	5	16	2	0	1	2	0	0	3.3506708850691216	
i 1	625.7439795918367	0.2525	74	702	6	1	6	16	0	1	16	0	0	2.39300230301072	
i 1	625.7568231292518	0.505	75	702	3	5	15	2	0	-2	2	0	0	3.3506708850691216	
i 1	625.7608367346938	6.3125	72	204	5	5	13	8	0	1	8	0	0	3.3506708850691216	
i 1	625.7608367346938	0.2525	71	204	1	20	5	0	0	-1	0	0	0	3.7602392055155063	
i 1	625.7616394557823	0.2525	68	204	1	24	11	1	0	0	1	0	0	7.760239205515506	
i 1	625.7688639455782	0.505	77	702	6	1	5	16	0	2	16	0	0	2.39300230301072	
i 1	625.9923741496599	0.505	77	204	5	24	11	16	0	2	16	0	0	3.39300230301072	
i 1	626.2303333333333	0.2525	75	702	5	5	9	2	0	1	2	0	0	3.3506708850691216	
i 1	626.2343469387755	3.0300000000000002	74	204	6	3	4	2	0	-2	2	0	0	4.0	
i 1	626.235149659864	0.2525	74	702	4	4	16	8	0	-1	8	0	0	4.0	
i 1	626.2375578231292	0.2525	71	204	1	20	7	1	0	-1	1	0	0	3.7602392055155063	
i 1	626.2463877551021	0.2525	74	1088	6	1	13	16	0	2	16	0	0	2.39300230301072	
i 1	626.2479931972789	0.2525	74	702	6	2	5	2	0	-2	2	0	0	4.0	
i 1	626.2536122448979	2.525	77	702	6	1	15	17	0	1	17	0	0	2.39300230301072	
i 1	626.2600340136055	0.2525	72	1088	4	5	10	2	0	1	2	0	0	3.3506708850691216	
i 1	626.2600340136055	0.2525	68	204	1	24	1	1	0	-1	1	0	0	7.760239205515506	
i 1	626.4803333333333	0.505	71	1088	4	9	6	8	0	-1	8	0	0	3.0	
i 1	626.4827414965987	1.01	74	702	6	2	7	8	0	-2	8	0	0	4.0	
i 1	626.4867551020408	2.02	71	702	1	24	4	0	0	252	0	307	0	7.760239205515506	
i 1	626.4899659863945	0.505	77	702	4	24	5	16	0	2	16	0	0	3.39300230301072	
i 1	626.4979931972789	0.505	77	702	6	1	16	16	0	2	16	0	0	2.39300230301072	
i 1	626.4979931972789	0.2525	75	702	3	5	11	2	0	-2	2	0	0	3.3506708850691216	
i 1	626.4995986394558	15.15	61	702	5	12	4	9	0	1	9	0	0	6.40917316428503	
i 1	626.5140476190476	15.15	66	702	5	13	7	9	0	0	9	0	0	4.817213742015223	
i 1	626.5180612244898	0.505	75	702	3	5	8	2	0	-2	2	0	0	3.3506708850691216	
i 1	626.7383605442177	2.7775	75	702	5	5	12	2	0	1	2	0	0	3.3506708850691216	
i 1	626.7391632653062	0.505	72	1088	4	5	15	2	0	1	2	0	0	3.3506708850691216	
i 1	626.9827414965987	0.505	75	702	5	5	9	2	0	1	2	0	0	3.3506708850691216	
i 1	627.0028095238096	0.7575000000000001	74	702	6	1	6	16	0	1	16	0	0	2.39300230301072	
i 1	627.0084285714286	0.2525	77	1088	6	1	10	17	0	1	17	0	0	2.39300230301072	
i 1	627.0108367346938	0.2525	74	702	4	4	9	8	0	-1	8	0	0	4.0	
i 1	627.2391632653062	0.7575000000000001	71	1088	5	9	10	2	0	-1	2	0	0	3.0	
i 1	627.2528095238096	0.2525	72	1088	4	5	9	2	0	-2	2	0	0	3.3506708850691216	
i 1	627.2544149659864	0.2525	77	702	4	24	9	16	0	2	16	0	0	3.39300230301072	
i 1	627.4819387755102	0.2525	72	1088	4	5	7	2	0	1	2	0	0	3.3506708850691216	
i 1	627.4899659863945	0.2525	75	702	3	5	8	2	0	-2	2	0	0	3.3506708850691216	
i 1	627.5044149659864	0.2525	71	1088	4	9	13	8	0	-1	8	0	0	3.0	
i 1	627.7375578231292	0.7575000000000001	77	702	6	1	15	16	0	2	16	0	0	2.39300230301072	
i 1	627.7463877551021	0.2525	75	702	5	5	13	2	0	1	2	0	0	3.3506708850691216	
i 1	627.7495986394558	0.2525	74	702	6	2	15	2	0	-2	2	0	0	4.0	
i 1	627.7504013605442	0.2525	74	702	3	3	8	8	0	-1	8	0	0	4.0	
i 1	627.7688639455782	0.505	72	1088	4	5	15	2	0	-2	2	0	0	3.3506708850691216	
i 1	627.9811360544218	0.2525	74	702	6	1	1	16	0	1	16	0	0	2.39300230301072	
i 1	628.0004013605442	9.595	71	204	5	4	4	2	0	-2	2	0	0	4.0	
i 1	628.0052176870748	0.505	74	702	6	2	14	8	0	-2	8	0	0	4.0	
i 1	628.235149659864	0.2525	75	702	3	5	11	2	0	-2	2	0	0	3.3506708850691216	
i 1	628.2528095238096	0.505	71	1088	5	9	5	2	0	-1	2	0	0	3.0	
i 1	628.2608367346938	0.2525	75	204	5	5	9	2	0	-2	2	0	0	3.3506708850691216	
i 1	628.2632448979592	4.2925	77	204	5	24	9	16	0	2	16	0	0	3.39300230301072	
i 1	628.4811360544218	0.2525	74	702	4	4	6	8	0	-1	8	0	0	4.0	
i 1	628.4859523809524	0.505	68	204	1	20	3	1	0	-1	1	0	0	3.7602392055155063	
i 1	628.4899659863945	0.505	68	204	1	24	9	0	0	0	0	0	0	7.760239205515506	
i 1	628.4971904761904	0.2525	75	702	3	5	10	2	0	-2	2	0	0	3.3506708850691216	
i 1	628.5100340136055	0.2525	72	1088	4	5	4	2	0	1	2	0	0	3.3506708850691216	
i 1	628.7327414965987	1.01	75	702	3	5	5	2	0	-2	2	0	0	3.3506708850691216	
i 1	628.7343469387755	0.7575000000000001	77	1088	6	1	15	17	0	1	17	0	0	2.39300230301072	
i 1	628.7455850340136	0.2525	77	702	6	1	2	16	0	2	16	0	0	2.39300230301072	
i 1	628.7471904761904	0.7575000000000001	74	702	3	3	5	8	0	-1	8	0	0	4.0	
i 1	628.764850340136	0.505	72	1088	4	5	6	2	0	-2	2	0	0	3.3506708850691216	
i 1	628.7656530612245	0.7575000000000001	71	1088	4	9	4	8	0	-1	8	0	0	3.0	
i 1	629.0084285714286	0.2525	74	702	6	1	14	16	0	1	16	0	0	2.39300230301072	
i 1	629.2552176870748	0.7575000000000001	72	1088	4	5	1	2	0	1	2	0	0	3.3506708850691216	
i 1	629.2576258503401	2.02	77	702	6	1	3	17	0	1	17	0	0	2.39300230301072	
i 1	629.2632448979592	0.2525	74	702	4	4	10	8	0	-1	8	0	0	4.0	
i 1	629.4819387755102	0.2525	68	204	1	20	10	1	0	-1	1	0	0	3.7602392055155063	
i 1	629.4843469387755	0.2525	71	1088	5	9	15	2	0	-1	2	0	0	3.0	
i 1	629.4939795918367	12.120000000000001	66	702	1	27	1	9	0	252	9	307	0	12.926105448427196	
i 1	629.4979931972789	0.2525	75	702	3	5	7	2	0	-2	2	0	0	3.3506708850691216	
i 1	629.4979931972789	0.2525	71	204	1	24	10	0	0	-1	0	0	0	7.760239205515506	
i 1	629.4987959183674	0.505	77	1088	5	1	1	17	0	1	17	0	0	2.39300230301072	
i 1	629.5036122448979	12.120000000000001	66	204	6	15	15	9	0	0	9	0	0	5.613193453150127	
i 1	629.5044149659864	0.2525	71	702	4	20	16	1	0	0	1	0	0	3.7602392055155063	
i 1	629.5140476190476	0.2525	74	702	6	2	11	8	0	-2	8	0	0	4.0	
i 1	629.514850340136	0.2525	77	702	4	24	9	16	0	2	16	0	0	3.39300230301072	
i 1	629.516455782313	1.7675	74	204	6	3	5	2	0	-2	2	0	0	4.0	
i 1	629.7311360544218	0.2525	71	1088	5	9	8	8	0	-1	8	0	0	3.0	
i 1	629.7391632653062	0.505	74	1088	6	1	14	16	0	2	16	0	0	2.39300230301072	
i 1	629.7399659863945	1.5150000000000001	75	702	5	5	8	2	0	1	2	0	0	3.3506708850691216	
i 1	629.7415714285714	0.505	74	702	6	2	5	2	0	-2	2	0	0	4.0	
i 1	629.7439795918367	0.2525	68	1088	3	20	9	0	0	-1	0	0	0	3.7602392055155063	
i 1	629.766455782313	0.2525	75	702	5	5	14	2	0	1	2	0	0	3.3506708850691216	
i 1	629.985149659864	0.2525	74	702	6	1	7	16	0	1	16	0	0	2.39300230301072	
i 1	630.0028095238096	0.505	74	702	3	4	2	8	0	-1	8	0	0	4.0	
i 1	630.235149659864	0.2525	77	702	6	1	16	16	0	2	16	0	0	2.39300230301072	
i 1	630.2584285714286	0.7575000000000001	71	1088	5	9	8	8	0	-1	8	0	0	3.0	
i 1	630.266455782313	0.505	77	1088	5	1	13	17	0	1	17	0	0	2.39300230301072	
i 1	630.4875578231292	0.2525	68	204	1	20	15	0	0	0	0	0	0	3.7602392055155063	
i 1	630.4915714285714	0.2525	74	702	6	2	10	2	0	-2	2	0	0	4.0	
i 1	630.4971904761904	0.2525	71	204	1	24	8	1	0	0	1	0	0	7.760239205515506	
i 1	630.5052176870748	0.2525	68	702	4	20	2	0	0	0	0	0	0	3.7602392055155063	
i 1	630.514850340136	0.505	75	702	3	5	14	2	0	-2	2	0	0	3.3506708850691216	
i 1	630.7375578231292	0.2525	71	1088	5	9	4	2	0	-1	2	0	0	3.0	
i 1	630.7415714285714	0.2525	72	1088	4	5	12	2	0	-2	2	0	0	3.3506708850691216	
i 1	630.7544149659864	0.2525	74	702	6	1	7	16	0	1	16	0	0	2.39300230301072	
i 1	630.764850340136	1.01	77	702	4	24	5	16	0	2	16	0	0	3.39300230301072	
i 1	630.9819387755102	1.2625	74	702	3	4	7	8	0	-1	8	0	0	4.0	
i 1	631.0116394557823	1.2625	72	1088	4	5	12	2	0	1	2	0	0	3.3506708850691216	
i 1	631.014850340136	0.505	77	1088	5	1	14	17	0	1	17	0	0	2.39300230301072	
i 1	631.014850340136	2.525	75	204	5	5	11	2	0	-2	2	0	0	3.3506708850691216	
i 1	631.0180612244898	0.505	74	702	6	2	8	8	0	-2	8	0	0	4.0	
i 1	631.2512040816326	0.2525	75	702	5	5	6	2	0	1	2	0	0	3.3506708850691216	
i 1	631.2616394557823	0.2525	74	1088	6	1	13	16	0	2	16	0	0	2.39300230301072	
i 1	631.2640476190476	0.2525	74	702	6	2	11	2	0	-2	2	0	0	4.0	
i 1	631.4875578231292	0.2525	72	1088	4	5	1	2	0	-2	2	0	0	3.3506708850691216	
i 1	631.490768707483	4.04	74	204	6	1	15	16	0	1	16	0	0	2.39300230301072	
i 1	631.490768707483	0.2525	68	1088	3	20	4	0	0	0	0	0	0	3.7602392055155063	
i 1	631.5004013605442	0.505	71	1088	5	9	12	8	0	-1	8	0	0	3.0	
i 1	631.5068231292518	0.2525	74	702	6	1	14	16	0	1	16	0	0	2.39300230301072	
i 1	631.5108367346938	0.2525	71	1088	5	9	13	2	0	-1	2	0	0	3.0	
i 1	631.7391632653062	0.505	74	204	6	3	4	2	0	-2	2	0	0	4.0	
i 1	631.7431768707482	0.505	77	1088	5	1	2	17	0	1	17	0	0	2.39300230301072	
i 1	631.7512040816326	0.2525	77	702	6	1	8	17	0	1	17	0	0	2.39300230301072	
i 1	631.7528095238096	0.505	75	702	5	5	14	2	0	1	2	0	0	3.3506708850691216	
i 1	631.9883605442177	0.505	72	1088	4	5	15	2	0	-2	2	0	0	3.3506708850691216	
i 1	632.0068231292518	0.2525	74	702	3	3	16	8	0	-1	8	0	0	4.0	
i 1	632.0124421768708	0.7575000000000001	71	1088	3	20	10	1	0	-1	1	0	0	3.7602392055155063	
i 1	632.2303333333333	0.7575000000000001	77	702	4	24	15	16	0	2	16	0	0	3.39300230301072	
i 1	632.2327414965987	0.2525	71	1088	5	9	1	8	0	-1	8	0	0	3.0	
i 1	632.2383605442177	0.2525	75	702	3	5	12	2	0	-2	2	0	0	3.3506708850691216	
i 1	632.2399659863945	0.2525	75	702	3	5	14	2	0	-2	2	0	0	3.3506708850691216	
i 1	632.2439795918367	0.2525	74	702	6	2	13	2	0	-2	2	0	0	4.0	
i 1	632.2600340136055	0.2525	74	1088	6	1	5	16	0	2	16	0	0	2.39300230301072	
i 1	632.2632448979592	0.505	74	702	6	2	7	8	0	-2	8	0	0	4.0	
i 1	632.4923741496599	9.09	61	204	6	15	13	9	0	1	9	0	0	5.613193453150127	
i 1	632.5020068027211	0.7575000000000001	75	702	5	5	13	2	0	1	2	0	0	3.3506708850691216	
i 1	632.5036122448979	0.505	72	204	5	5	16	8	0	1	8	0	0	3.3506708850691216	
i 1	632.5060204081633	0.2525	77	702	6	1	4	17	0	1	17	0	0	2.39300230301072	
i 1	632.5076258503401	3.0300000000000002	75	702	5	5	1	2	0	1	2	0	0	3.3506708850691216	
i 1	632.509231292517	0.7575000000000001	74	702	5	1	10	16	0	1	16	0	0	2.39300230301072	
i 1	632.5116394557823	0.505	71	1088	5	9	12	2	0	-1	2	0	0	3.0	
i 1	632.5156530612245	9.09	61	702	1	27	16	6	0	252	6	307	0	12.926105448427196	
i 1	632.5180612244898	0.2525	71	702	2	20	1	0	0	-1	0	0	0	3.7602392055155063	
i 1	632.7415714285714	0.505	77	1088	5	1	6	17	0	1	17	0	0	2.39300230301072	
i 1	632.7504013605442	0.2525	71	702	4	20	7	1	0	-1	1	0	0	3.7602392055155063	
i 1	632.7608367346938	0.2525	71	204	4	20	15	0	0	-1	0	0	0	3.7602392055155063	
i 1	632.7640476190476	0.2525	68	204	1	24	11	1	0	-1	1	0	0	7.760239205515506	
i 1	632.7656530612245	1.01	71	1088	5	9	15	8	0	-1	8	0	0	3.0	
i 1	632.9891632653062	2.2725	77	702	6	1	2	17	0	1	17	0	0	2.39300230301072	
i 1	632.9955850340136	0.2525	74	702	6	2	6	2	0	-2	2	0	0	4.0	
i 1	632.9979931972789	1.2625	72	1088	4	5	8	2	0	-2	2	0	0	3.3506708850691216	
i 1	633.0012040816326	0.7575000000000001	71	702	2	20	16	1	0	0	1	0	0	3.7602392055155063	
i 1	633.0028095238096	0.2525	74	204	6	3	2	2	0	-2	2	0	0	4.0	
i 1	633.0180612244898	0.2525	71	1088	3	20	2	0	0	-1	0	0	0	3.7602392055155063	
i 1	633.2431768707482	1.2625	74	702	6	2	11	8	0	-2	8	0	0	4.0	
i 1	633.2487959183674	0.2525	75	702	3	5	13	2	0	-2	2	0	0	3.3506708850691216	
i 1	633.2512040816326	0.7575000000000001	77	702	6	1	4	16	0	2	16	0	0	2.39300230301072	
i 1	633.2544149659864	0.2525	77	204	5	24	5	16	0	2	16	0	0	3.39300230301072	
i 1	633.483544217687	0.505	75	702	3	5	14	2	0	-2	2	0	0	3.3506708850691216	
i 1	633.4899659863945	0.2525	71	1088	3	20	11	0	0	-1	0	0	0	3.7602392055155063	
i 1	633.5068231292518	0.2525	75	702	5	5	9	2	0	1	2	0	0	3.3506708850691216	
i 1	633.5108367346938	0.7575000000000001	74	702	5	1	2	16	0	1	16	0	0	2.39300230301072	
i 1	633.733544217687	0.505	71	1088	5	9	15	2	0	-1	2	0	0	3.0	
i 1	633.766455782313	0.2525	71	1088	3	20	15	0	0	-1	0	0	0	3.7602392055155063	
i 1	633.9819387755102	0.2525	74	1088	5	1	12	16	0	2	16	0	0	2.39300230301072	
i 1	634.0028095238096	2.2725	75	702	5	5	6	2	0	1	2	0	0	3.3506708850691216	
i 1	634.0052176870748	2.7775	71	702	2	20	6	1	0	0	1	0	0	3.7602392055155063	
i 1	634.2375578231292	0.505	77	204	5	24	3	16	0	2	16	0	0	3.39300230301072	
i 1	634.2471904761904	0.505	72	1088	4	5	5	2	0	1	2	0	0	3.3506708850691216	
i 1	634.2479931972789	0.2525	74	204	6	3	11	2	0	-2	2	0	0	4.0	
i 1	634.2560204081633	0.505	77	702	6	1	9	16	0	2	16	0	0	2.39300230301072	
i 1	634.2560204081633	0.505	74	702	4	3	11	8	0	-1	8	0	0	4.0	
i 1	634.4867551020408	0.2525	75	702	3	5	10	2	0	-2	2	0	0	3.3506708850691216	
i 1	634.5076258503401	0.505	71	1088	5	9	4	2	0	-1	2	0	0	3.0	
i 1	634.7375578231292	2.7775	72	204	5	5	7	8	0	1	8	0	0	3.3506708850691216	
i 1	634.7447823129252	0.505	77	1088	5	1	11	17	0	1	17	0	0	2.39300230301072	
i 1	634.7463877551021	1.01	74	702	6	2	7	8	0	-2	8	0	0	4.0	
i 1	634.7479931972789	0.2525	74	702	5	1	10	16	0	1	16	0	0	2.39300230301072	
i 1	634.7528095238096	0.505	75	204	5	5	11	2	0	-2	2	0	0	3.3506708850691216	
i 1	634.759231292517	0.505	74	204	6	3	8	2	0	-2	2	0	0	4.0	
i 1	634.9955850340136	0.505	77	702	6	1	13	16	0	2	16	0	0	2.39300230301072	
i 1	635.0052176870748	0.505	71	1088	3	20	8	0	0	-1	0	0	0	3.7602392055155063	
i 1	635.0060204081633	0.7575000000000001	74	702	6	2	15	2	0	-2	2	0	0	4.0	
i 1	635.2303333333333	2.2725	77	204	5	24	7	16	0	2	16	0	0	3.39300230301072	
i 1	635.2319387755102	0.2525	74	702	5	1	13	16	0	1	16	0	0	2.39300230301072	
i 1	635.2375578231292	0.2525	75	702	3	5	16	2	0	-2	2	0	0	3.3506708850691216	
i 1	635.2415714285714	0.7575000000000001	71	1088	5	9	16	2	0	-1	2	0	0	3.0	
i 1	635.4819387755102	2.02	71	702	2	24	2	1	0	0	1	0	0	7.760239205515506	
i 1	635.5012040816326	0.2525	74	1088	5	1	7	16	0	2	16	0	0	2.39300230301072	
i 1	635.5028095238096	0.2525	75	702	3	5	3	2	0	-2	2	0	0	3.3506708850691216	
i 1	635.5036122448979	0.2525	72	1088	4	5	12	2	0	1	2	0	0	3.3506708850691216	
i 1	635.5100340136055	6.0600000000000005	61	1088	4	16	16	6	0	0	6	0	0	6.40917316428503	
i 1	635.5108367346938	1.01	77	702	4	1	8	16	0	2	16	0	0	2.39300230301072	
i 1	635.5116394557823	1.2625	74	204	7	1	5	16	0	1	16	0	0	2.39300230301072	
i 1	635.733544217687	0.7575000000000001	75	702	3	5	1	2	0	-2	2	0	0	3.3506708850691216	
i 1	635.7375578231292	0.505	74	702	4	4	1	8	0	-1	8	0	0	4.0	
i 1	635.7584285714286	0.505	74	204	6	3	14	2	0	-2	2	0	0	4.0	
i 1	635.9915714285714	0.505	71	1088	5	9	5	8	0	-1	8	0	0	3.0	
i 1	636.2359523809524	0.2525	71	1088	5	9	12	2	0	-1	2	0	0	3.0	
i 1	636.2632448979592	0.505	74	702	4	3	9	8	0	-1	8	0	0	4.0	
i 1	636.2640476190476	0.2525	74	1088	5	1	5	16	0	2	16	0	0	2.39300230301072	
i 1	636.4859523809524	1.01	75	702	5	5	14	2	0	1	2	0	0	3.3506708850691216	
i 1	636.4899659863945	0.505	74	702	5	1	12	16	0	1	16	0	0	2.39300230301072	
i 1	636.4979931972789	0.505	74	702	6	2	11	8	0	-2	8	0	0	4.0	
i 1	636.5004013605442	1.01	77	702	5	1	3	17	0	1	17	0	0	2.39300230301072	
i 1	636.5132448979592	1.01	74	204	6	3	11	2	0	-2	2	0	0	4.0	
i 1	636.5140476190476	0.505	71	1088	3	20	9	0	0	-1	0	0	0	3.7602392055155063	
i 1	636.7431768707482	0.2525	71	1088	5	9	13	8	0	-1	8	0	0	3.0	
i 1	636.7455850340136	0.2525	71	1088	3	20	10	0	0	-1	0	0	0	3.7602392055155063	
i 1	636.7552176870748	0.7575000000000001	77	702	4	1	3	16	0	2	16	0	0	2.39300230301072	
i 1	636.9955850340136	0.2525	74	702	4	4	13	8	0	-1	8	0	0	4.0	
i 1	636.9971904761904	0.505	71	702	2	20	14	1	0	0	1	0	0	3.7602392055155063	
i 1	637.0124421768708	0.2525	74	702	4	3	6	8	0	-1	8	0	0	4.0	
i 1	637.0140476190476	0.2525	74	1088	5	1	8	16	0	2	16	0	0	2.39300230301072	
i 1	637.2319387755102	0.2525	72	1088	4	5	1	2	0	1	2	0	0	3.3506708850691216	
i 1	637.233544217687	0.2525	71	1088	5	9	16	2	0	-1	2	0	0	3.0	
i 1	637.2431768707482	0.2525	74	702	5	1	6	16	0	1	16	0	0	2.39300230301072	
i 1	637.2463877551021	0.2525	74	702	6	2	9	2	0	-2	2	0	0	4.0	
i 1	637.2584285714286	0.2525	71	1088	3	20	12	0	0	-1	0	0	0	3.7602392055155063	
i 1	637.2688639455782	0.2525	75	204	5	5	3	2	0	-2	2	0	0	3.3506708850691216	
i 1	638.4867551020408	3.0300000000000002	66	1088	4	16	11	6	0	0	6	0	0	6.40917316428503	
i 1	641.4803333333333	2.02	66	702	3	14	4	9	0	1	9	0	0	2.605531084707703	
i 1	641.4875578231292	2.02	61	204	6	15	10	9	0	1	9	0	0	4.321423406646625	
i 1	641.4899659863945	2.02	66	1088	4	16	4	6	0	0	6	0	0	5.117403117781529	
i 1	641.490768707483	2.02	61	204	4	7	1	9	0	0	9	0	0	1.3027655423538516	
i 1	641.5004013605442	2.02	61	702	5	12	1	9	0	1	9	0	0	5.117403117781529	
i 1	641.5020068027211	2.02	66	702	5	13	1	9	0	0	9	0	0	3.5254436955117217	
i 1	641.5020068027211	2.02	66	702	5	12	9	6	0	0	6	0	0	5.117403117781529	
i 1	641.5052176870748	2.02	61	702	5	14	4	9	0	0	9	0	0	5.913382828916431	
i 1	641.509231292517	2.02	66	204	6	15	12	9	0	0	9	0	0	4.321423406646625	
i 1	641.5132448979592	2.02	61	702	3	14	14	9	0	1	9	0	0	2.605531084707703	
i 1	641.516455782313	2.02	61	1088	4	16	12	6	0	0	6	0	0	5.117403117781529	
i 1	641.5180612244898	2.02	61	702	1	27	2	6	0	252	6	307	0	13.605280221395054	
t0 118
</CsScore>
</CsoundSynthesizer>

