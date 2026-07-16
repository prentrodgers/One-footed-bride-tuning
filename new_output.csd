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

f5000.0 0.0 256.0 -6.0 1.0 128.0 0.9991345 128.0 0.998269 
;Inst	Sta	Hold	Vel	Ton	Oct	Voi	Ste	En1	Gls	Ups	Ren	2gl	3gl	Vol
i 1	0.00037414965986394544	0.7575000000000001	71	903	3	20	13	0	5000	0	0	0	0	14.0	
i 1	0.0011224489795918363	0.2525	72	201	6	1	5	8	0	-2	8	0	0	9.0	
i 1	0.0011224489795918363	0.2525	74	903	4	9	16	8	5000	-2	8	0	0	13.0	
i 1	0.0018707482993197307	1.01	63	587	5	15	10	16	0	2	16	0	0	9.0	
i 1	0.0018707482993197307	0.2525	74	201	7	2	8	2	0	-2	2	0	0	14.0	
i 1	0.0018707482993197307	0.505	74	201	6	2	8	8	0	-2	8	0	0	14.0	
i 1	0.003367346938775509	8.585	63	587	5	15	6	16	0	1	16	0	0	9.0	
i 1	0.003367346938775509	0.2525	71	903	3	20	14	0	0	-1	0	0	0	14.0	
i 1	0.004115646258503403	1.01	63	201	4	12	14	1	0	2	1	0	0	10.0	
i 1	0.004115646258503403	0.2525	71	903	3	24	8	0	5000	-1	0	0	0	18.0	
i 1	0.0048639455782312924	0.2525	74	903	4	5	14	8	5000	-1	8	0	0	11.0	
i 1	0.005612244897959183	0.2525	75	903	6	1	12	2	5000	-2	2	0	0	9.0	
i 1	0.008605442176870749	1.01	61	903	4	16	13	16	5000	2	16	0	0	10.0	
i 1	0.00935374149659864	0.2525	71	201	7	5	1	2	0	-2	2	0	0	11.0	
i 1	0.010102040816326534	0.505	75	201	7	1	8	2	0	-2	2	0	0	9.0	
i 1	0.010850340136054421	0.2525	68	903	3	20	5	1	0	0	1	0	0	14.0	
i 1	0.013095238095238094	4.2925	63	201	6	13	5	16	0	1	16	0	0	8.0	
i 1	0.017585034013605443	5.3025	61	903	4	16	4	16	5000	1	16	0	0	10.0	
i 1	0.018333333333333333	0.505	74	201	6	5	13	8	0	-1	8	0	0	11.0	
i 1	0.2443877551020408	0.2525	71	201	3	24	16	0	0	-1	0	0	0	18.0	
i 1	0.25037414965986393	0.2525	74	903	4	9	12	2	5000	-2	2	0	0	13.0	
i 1	0.25112244897959185	0.2525	71	201	4	20	14	1	0	-1	1	0	0	14.0	
i 1	0.2556122448979592	0.2525	71	201	4	20	15	0	0	-1	0	0	0	14.0	
i 1	0.25785714285714284	0.2525	72	903	6	1	3	2	5000	-2	2	0	0	9.0	
i 1	0.2630952380952381	0.505	74	587	5	5	16	2	0	-2	2	0	0	11.0	
i 1	0.26683673469387753	0.2525	74	903	4	5	6	2	5000	-2	2	0	0	11.0	
i 1	0.4854081632653061	0.2525	71	201	4	3	16	2	0	-1	2	0	0	14.0	
i 1	0.4951360544217687	0.2525	72	201	6	1	13	2	0	-2	2	0	0	9.0	
i 1	0.7324149659863946	0.2525	71	201	4	4	16	2	0	-1	2	0	0	14.0	
i 1	0.7354081632653061	0.2525	75	587	4	24	2	2	0	-2	2	0	0	12.0	
i 1	0.7496258503401361	0.2525	68	201	3	24	15	1	0	0	1	0	0	18.0	
i 1	0.7518707482993198	0.2525	72	201	5	24	16	2	0	-2	2	0	0	12.0	
i 1	0.7668367346938776	0.2525	74	201	3	5	4	2	0	-1	2	0	0	11.0	
i 1	0.9913945578231292	0.505	75	903	6	1	2	2	5000	-2	2	0	0	9.0	
i 1	0.9921428571428571	0.2525	74	201	7	2	14	2	0	-2	2	0	0	14.0	
i 1	0.9928911564625851	0.2525	71	903	3	24	9	0	5000	-1	0	0	0	18.0	
i 1	0.9936394557823129	7.575	63	201	6	12	11	1	0	2	1	0	0	10.0	
i 1	1.0018707482993197	0.2525	68	903	3	20	15	0	0	0	0	0	0	14.0	
i 1	1.0033673469387756	7.575	63	587	5	15	4	16	0	2	16	0	0	9.0	
i 1	1.0056122448979592	0.505	72	201	6	1	13	8	0	-2	8	0	0	9.0	
i 1	1.007108843537415	4.2925	63	201	4	12	7	1	0	2	1	0	0	10.0	
i 1	1.007108843537415	0.2525	74	903	4	5	1	8	5000	-1	8	0	0	11.0	
i 1	1.0078571428571428	4.2925	61	903	4	16	4	16	5000	2	16	0	0	10.0	
i 1	1.0153401360544219	0.2525	71	903	3	20	14	0	5000	0	0	0	0	14.0	
i 1	1.2443877551020408	0.505	72	201	6	1	7	2	0	-2	2	0	0	9.0	
i 1	1.2443877551020408	0.2525	74	201	6	5	5	8	0	-1	8	0	0	11.0	
i 1	1.2451360544217687	0.7575000000000001	71	201	3	24	16	0	0	-1	0	0	0	18.0	
i 1	1.2518707482993197	0.2525	74	903	4	9	2	2	5000	-2	2	0	0	13.0	
i 1	1.2526190476190475	0.505	74	587	5	5	16	2	0	-2	2	0	0	11.0	
i 1	1.257108843537415	0.2525	72	903	6	1	16	2	5000	-2	2	0	0	9.0	
i 1	1.2593537414965987	0.505	75	587	6	1	4	8	0	1	8	0	0	9.0	
i 1	1.2653401360544219	0.2525	74	201	6	2	10	8	0	-2	8	0	0	14.0	
i 1	1.2675850340136054	0.2525	75	201	7	1	2	2	0	-2	2	0	0	9.0	
i 1	1.2675850340136054	0.7575000000000001	74	587	5	3	12	8	0	-2	8	0	0	14.0	
i 1	1.2683333333333333	0.7575000000000001	71	201	3	20	6	1	0	-1	1	0	0	14.0	
i 1	1.4839115646258503	0.505	71	201	4	3	16	2	0	-1	2	0	0	14.0	
i 1	1.513095238095238	0.2525	68	903	3	20	11	0	0	-1	0	0	0	14.0	
i 1	1.7451360544217687	0.2525	75	587	4	24	6	2	0	-2	2	0	0	12.0	
i 1	1.7451360544217687	0.2525	74	587	5	5	3	8	0	-2	8	0	0	11.0	
i 1	1.749625850340136	0.505	71	201	4	4	6	2	0	-1	2	0	0	14.0	
i 1	1.750374149659864	0.7575000000000001	74	903	4	9	16	8	5000	-2	8	0	0	13.0	
i 1	1.7511224489795918	0.2525	72	201	5	24	5	2	0	-2	2	0	0	12.0	
i 1	1.7556122448979592	1.5150000000000001	74	587	4	4	9	8	0	-1	8	0	0	14.0	
i 1	1.7623469387755102	0.505	68	201	3	24	12	1	0	0	1	0	0	18.0	
i 1	1.7653401360544219	0.7575000000000001	74	201	7	2	2	2	0	-2	2	0	0	14.0	
i 1	1.9846598639455781	0.505	74	201	6	2	12	8	0	-2	8	0	0	14.0	
i 1	1.9854081632653062	0.2525	75	903	6	1	16	2	5000	-2	2	0	0	9.0	
i 1	1.9876530612244898	0.2525	71	587	4	24	11	1	0	-1	1	0	0	18.0	
i 1	2.000374149659864	0.2525	71	201	7	5	11	2	0	-2	2	0	0	11.0	
i 1	2.001122448979592	0.2525	68	587	4	20	12	1	0	-1	1	0	0	14.0	
i 1	2.004863945578231	0.505	74	903	4	9	15	2	5000	-2	2	0	0	13.0	
i 1	2.005612244897959	0.2525	72	201	6	1	16	8	0	-2	8	0	0	9.0	
i 1	2.013095238095238	0.2525	71	903	3	24	7	0	5000	-1	0	0	0	18.0	
i 1	2.2324149659863948	0.505	71	201	4	3	3	2	0	-1	2	0	0	14.0	
i 1	2.2354081632653062	0.2525	71	201	3	24	7	0	0	-1	0	0	0	18.0	
i 1	2.242142857142857	0.7575000000000001	71	903	3	20	4	0	5000	0	0	0	0	14.0	
i 1	2.242891156462585	0.505	74	587	5	3	1	8	0	-2	8	0	0	14.0	
i 1	2.242891156462585	0.505	68	201	1	24	10	1	0	248	1	308	0	18.0	
i 1	2.2436394557823127	0.2525	74	903	4	5	13	2	5000	-2	2	0	0	11.0	
i 1	2.244387755102041	0.2525	75	201	7	1	14	2	0	-2	2	0	0	9.0	
i 1	2.249625850340136	0.2525	68	201	4	20	4	0	0	-1	0	0	0	14.0	
i 1	2.254863945578231	0.2525	68	201	4	20	10	0	0	0	0	0	0	14.0	
i 1	2.4891496598639455	0.2525	74	587	5	5	8	2	0	-2	2	0	0	11.0	
i 1	2.494387755102041	0.7575000000000001	74	587	5	5	4	8	0	-2	8	0	0	11.0	
i 1	2.4973809523809525	0.505	75	587	4	24	2	2	0	-2	2	0	0	12.0	
i 1	2.504863945578231	0.2525	74	201	4	5	16	2	0	-1	2	0	0	11.0	
i 1	2.507108843537415	0.2525	75	587	6	1	5	8	0	1	8	0	0	9.0	
i 1	2.508605442176871	0.2525	71	903	3	24	4	0	5000	-1	0	0	0	18.0	
i 1	2.5101020408163266	0.2525	68	903	3	20	5	1	0	0	1	0	0	14.0	
i 1	2.741394557823129	0.505	68	587	4	20	8	0	0	0	0	0	0	14.0	
i 1	2.7436394557823127	0.505	74	201	3	5	12	2	0	-1	2	0	0	11.0	
i 1	2.7458843537414968	1.2625	68	201	3	24	4	1	0	0	1	0	0	18.0	
i 1	2.7466326530612246	0.7575000000000001	74	903	4	5	11	2	5000	-2	2	0	0	11.0	
i 1	2.7518707482993197	0.505	71	201	4	4	4	2	0	-1	2	0	0	14.0	
i 1	2.9839115646258505	1.2625	71	903	3	24	9	0	5000	-1	0	0	0	18.0	
i 1	2.986904761904762	0.2525	71	201	7	5	3	2	0	-2	2	0	0	11.0	
i 1	2.9898979591836734	0.505	74	201	6	2	3	8	0	-2	8	0	0	14.0	
i 1	3.001122448979592	0.505	74	201	6	5	2	8	0	-1	8	0	0	11.0	
i 1	3.0026190476190475	0.2525	74	903	4	5	14	8	5000	-1	8	0	0	11.0	
i 1	3.005612244897959	0.505	74	903	4	9	3	8	5000	-2	8	0	0	13.0	
i 1	3.0063605442176873	0.2525	72	201	6	1	14	8	0	-2	8	0	0	9.0	
i 1	3.007857142857143	0.505	74	201	7	2	12	2	0	-2	2	0	0	14.0	
i 1	3.007857142857143	0.505	74	903	4	9	2	2	5000	-2	2	0	0	13.0	
i 1	3.2346598639455784	1.01	71	201	3	24	15	0	0	-1	0	0	0	18.0	
i 1	3.242891156462585	0.2525	72	903	6	1	12	2	5000	-2	2	0	0	9.0	
i 1	3.2473809523809525	0.505	71	201	4	3	9	2	0	-1	2	0	0	14.0	
i 1	3.248877551020408	0.505	74	587	5	3	4	8	0	-2	8	0	0	14.0	
i 1	3.248877551020408	0.2525	71	201	3	20	8	1	0	-1	1	0	0	14.0	
i 1	3.255612244897959	0.505	72	201	6	1	8	2	0	-2	2	0	0	9.0	
i 1	3.5041156462585032	0.2525	68	587	4	20	8	1	0	0	1	0	0	14.0	
i 1	3.5093537414965987	0.2525	74	201	4	5	7	2	0	-1	2	0	0	11.0	
i 1	3.5160884353741495	0.7575000000000001	71	201	7	5	8	2	0	-2	2	0	0	11.0	
i 1	3.5160884353741495	0.2525	74	587	5	5	6	2	0	-2	2	0	0	11.0	
i 1	3.736156462585034	0.505	71	903	3	20	2	1	0	-1	1	0	0	14.0	
i 1	3.736904761904762	0.2525	74	201	3	5	14	2	0	-1	2	0	0	11.0	
i 1	3.7398979591836734	0.2525	72	201	5	24	9	2	0	-2	2	0	0	12.0	
i 1	3.742142857142857	0.505	74	201	7	2	13	2	0	-2	2	0	0	14.0	
i 1	3.7466326530612246	0.2525	74	587	4	4	6	8	0	-1	8	0	0	14.0	
i 1	3.7473809523809525	0.2525	74	587	5	5	7	8	0	-2	8	0	0	11.0	
i 1	3.7481292517006803	0.2525	71	201	4	4	12	2	0	-1	2	0	0	14.0	
i 1	3.754863945578231	0.505	72	201	6	1	9	8	0	-2	8	0	0	9.0	
i 1	3.758605442176871	0.505	71	201	3	20	16	0	0	-1	0	0	0	14.0	
i 1	3.7653401360544216	0.2525	68	201	3	24	9	1	0	0	1	0	0	18.0	
i 1	3.9898979591836734	0.2525	74	903	4	9	11	8	5000	-2	8	0	0	13.0	
i 1	3.994387755102041	0.2525	71	201	4	3	9	2	0	-1	2	0	0	14.0	
i 1	4.005612244897959	0.2525	74	903	4	5	13	8	5000	-1	8	0	0	11.0	
i 1	4.232414965986394	0.7575000000000001	74	587	5	5	7	8	0	-2	8	0	0	11.0	
i 1	4.232414965986394	0.2525	71	903	3	24	7	0	5000	-1	0	0	0	7.0	
i 1	4.233163265306122	0.2525	74	903	4	9	16	2	5000	-2	2	0	0	13.0	
i 1	4.237653061224489	0.505	74	903	4	5	5	2	5000	-2	2	0	0	11.0	
i 1	4.238401360544218	0.2525	75	201	6	1	8	2	0	-2	2	0	0	9.0	
i 1	4.246632653061225	0.505	74	201	7	5	6	8	0	-1	8	0	0	11.0	
i 1	4.246632653061225	0.7575000000000001	71	201	3	24	11	0	0	-1	0	0	0	7.0	
i 1	4.253367346938775	0.7575000000000001	68	201	3	24	8	1	0	0	1	0	0	7.0	
i 1	4.259353741496598	0.7575000000000001	71	201	3	20	3	0	0	-1	0	0	0	3.0	
i 1	4.260850340136054	1.2625	68	201	3	24	9	1	0	0	1	0	0	7.0	
i 1	4.26608843537415	0.2525	71	903	3	20	8	1	0	-1	1	0	0	3.0	
i 1	4.489149659863946	0.2525	74	587	5	5	10	2	0	-2	2	0	0	11.0	
i 1	4.492142857142857	0.2525	74	587	5	3	9	8	0	-2	8	0	0	14.0	
i 1	4.495884353741497	0.505	71	201	4	4	2	2	0	-1	2	0	0	14.0	
i 1	4.499625850340136	0.2525	74	201	4	5	5	2	0	-1	2	0	0	11.0	
i 1	4.507108843537415	0.2525	75	587	6	1	2	8	0	1	8	0	0	9.0	
i 1	4.507108843537415	0.2525	75	903	6	1	11	2	5000	-2	2	0	0	9.0	
i 1	4.513843537414966	0.505	74	201	3	5	6	2	0	-1	2	0	0	11.0	
i 1	4.74139455782313	0.2525	75	587	4	24	10	2	0	-2	2	0	0	12.0	
i 1	4.74812925170068	0.505	71	903	3	24	11	0	5000	-1	0	0	0	7.0	
i 1	4.765340136054422	1.01	75	201	6	1	12	2	0	-2	2	0	0	9.0	
i 1	4.982414965986394	0.2525	71	587	4	24	9	0	0	0	0	0	0	7.0	
i 1	4.984659863945578	0.2525	71	587	4	20	10	1	0	-1	1	0	0	3.0	
i 1	4.988401360544218	0.505	74	903	4	5	10	8	5000	-1	8	0	0	11.0	
i 1	4.993639455782313	0.2525	74	201	7	2	15	2	0	-2	2	0	0	14.0	
i 1	5.0026190476190475	0.2525	75	903	6	1	16	2	5000	-2	2	0	0	9.0	
i 1	5.004115646258503	0.505	74	201	7	2	2	8	0	-2	8	0	0	14.0	
i 1	5.004115646258503	0.505	71	201	7	5	14	2	0	-2	2	0	0	11.0	
i 1	5.006360544217687	0.2525	72	201	6	1	9	8	0	-2	8	0	0	9.0	
i 1	5.016836734693878	0.7575000000000001	74	201	7	5	13	8	0	-1	8	0	0	11.0	
i 1	5.232414965986394	11.8675	61	903	4	16	8	16	5000	2	16	0	0	10.0	
i 1	5.24139455782313	0.2525	71	201	3	24	5	1	0	0	1	0	0	7.0	
i 1	5.244387755102041	0.2525	74	903	4	9	7	2	5000	-2	2	0	0	13.0	
i 1	5.244387755102041	0.7575000000000001	68	201	3	20	6	1	0	0	1	0	0	3.0	
i 1	5.248877551020408	4.2925	61	903	4	16	5	16	5000	1	16	0	0	10.0	
i 1	5.25187074829932	1.5150000000000001	71	201	3	24	15	0	0	-1	0	0	0	7.0	
i 1	5.254863945578231	0.505	74	903	4	5	11	2	5000	-2	2	0	0	11.0	
i 1	5.257108843537415	3.2825	63	201	6	12	12	1	0	2	1	0	0	10.0	
i 1	5.260850340136054	0.505	72	903	6	1	3	2	5000	-2	2	0	0	9.0	
i 1	5.265340136054422	0.7575000000000001	74	587	5	5	9	2	0	-2	2	0	0	11.0	
i 1	5.265340136054422	0.7575000000000001	74	201	4	5	5	2	0	-1	2	0	0	11.0	
i 1	5.485408163265306	0.2525	71	903	3	24	14	0	5000	-1	0	0	0	7.0	
i 1	5.486156462585034	0.505	75	587	4	24	16	2	0	-2	2	0	0	12.0	
i 1	5.495136054421769	0.2525	74	587	5	3	16	8	0	-2	8	0	0	14.0	
i 1	5.496632653061225	0.505	74	587	5	5	2	8	0	-2	8	0	0	11.0	
i 1	5.49812925170068	0.505	72	201	5	24	3	2	0	-2	2	0	0	12.0	
i 1	5.505612244897959	0.2525	75	587	6	1	10	8	0	1	8	0	0	9.0	
i 1	5.509353741496598	0.505	74	201	4	5	9	2	0	-1	2	0	0	11.0	
i 1	5.510850340136054	0.2525	72	201	6	1	9	2	0	-2	2	0	0	9.0	
i 1	5.515340136054422	0.2525	71	201	4	3	8	2	0	-1	2	0	0	14.0	
i 1	5.743639455782313	0.505	74	587	4	4	12	8	0	-1	8	0	0	14.0	
i 1	5.760850340136054	0.7575000000000001	71	201	7	5	12	2	0	-2	2	0	0	11.0	
i 1	5.763843537414966	0.505	71	201	4	4	15	2	0	-1	2	0	0	14.0	
i 1	5.766836734693878	0.7575000000000001	74	903	4	5	11	8	5000	-1	8	0	0	11.0	
i 1	5.984659863945578	1.01	74	587	5	3	3	8	0	-2	8	0	0	14.0	
i 1	5.9869047619047615	0.2525	75	903	6	1	15	2	5000	-2	2	0	0	9.0	
i 1	5.992891156462585	0.7575000000000001	74	903	4	9	8	2	5000	-2	2	0	0	13.0	
i 1	5.99812925170068	0.2525	68	587	4	20	11	1	0	-1	1	0	0	3.0	
i 1	6.000374149659864	0.2525	68	587	4	24	14	1	0	0	1	0	0	7.0	
i 1	6.0026190476190475	0.7575000000000001	74	201	7	2	9	8	0	-2	8	0	0	14.0	
i 1	6.004115646258503	0.2525	72	201	6	1	4	8	0	-2	8	0	0	9.0	
i 1	6.005612244897959	0.2525	74	201	7	2	9	2	0	-2	2	0	0	14.0	
i 1	6.015340136054422	0.2525	74	903	4	9	10	8	5000	-2	8	0	0	13.0	
i 1	6.015340136054422	1.2625	68	201	3	24	8	1	0	0	1	0	0	7.0	
i 1	6.238401360544218	0.7575000000000001	74	587	5	5	7	2	0	-2	2	0	0	11.0	
i 1	6.239149659863946	0.2525	74	201	7	5	3	8	0	-1	8	0	0	11.0	
i 1	6.251122448979592	0.505	72	903	6	1	10	2	5000	-2	2	0	0	9.0	
i 1	6.255612244897959	0.2525	74	903	4	5	2	2	5000	-2	2	0	0	11.0	
i 1	6.256360544217687	0.505	68	201	3	24	14	1	0	-1	1	0	0	7.0	
i 1	6.257857142857143	0.505	71	201	3	20	1	0	0	0	0	0	0	3.0	
i 1	6.260850340136054	0.7575000000000001	75	587	6	1	14	8	0	1	8	0	0	9.0	
i 1	6.26608843537415	0.505	75	201	6	1	15	2	0	-2	2	0	0	9.0	
i 1	6.266836734693878	0.7575000000000001	74	201	4	5	3	2	0	-1	2	0	0	11.0	
i 1	6.48391156462585	0.505	72	201	5	24	5	2	0	-2	2	0	0	12.0	
i 1	6.494387755102041	0.505	71	201	4	4	12	2	0	-1	2	0	0	14.0	
i 1	6.495136054421769	0.505	72	201	6	1	9	2	0	-2	2	0	0	9.0	
i 1	6.499625850340136	1.7675	75	587	4	24	6	2	0	-2	2	0	0	12.0	
i 1	6.504115646258503	1.2625	71	903	3	20	16	0	5000	0	0	0	0	3.0	
i 1	6.506360544217687	0.7575000000000001	71	903	3	24	3	0	5000	-1	0	0	0	7.0	
i 1	6.507857142857143	0.505	74	587	4	4	2	8	0	-1	8	0	0	14.0	
i 1	6.510102040816326	0.2525	71	201	4	3	15	2	0	-1	2	0	0	14.0	
i 1	6.510102040816326	0.2525	71	903	3	20	7	0	0	-1	0	0	0	3.0	
i 1	6.743639455782313	0.505	68	201	4	20	13	1	0	0	1	0	0	3.0	
i 1	6.744387755102041	0.2525	74	587	5	5	9	8	0	-2	8	0	0	11.0	
i 1	6.751122448979592	0.2525	71	201	4	20	1	0	0	-1	0	0	0	3.0	
i 1	6.754115646258503	0.7575000000000001	75	903	6	1	10	2	5000	-2	2	0	0	9.0	
i 1	6.755612244897959	0.7575000000000001	74	903	4	5	16	8	5000	-1	8	0	0	11.0	
i 1	6.760102040816326	0.2525	74	201	4	5	12	2	0	-1	2	0	0	11.0	
i 1	6.761598639455782	0.7575000000000001	72	201	6	1	3	8	0	-2	8	0	0	9.0	
i 1	6.761598639455782	0.505	71	587	4	20	3	1	0	0	1	0	0	3.0	
i 1	6.766836734693878	0.505	68	587	4	24	6	1	0	-1	1	0	0	7.0	
i 1	6.767585034013606	0.7575000000000001	71	201	7	5	15	2	0	-2	2	0	0	11.0	
i 1	7.00187074829932	0.505	71	201	3	24	2	0	0	-1	0	0	0	7.0	
i 1	7.010102040816326	0.505	74	201	7	2	15	2	0	-2	2	0	0	14.0	
i 1	7.011598639455782	0.505	74	903	4	9	14	8	5000	-2	8	0	0	13.0	
i 1	7.013843537414966	0.7575000000000001	74	903	4	9	12	2	5000	-2	2	0	0	13.0	
i 1	7.2316666666666665	0.7575000000000001	74	587	5	5	7	8	0	-2	8	0	0	11.0	
i 1	7.23391156462585	0.505	71	201	4	3	2	2	0	-1	2	0	0	14.0	
i 1	7.235408163265306	0.2525	71	201	3	20	5	0	0	-1	0	0	0	3.0	
i 1	7.236156462585034	1.2625	74	587	4	4	4	8	0	-1	8	0	0	14.0	
i 1	7.2369047619047615	0.7575000000000001	74	587	5	3	15	8	0	-2	8	0	0	14.0	
i 1	7.24812925170068	0.7575000000000001	74	587	5	5	15	2	0	-2	2	0	0	11.0	
i 1	7.251122448979592	0.505	74	201	7	2	5	8	0	-2	8	0	0	14.0	
i 1	7.254115646258503	0.7575000000000001	74	201	4	5	10	2	0	-1	2	0	0	11.0	
i 1	7.254863945578231	0.505	75	201	6	1	15	2	0	-2	2	0	0	9.0	
i 1	7.255612244897959	0.505	72	201	6	1	8	2	0	-2	2	0	0	9.0	
i 1	7.257857142857143	0.505	74	903	4	5	14	2	5000	-2	2	0	0	11.0	
i 1	7.259353741496598	0.505	75	587	6	1	7	8	0	1	8	0	0	9.0	
i 1	7.260102040816326	0.505	74	201	7	5	2	8	0	-1	8	0	0	11.0	
i 1	7.262346938775511	0.505	72	903	6	1	12	2	5000	-2	2	0	0	9.0	
i 1	7.484659863945578	0.505	71	201	3	24	3	1	0	0	1	0	0	7.0	
i 1	7.488401360544218	0.7575000000000001	71	201	4	4	9	2	0	-1	2	0	0	14.0	
i 1	7.4973809523809525	0.2525	71	903	3	20	11	0	0	0	0	0	0	3.0	
i 1	7.498877551020408	0.7575000000000001	72	201	5	24	14	2	0	-2	2	0	0	12.0	
i 1	7.507108843537415	0.505	74	201	4	5	8	2	0	-1	2	0	0	11.0	
i 1	7.516836734693878	0.505	68	201	3	24	9	1	0	0	1	0	0	7.0	
i 1	7.734659863945578	0.505	71	201	7	5	1	2	0	-2	2	0	0	11.0	
i 1	7.742891156462585	0.2525	71	201	3	24	12	0	0	-1	0	0	0	7.0	
i 1	7.757857142857143	0.505	72	201	6	1	11	8	0	-2	8	0	0	9.0	
i 1	7.7683333333333335	0.505	74	903	4	5	16	8	5000	-1	8	0	0	11.0	
i 1	7.9869047619047615	1.01	74	903	4	9	7	8	5000	-2	8	0	0	13.0	
i 1	7.987653061224489	0.505	74	903	4	9	16	2	5000	-2	2	0	0	13.0	
i 1	7.987653061224489	0.2525	71	903	3	24	4	0	5000	-1	0	0	0	7.0	
i 1	7.989149659863946	0.2525	75	903	6	1	4	2	5000	-2	2	0	0	9.0	
i 1	7.99139455782313	0.505	74	201	7	2	16	8	0	-2	8	0	0	14.0	
i 1	7.992142857142857	0.505	75	201	6	1	10	2	0	-2	2	0	0	9.0	
i 1	7.995136054421769	0.505	74	201	7	2	7	2	0	-2	2	0	0	14.0	
i 1	8.000374149659864	0.2525	71	903	3	20	13	0	0	0	0	0	0	3.0	
i 1	8.003367346938775	0.2525	71	903	3	20	15	0	0	-1	0	0	0	3.0	
i 1	8.01234693877551	0.505	72	903	6	1	7	2	5000	-2	2	0	0	9.0	
i 1	8.013095238095238	0.505	71	201	1	24	13	0	0	252	0	307	0	7.0	
i 1	8.236156462585035	0.2525	71	201	3	24	5	1	0	0	1	0	0	7.0	
i 1	8.24812925170068	0.2525	74	201	7	5	7	8	0	-1	8	0	0	11.0	
i 1	8.251122448979592	0.2525	74	903	4	5	12	2	5000	-2	2	0	0	11.0	
i 1	8.483163265306123	0.7575000000000001	68	405	3	24	10	1	0	0	1	0	0	7.0	
i 1	8.488401360544218	0.505	71	696	4	4	7	2	0	-1	2	0	0	14.0	
i 1	8.492891156462585	0.7575000000000001	71	903	3	24	2	0	5000	-1	0	0	0	7.0	
i 1	8.497380952380952	0.505	75	903	6	1	3	2	5000	-2	2	0	0	9.0	
i 1	8.497380952380952	1.01	61	405	5	12	11	16	0	2	16	0	0	10.0	
i 1	8.49812925170068	5.3025	63	405	5	12	5	1	0	1	1	0	0	10.0	
i 1	8.500374149659864	0.7575000000000001	71	201	7	5	1	2	0	-2	2	0	0	11.0	
i 1	8.503367346938775	0.7575000000000001	72	201	6	1	13	8	0	-2	8	0	0	9.0	
i 1	8.504863945578231	4.2925	63	696	5	15	8	16	0	1	16	0	0	9.0	
i 1	8.505612244897959	0.2525	68	696	4	20	15	0	0	0	0	0	0	3.0	
i 1	8.507857142857143	0.505	74	201	7	2	2	2	0	-2	2	0	0	14.0	
i 1	8.51234693877551	0.505	75	696	4	24	4	2	0	1	2	0	0	12.0	
i 1	8.513095238095238	0.505	74	903	4	5	12	8	5000	-1	8	0	0	11.0	
i 1	8.518333333333333	0.505	71	696	5	5	2	8	0	-2	8	0	0	11.0	
i 1	8.733163265306123	0.7575000000000001	74	201	7	2	15	8	0	-2	8	0	0	14.0	
i 1	8.738401360544218	0.505	74	201	7	5	15	8	0	-1	8	0	0	11.0	
i 1	8.746632653061225	1.7675	75	201	6	1	7	2	0	-2	2	0	0	9.0	
i 1	8.746632653061225	0.7575000000000001	71	405	4	3	12	2	0	-1	2	0	0	14.0	
i 1	8.750374149659864	0.505	72	903	6	1	7	2	5000	-2	2	0	0	9.0	
i 1	8.75187074829932	0.7575000000000001	72	405	6	1	15	2	0	1	2	0	0	9.0	
i 1	8.755612244897959	0.2525	68	405	3	24	9	1	0	-1	1	0	0	7.0	
i 1	8.759353741496598	0.505	74	405	4	5	10	8	0	-1	8	0	0	11.0	
i 1	8.763843537414965	0.505	74	903	4	5	2	2	5000	-2	2	0	0	11.0	
i 1	8.766088435374149	0.2525	74	903	4	9	9	2	5000	-2	2	0	0	13.0	
i 1	8.982414965986395	0.2525	71	696	4	20	1	0	0	-1	0	0	0	3.0	
i 1	8.983163265306123	0.7575000000000001	72	405	4	24	14	2	0	-2	2	0	0	12.0	
i 1	8.989149659863946	0.2525	71	696	4	24	14	0	0	-1	0	0	0	7.0	
i 1	9.000374149659864	0.7575000000000001	74	405	4	5	6	8	0	-2	8	0	0	11.0	
i 1	9.006360544217687	0.7575000000000001	71	696	6	5	15	2	0	-1	2	0	0	11.0	
i 1	9.015340136054421	0.7575000000000001	75	696	5	1	12	2	0	1	2	0	0	9.0	
i 1	9.236156462585035	0.2525	71	405	4	4	9	2	0	-2	2	0	0	14.0	
i 1	9.240646258503402	0.505	71	903	3	20	3	0	5000	0	0	0	0	3.0	
i 1	9.245884353741497	0.7575000000000001	71	696	4	4	4	2	0	-1	2	0	0	14.0	
i 1	9.251122448979592	0.7575000000000001	75	903	6	1	6	2	5000	-2	2	0	0	9.0	
i 1	9.251122448979592	0.7575000000000001	71	696	5	5	13	8	0	-2	8	0	0	11.0	
i 1	9.261598639455782	0.2525	74	696	5	3	2	2	0	-1	2	0	0	14.0	
i 1	9.266836734693877	0.7575000000000001	75	696	4	24	1	2	0	1	2	0	0	12.0	
i 1	9.268333333333333	0.7575000000000001	74	903	4	9	11	8	5000	-2	8	0	0	13.0	
i 1	9.483911564625851	0.505	71	903	3	24	16	0	5000	-1	0	0	0	7.0	
i 1	9.485408163265307	0.2525	68	405	3	24	10	1	0	-1	1	0	0	7.0	
i 1	9.49139455782313	0.7575000000000001	74	903	4	5	16	2	5000	-2	2	0	0	11.0	
i 1	9.492142857142857	0.7575000000000001	71	201	7	5	2	2	0	-2	2	0	0	11.0	
i 1	9.493639455782313	1.01	74	201	7	5	14	8	0	-1	8	0	0	11.0	
i 1	9.496632653061225	0.2525	68	405	3	24	7	1	0	-1	1	0	0	7.0	
i 1	9.497380952380952	0.505	72	201	6	1	12	8	0	-2	8	0	0	9.0	
i 1	9.49812925170068	0.505	72	903	6	1	1	2	5000	-2	2	0	0	9.0	
i 1	9.500374149659864	0.505	74	903	4	5	3	8	5000	-1	8	0	0	11.0	
i 1	9.504863945578231	4.7975	68	405	3	24	16	1	0	0	1	0	0	7.0	
i 1	9.506360544217687	0.2525	68	405	3	20	7	0	0	-1	0	0	0	3.0	
i 1	9.509353741496598	7.575	61	903	4	16	3	16	5000	1	16	0	0	10.0	
i 1	9.514591836734693	4.2925	61	405	5	12	11	16	0	2	16	0	0	10.0	
i 1	9.516836734693877	0.2525	68	903	3	20	16	1	0	0	1	0	0	3.0	
i 1	9.734659863945579	0.505	71	405	4	3	14	2	0	-1	2	0	0	14.0	
i 1	9.740646258503402	0.505	74	903	4	9	5	2	5000	-2	2	0	0	13.0	
i 1	9.748877551020408	0.505	71	696	4	24	5	1	0	-1	1	0	0	7.0	
i 1	9.753367346938775	0.7575000000000001	74	405	4	5	10	8	0	-1	8	0	0	11.0	
i 1	9.755612244897959	0.505	74	201	7	2	16	8	0	-2	8	0	0	14.0	
i 1	9.756360544217687	0.505	74	201	7	2	10	2	0	-2	2	0	0	14.0	
i 1	9.759353741496598	0.505	71	696	4	20	13	1	0	0	1	0	0	3.0	
i 1	9.760102040816326	0.7575000000000001	72	405	6	1	2	2	0	1	2	0	0	9.0	
i 1	10.003367346938775	0.505	71	405	4	4	4	2	0	-2	2	0	0	14.0	
i 1	10.009353741496598	0.7575000000000001	74	405	4	5	13	8	0	-2	8	0	0	11.0	
i 1	10.013095238095238	0.7575000000000001	74	696	5	3	3	2	0	-1	2	0	0	14.0	
i 1	10.018333333333333	1.5150000000000001	71	696	6	5	16	2	0	-1	2	0	0	11.0	
i 1	10.233163265306123	0.505	75	903	6	1	8	2	5000	-2	2	0	0	9.0	
i 1	10.236904761904762	1.7675	68	405	3	24	3	1	0	-1	1	0	0	7.0	
i 1	10.239149659863946	1.5150000000000001	68	405	3	20	13	0	0	0	0	0	0	3.0	
i 1	10.242142857142857	1.5150000000000001	68	903	3	20	5	0	0	-1	0	0	0	3.0	
i 1	10.242891156462585	6.8175	71	903	3	24	5	0	5000	-1	0	0	0	7.0	
i 1	10.244387755102041	0.7575000000000001	74	903	4	5	11	8	5000	-1	8	0	0	11.0	
i 1	10.25187074829932	1.5150000000000001	71	405	3	24	16	1	0	-1	1	0	0	7.0	
i 1	10.257857142857143	0.505	75	696	4	24	12	2	0	1	2	0	0	12.0	
i 1	10.265340136054421	0.7575000000000001	71	696	5	5	11	8	0	-2	8	0	0	11.0	
i 1	10.266088435374149	0.505	72	405	4	24	16	2	0	-2	2	0	0	12.0	
i 1	10.268333333333333	0.505	75	696	5	1	14	2	0	1	2	0	0	9.0	
i 1	10.495136054421769	0.7575000000000001	74	903	4	5	16	2	5000	-2	2	0	0	11.0	
i 1	10.499625850340136	0.7575000000000001	72	903	6	1	16	2	5000	-2	2	0	0	9.0	
i 1	10.501122448979592	0.2525	71	696	4	4	14	2	0	-1	2	0	0	14.0	
i 1	10.509353741496598	0.7575000000000001	72	201	6	1	12	8	0	-2	8	0	0	9.0	
i 1	10.510850340136054	0.7575000000000001	71	201	7	5	15	2	0	-2	2	0	0	11.0	
i 1	10.516088435374149	0.2525	74	903	4	9	5	8	5000	-2	8	0	0	13.0	
i 1	10.731666666666667	0.7575000000000001	74	201	7	2	11	8	0	-2	8	0	0	14.0	
i 1	10.735408163265307	0.7575000000000001	75	201	6	1	14	2	0	-2	2	0	0	9.0	
i 1	10.736904761904762	1.7675	74	201	7	5	11	8	0	-1	8	0	0	11.0	
i 1	10.739149659863946	0.505	74	903	4	9	8	2	5000	-2	2	0	0	13.0	
i 1	10.744387755102041	0.505	74	201	7	2	15	2	0	-2	2	0	0	14.0	
i 1	10.768333333333333	0.7575000000000001	74	405	4	5	15	8	0	-1	8	0	0	11.0	
i 1	10.983163265306123	0.7575000000000001	75	696	5	1	5	2	0	1	2	0	0	9.0	
i 1	10.990646258503402	0.505	71	405	4	3	13	2	0	-1	2	0	0	14.0	
i 1	10.995136054421769	0.7575000000000001	72	405	4	24	3	2	0	-2	2	0	0	12.0	
i 1	11.003367346938775	0.505	74	405	4	5	7	8	0	-2	8	0	0	11.0	
i 1	11.004115646258503	0.505	72	405	6	1	1	2	0	1	2	0	0	9.0	
i 1	11.009353741496598	0.505	71	405	4	4	16	2	0	-2	2	0	0	14.0	
i 1	11.016088435374149	0.7575000000000001	74	696	5	3	4	2	0	-1	2	0	0	14.0	
i 1	11.231666666666667	1.5150000000000001	71	696	4	4	8	2	0	-1	2	0	0	14.0	
i 1	11.245136054421769	0.7575000000000001	71	696	5	5	6	8	0	-2	8	0	0	11.0	
i 1	11.24812925170068	0.7575000000000001	75	696	4	24	5	2	0	1	2	0	0	12.0	
i 1	11.250374149659864	1.5150000000000001	75	903	6	1	7	2	5000	-2	2	0	0	9.0	
i 1	11.25860544217687	0.7575000000000001	74	903	4	5	15	8	5000	-1	8	0	0	11.0	
i 1	11.26234693877551	0.7575000000000001	74	903	4	9	11	8	5000	-2	8	0	0	13.0	
i 1	11.49139455782313	0.505	72	903	6	1	3	2	5000	-2	2	0	0	9.0	
i 1	11.500374149659864	0.7575000000000001	71	903	3	20	6	0	5000	0	0	0	0	3.0	
i 1	11.507108843537415	0.505	72	201	6	1	14	8	0	-2	8	0	0	9.0	
i 1	11.734659863945579	0.505	74	201	7	2	16	2	0	-2	2	0	0	14.0	
i 1	11.739149659863946	0.7575000000000001	72	405	6	1	5	2	0	1	2	0	0	9.0	
i 1	11.754863945578231	0.2525	71	696	4	24	9	0	0	0	0	0	0	7.0	
i 1	11.757108843537415	0.7575000000000001	71	405	4	3	14	2	0	-1	2	0	0	14.0	
i 1	11.757857142857143	0.7575000000000001	74	405	4	5	14	8	0	-1	8	0	0	11.0	
i 1	11.760102040816326	0.7575000000000001	75	201	6	1	2	2	0	-2	2	0	0	9.0	
i 1	11.760102040816326	0.2525	74	903	4	5	3	2	5000	-2	2	0	0	11.0	
i 1	11.760102040816326	0.2525	68	696	4	20	7	0	0	0	0	0	0	3.0	
i 1	11.761598639455782	0.2525	71	201	4	20	4	0	0	0	0	0	0	3.0	
i 1	11.76234693877551	0.505	74	903	4	9	2	2	5000	-2	2	0	0	13.0	
i 1	11.763843537414965	0.2525	71	201	7	5	3	2	0	-2	2	0	0	11.0	
i 1	11.767585034013605	0.7575000000000001	74	201	7	2	7	8	0	-2	8	0	0	14.0	
i 1	11.985408163265307	0.505	74	696	5	3	13	2	0	-1	2	0	0	14.0	
i 1	11.989897959183674	0.505	71	405	4	4	1	2	0	-2	2	0	0	14.0	
i 1	11.998877551020408	0.505	71	405	3	24	5	1	0	-1	1	0	0	7.0	
i 1	12.00187074829932	0.505	68	903	3	20	10	0	0	0	0	0	0	3.0	
i 1	12.240646258503402	0.505	75	696	4	24	8	2	0	1	2	0	0	12.0	
i 1	12.247380952380952	0.505	75	696	5	1	6	2	0	1	2	0	0	9.0	
i 1	12.252619047619048	0.505	74	903	4	9	3	8	5000	-2	8	0	0	13.0	
i 1	12.253367346938775	0.505	71	696	6	5	7	2	0	-1	2	0	0	11.0	
i 1	12.254115646258503	0.505	74	903	4	5	11	8	5000	-1	8	0	0	11.0	
i 1	12.25860544217687	0.505	72	405	4	24	7	2	0	-2	2	0	0	12.0	
i 1	12.263095238095238	0.505	71	696	5	5	13	8	0	-2	8	0	0	11.0	
i 1	12.264591836734693	0.505	74	405	4	5	5	8	0	-2	8	0	0	11.0	
i 1	12.485408163265307	0.7575000000000001	74	903	4	5	1	2	5000	-2	2	0	0	11.0	
i 1	12.485408163265307	0.2525	68	201	4	20	11	1	0	0	1	0	0	3.0	
i 1	12.495136054421769	0.2525	68	696	4	20	11	1	0	-1	1	0	0	3.0	
i 1	12.498877551020408	0.7575000000000001	72	903	6	1	12	2	5000	-2	2	0	0	9.0	
i 1	12.498877551020408	0.2525	68	201	4	20	13	1	0	-1	1	0	0	3.0	
i 1	12.500374149659864	1.5150000000000001	74	201	7	2	3	2	0	-2	2	0	0	14.0	
i 1	12.504863945578231	0.2525	71	201	7	5	7	2	0	-2	2	0	0	11.0	
i 1	12.507108843537415	1.2625	71	903	3	20	15	0	5000	0	0	0	0	3.0	
i 1	12.509353741496598	1.7675	72	201	6	1	4	8	0	-2	8	0	0	9.0	
i 1	12.509353741496598	0.7575000000000001	68	405	3	24	2	1	0	-1	1	0	0	7.0	
i 1	12.51234693877551	0.2525	68	696	4	24	15	1	0	-1	1	0	0	7.0	
i 1	12.732414965986395	0.7575000000000001	74	405	4	5	5	8	0	-1	8	0	0	11.0	
i 1	12.736904761904762	1.5150000000000001	71	201	7	5	2	2	0	-2	2	0	0	11.0	
i 1	12.736904761904762	0.505	71	405	3	20	3	1	0	0	1	0	0	3.0	
i 1	12.739149659863946	0.505	74	903	4	9	14	2	5000	-2	2	0	0	13.0	
i 1	12.752619047619048	2.525	71	903	3	20	6	0	0	-1	0	0	0	3.0	
i 1	12.755612244897959	0.2525	75	696	4	24	8	2	0	1	2	0	0	12.0	
i 1	12.757108843537415	1.01	71	903	3	20	15	0	0	0	0	0	0	3.0	
i 1	12.986156462585035	0.505	71	405	4	3	5	2	0	-1	2	0	0	14.0	
i 1	12.988401360544218	0.7575000000000001	72	405	4	24	3	2	0	-2	2	0	0	12.0	
i 1	12.989897959183674	0.7575000000000001	71	696	6	5	8	2	0	-1	2	0	0	11.0	
i 1	12.990646258503402	0.7575000000000001	74	696	5	3	6	2	0	-1	2	0	0	14.0	
i 1	12.99139455782313	0.505	74	201	7	5	15	8	0	-1	8	0	0	11.0	
i 1	12.99812925170068	0.7575000000000001	71	405	4	4	14	2	0	-2	2	0	0	14.0	
i 1	12.999625850340136	0.505	74	201	7	2	7	8	0	-2	8	0	0	14.0	
i 1	13.001122448979592	0.7575000000000001	74	405	4	5	11	8	0	-2	8	0	0	11.0	
i 1	13.002619047619048	0.505	75	201	6	1	10	2	0	-2	2	0	0	9.0	
i 1	13.006360544217687	0.505	72	405	6	1	1	2	0	1	2	0	0	9.0	
i 1	13.011598639455782	0.7575000000000001	75	696	5	1	13	2	0	1	2	0	0	9.0	
i 1	13.013843537414965	1.2625	71	405	3	24	2	1	0	-1	1	0	0	7.0	
i 1	13.232414965986395	0.7575000000000001	75	696	4	24	4	2	0	1	2	0	0	12.0	
i 1	13.233911564625851	0.505	74	903	4	9	10	8	5000	-2	8	0	0	13.0	
i 1	13.234659863945579	0.7575000000000001	75	903	6	1	15	2	5000	-2	2	0	0	9.0	
i 1	13.239897959183674	0.7575000000000001	71	696	6	5	4	8	0	-2	8	0	0	11.0	
i 1	13.25187074829932	0.7575000000000001	74	903	4	5	5	8	5000	-1	8	0	0	11.0	
i 1	13.257857142857143	0.505	71	696	4	4	8	2	0	-1	2	0	0	14.0	
i 1	13.486904761904762	0.505	74	903	4	9	6	2	5000	-2	2	0	0	13.0	
i 1	13.489897959183674	0.7575000000000001	74	903	4	5	16	2	5000	-2	2	0	0	11.0	
i 1	13.494387755102041	0.7575000000000001	72	903	6	1	9	2	5000	-2	2	0	0	9.0	
i 1	13.733911564625851	3.2825	68	405	3	24	16	1	0	-1	1	0	0	7.0	
i 1	13.736156462585035	1.5150000000000001	71	405	3	20	15	1	0	0	1	0	0	3.0	
i 1	13.738401360544218	3.2825	63	405	5	12	4	1	0	1	1	0	0	10.0	
i 1	13.743639455782313	1.7675	75	201	6	1	14	2	0	-2	2	0	0	9.0	
i 1	13.756360544217687	3.2825	61	405	5	12	12	16	0	2	16	0	0	10.0	
i 1	13.757857142857143	0.7575000000000001	74	405	4	5	4	8	0	-1	8	0	0	11.0	
i 1	13.760102040816326	0.7575000000000001	72	405	6	1	5	2	0	1	2	0	0	9.0	
i 1	13.763843537414965	1.7675	74	201	7	5	15	8	0	-1	8	0	0	11.0	
i 1	13.983163265306123	0.505	71	405	4	3	14	2	0	-1	2	0	0	14.0	
i 1	13.984659863945579	0.7575000000000001	71	696	6	5	6	2	0	-1	2	0	0	11.0	
i 1	13.98765306122449	1.5150000000000001	74	201	7	2	1	8	0	-2	8	0	0	14.0	
i 1	13.996632653061225	0.7575000000000001	75	696	5	1	9	2	0	1	2	0	0	9.0	
i 1	14.009353741496598	0.7575000000000001	72	405	4	24	8	2	0	-2	2	0	0	12.0	
i 1	14.015340136054421	0.7575000000000001	74	405	4	5	4	8	0	-2	8	0	0	11.0	
i 1	14.236904761904762	0.505	71	696	6	5	9	8	0	-2	8	0	0	11.0	
i 1	14.243639455782313	0.7575000000000001	75	903	6	1	10	2	5000	-2	2	0	0	9.0	
i 1	14.244387755102041	0.505	74	903	4	9	3	8	5000	-2	8	0	0	13.0	
i 1	14.245136054421769	0.7575000000000001	75	696	4	24	7	2	0	1	2	0	0	12.0	
i 1	14.245884353741497	0.505	71	405	4	4	5	2	0	-2	2	0	0	14.0	
i 1	14.249625850340136	0.505	74	696	5	3	15	2	0	-1	2	0	0	14.0	
i 1	14.260102040816326	0.505	74	903	4	5	14	8	5000	-1	8	0	0	11.0	
i 1	14.267585034013605	0.505	71	696	4	4	8	2	0	-1	2	0	0	14.0	
i 1	14.483163265306123	1.01	71	903	3	20	5	0	5000	0	0	0	0	3.0	
i 1	14.48765306122449	0.7575000000000001	71	903	3	20	14	0	0	0	0	0	0	3.0	
i 1	14.49139455782313	0.7575000000000001	72	903	6	1	7	2	5000	-2	2	0	0	9.0	
i 1	14.500374149659864	0.7575000000000001	71	201	7	5	2	2	0	-2	2	0	0	11.0	
i 1	14.503367346938775	0.7575000000000001	74	903	4	9	4	2	5000	-2	2	0	0	13.0	
i 1	14.507108843537415	0.7575000000000001	74	201	7	2	8	2	0	-2	2	0	0	14.0	
i 1	14.509353741496598	0.7575000000000001	74	903	4	5	1	2	5000	-2	2	0	0	11.0	
i 1	14.513843537414965	0.7575000000000001	72	201	6	1	5	8	0	-2	8	0	0	9.0	
i 1	14.736156462585035	0.7575000000000001	72	405	6	1	7	2	0	1	2	0	0	9.0	
i 1	14.986904761904762	0.7575000000000001	74	405	4	5	2	8	0	-2	8	0	0	11.0	
i 1	14.99812925170068	0.7575000000000001	71	405	4	4	2	2	0	-2	2	0	0	14.0	
i 1	14.998877551020408	2.02	71	696	6	5	13	2	0	-1	2	0	0	11.0	
i 1	14.999625850340136	1.7675	74	696	5	3	7	2	0	-1	2	0	0	14.0	
i 1	15.01234693877551	2.02	75	696	5	1	3	2	0	1	2	0	0	9.0	
i 1	15.01234693877551	0.505	71	405	4	3	13	2	0	-1	2	0	0	14.0	
i 1	15.013095238095238	0.7575000000000001	72	405	4	24	3	2	0	-2	2	0	0	12.0	
i 1	15.017585034013605	0.505	74	405	4	5	3	8	0	-1	8	0	0	11.0	
i 1	15.232414965986395	0.2525	71	201	4	20	5	1	0	0	1	0	0	3.0	
i 1	15.236156462585035	0.7575000000000001	75	903	6	1	16	2	5000	-2	2	0	0	9.0	
i 1	15.236904761904762	0.7575000000000001	71	696	4	4	2	2	0	-1	2	0	0	14.0	
i 1	15.23765306122449	0.7575000000000001	74	903	4	9	6	8	5000	-2	8	0	0	13.0	
i 1	15.249625850340136	0.7575000000000001	74	903	4	5	11	8	5000	-1	8	0	0	11.0	
i 1	15.254863945578231	0.7575000000000001	71	696	6	5	6	8	0	-2	8	0	0	11.0	
i 1	15.261598639455782	0.7575000000000001	75	696	4	24	11	2	0	1	2	0	0	12.0	
i 1	15.266836734693877	0.2525	71	696	4	20	6	0	0	0	0	0	0	3.0	
i 1	15.488401360544218	0.7575000000000001	74	201	7	2	13	2	0	-2	2	0	0	14.0	
i 1	15.49812925170068	0.7575000000000001	74	903	4	9	7	2	5000	-2	2	0	0	13.0	
i 1	15.498877551020408	0.7575000000000001	71	201	7	5	1	2	0	-2	2	0	0	11.0	
i 1	15.506360544217687	0.7575000000000001	74	903	4	5	14	2	5000	-2	2	0	0	11.0	
i 1	15.507857142857143	0.505	72	201	6	1	3	8	0	-2	8	0	0	9.0	
i 1	15.510850340136054	0.505	72	903	6	1	11	2	5000	-2	2	0	0	9.0	
i 1	15.51234693877551	1.01	71	903	3	20	9	0	0	-1	0	0	0	3.0	
i 1	15.517585034013605	1.01	68	405	3	20	6	1	0	-1	1	0	0	3.0	
i 1	15.731666666666667	0.7575000000000001	71	405	4	3	16	2	0	-1	2	0	0	14.0	
i 1	15.743639455782313	0.7575000000000001	72	405	6	1	2	2	0	1	2	0	0	9.0	
i 1	15.745136054421769	0.7575000000000001	75	201	6	1	5	2	0	-2	2	0	0	9.0	
i 1	15.750374149659864	0.7575000000000001	74	201	7	2	10	8	0	-2	8	0	0	14.0	
i 1	15.759353741496598	0.7575000000000001	74	405	4	5	8	8	0	-1	8	0	0	11.0	
i 1	15.763843537414965	0.7575000000000001	74	201	7	5	3	8	0	-1	8	0	0	11.0	
i 1	15.995136054421769	0.7575000000000001	74	405	4	5	16	8	0	-2	8	0	0	11.0	
i 1	16.00261904761905	0.7575000000000001	71	405	4	4	13	2	0	-2	2	0	0	14.0	
i 1	16.004115646258505	1.01	71	903	3	20	6	0	5000	0	0	0	0	3.0	
i 1	16.007108843537416	0.505	68	903	3	20	9	1	0	-1	1	0	0	3.0	
i 1	16.231666666666666	0.505	72	405	4	24	11	2	0	-2	2	0	0	12.0	
i 1	16.23765306122449	0.7575000000000001	71	696	6	5	8	8	0	-2	8	0	0	11.0	
i 1	16.24363945578231	0.2525	71	405	3	24	11	1	0	-1	1	0	0	7.0	
i 1	16.251122448979594	0.7575000000000001	74	903	4	5	4	8	5000	-1	8	0	0	11.0	
i 1	16.25261904761905	0.7575000000000001	75	903	6	1	8	2	5000	-2	2	0	0	9.0	
i 1	16.254863945578233	0.7575000000000001	71	696	4	4	4	2	0	-1	2	0	0	14.0	
i 1	16.257108843537416	0.7575000000000001	74	903	4	9	2	8	5000	-2	8	0	0	13.0	
i 1	16.268333333333334	0.7575000000000001	75	696	4	24	7	2	0	1	2	0	0	12.0	
i 1	16.485408163265305	0.505	74	903	4	5	1	2	5000	-2	2	0	0	11.0	
i 1	16.485408163265305	0.505	68	405	3	24	3	1	0	0	1	0	0	7.0	
i 1	16.48765306122449	0.505	72	201	6	1	15	8	0	-2	8	0	0	9.0	
i 1	16.489149659863944	0.2525	71	696	4	20	10	0	0	-1	0	0	0	3.0	
i 1	16.489897959183672	0.505	72	903	6	1	14	2	5000	-2	2	0	0	9.0	
i 1	16.49438775510204	0.505	74	903	4	9	12	2	5000	-2	2	0	0	13.0	
i 1	16.501122448979594	0.505	74	201	7	2	5	2	0	-2	2	0	0	14.0	
i 1	16.50561224489796	0.2525	68	201	4	20	1	0	0	0	0	0	0	3.0	
i 1	16.5093537414966	0.505	71	201	7	5	11	2	0	-2	2	0	0	11.0	
i 1	16.510102040816328	0.2525	68	201	4	20	13	0	0	-1	0	0	0	3.0	
i 1	16.517585034013607	0.2525	71	696	4	24	9	0	0	-1	0	0	0	7.0	
i 1	16.734659863945577	0.2525	74	201	7	2	12	8	0	-2	8	0	0	14.0	
i 1	16.74363945578231	0.2525	74	405	4	5	4	8	0	-1	8	0	0	11.0	
i 1	16.750374149659866	0.2525	71	903	3	20	9	0	0	0	0	0	0	3.0	
i 1	16.7593537414966	0.2525	72	405	6	1	10	2	0	1	2	0	0	9.0	
i 1	16.764591836734695	0.2525	68	405	3	20	14	1	0	0	1	0	0	3.0	
i 1	16.98391156462585	0.2525	74	195	5	5	9	16	0	1	16	0	0	11.0	
i 1	16.985408163265305	1.01	61	581	5	12	6	6	0	1	6	0	0	10.0	
i 1	16.986156462585033	0.7575000000000001	77	897	4	24	12	17	0	1	17	0	0	12.0	
i 1	16.988401360544216	0.7575000000000001	76	581	3	24	10	16	0	1	16	0	0	7.0	
i 1	16.989149659863944	0.7575000000000001	74	581	4	24	16	16	0	1	16	0	0	12.0	
i 1	16.989149659863944	8.585	66	581	5	12	15	9	0	2	9	0	0	10.0	
i 1	16.992142857142856	4.2925	61	195	5	16	6	9	0	1	9	0	0	10.0	
i 1	16.992891156462584	1.2625	69	195	5	9	5	0	0	-1	0	0	0	13.0	
i 1	16.992891156462584	0.7575000000000001	74	897	6	5	2	16	0	1	16	0	0	11.0	
i 1	16.99438775510204	0.505	74	581	6	1	1	16	0	1	16	0	0	9.0	
i 1	16.99738095238095	0.7575000000000001	74	581	4	5	8	17	0	1	17	0	0	11.0	
i 1	16.998877551020406	1.2625	76	195	4	20	7	17	0	1	17	0	0	3.0	
i 1	16.999625850340134	0.2525	73	897	4	20	1	17	0	1	17	0	0	3.0	
i 1	17.00187074829932	2.02	77	897	5	1	9	17	0	2	17	0	0	9.0	
i 1	17.00261904761905	0.7575000000000001	69	581	4	4	9	0	0	0	0	0	0	14.0	
i 1	17.004115646258505	0.2525	73	897	4	20	3	16	0	1	16	0	0	3.0	
i 1	17.00636054421769	11.8675	73	195	4	24	14	16	0	1	16	0	0	7.0	
i 1	17.007108843537416	0.505	77	581	4	5	9	17	0	2	17	0	0	11.0	
i 1	17.008605442176872	0.2525	73	897	4	24	1	17	0	2	17	0	0	7.0	
i 1	17.010850340136056	1.2625	72	897	6	2	5	1	0	-1	1	0	0	14.0	
i 1	17.010850340136056	0.7575000000000001	72	897	4	4	9	1	0	-1	1	0	0	14.0	
i 1	17.01234693877551	0.2525	74	195	7	1	1	17	0	1	17	0	0	9.0	
i 1	17.01309523809524	0.505	74	897	5	1	11	17	0	1	17	0	0	9.0	
i 1	17.01309523809524	0.505	74	897	6	5	2	16	0	2	16	0	0	11.0	
i 1	17.013843537414967	2.02	72	897	6	2	9	1	0	-1	1	0	0	14.0	
i 1	17.015340136054423	2.7775	73	581	3	24	1	16	0	1	16	0	0	7.0	
i 1	17.01608843537415	0.2525	76	897	4	20	9	17	0	1	17	0	0	3.0	
i 1	17.017585034013607	2.02	74	897	6	5	9	17	0	2	17	0	0	11.0	
i 1	17.238401360544216	1.01	73	195	4	20	15	16	0	1	16	0	0	3.0	
i 1	17.245884353741495	0.7575000000000001	72	195	6	9	6	0	0	0	0	0	0	13.0	
i 1	17.24812925170068	1.01	73	581	3	24	2	17	0	1	17	0	0	7.0	
i 1	17.253367346938777	0.505	76	581	3	20	4	16	0	1	16	0	0	3.0	
i 1	17.257108843537416	0.7575000000000001	77	195	5	1	9	17	0	1	17	0	0	9.0	
i 1	17.265340136054423	1.01	76	195	4	20	2	17	0	2	17	0	0	3.0	
i 1	17.268333333333334	0.7575000000000001	77	195	7	5	12	17	0	2	17	0	0	11.0	
i 1	17.492891156462584	0.7575000000000001	77	897	5	1	16	16	0	2	16	0	0	9.0	
i 1	17.49738095238095	0.7575000000000001	74	195	5	5	14	16	0	1	16	0	0	11.0	
i 1	17.5093537414966	0.7575000000000001	74	195	7	1	14	17	0	1	17	0	0	9.0	
i 1	17.51683673469388	0.7575000000000001	77	897	6	5	3	16	0	1	16	0	0	11.0	
i 1	17.734659863945577	0.7575000000000001	69	897	5	3	11	1	0	-1	1	0	0	14.0	
i 1	17.741394557823128	0.7575000000000001	74	897	6	5	5	16	0	2	16	0	0	11.0	
i 1	17.742142857142856	0.7575000000000001	74	581	6	1	2	16	0	1	16	0	0	9.0	
i 1	17.7593537414966	0.7575000000000001	74	897	5	1	15	17	0	1	17	0	0	9.0	
i 1	17.76234693877551	0.7575000000000001	72	581	4	3	11	0	0	0	0	0	0	14.0	
i 1	17.76683673469388	0.7575000000000001	77	581	4	5	2	17	0	2	17	0	0	11.0	
i 1	17.986156462585033	0.2525	76	581	3	20	7	16	0	1	16	0	0	3.0	
i 1	17.98765306122449	0.7575000000000001	74	581	4	24	5	16	0	1	16	0	0	12.0	
i 1	17.989897959183672	0.7575000000000001	72	897	4	4	2	1	0	-1	1	0	0	14.0	
i 1	18.00187074829932	11.8675	61	581	5	12	16	6	0	1	6	0	0	10.0	
i 1	18.00561224489796	0.7575000000000001	69	581	4	4	4	0	0	0	0	0	0	14.0	
i 1	18.008605442176872	0.7575000000000001	74	897	6	5	5	16	0	1	16	0	0	11.0	
i 1	18.0093537414966	1.01	76	581	3	24	7	16	0	1	16	0	0	7.0	
i 1	18.01309523809524	0.7575000000000001	74	581	4	5	3	17	0	1	17	0	0	11.0	
i 1	18.01608843537415	0.7575000000000001	77	897	4	24	3	17	0	1	17	0	0	12.0	
i 1	18.231666666666666	0.2525	76	897	4	20	5	17	0	1	17	0	0	3.0	
i 1	18.238401360544216	0.7575000000000001	77	195	7	5	1	17	0	2	17	0	0	11.0	
i 1	18.245884353741495	0.2525	76	897	4	24	3	16	0	1	16	0	0	7.0	
i 1	18.250374149659866	0.2525	73	897	4	20	8	16	0	2	16	0	0	3.0	
i 1	18.260850340136056	0.2525	73	897	4	20	10	16	0	2	16	0	0	3.0	
i 1	18.263843537414967	0.7575000000000001	72	195	6	9	15	0	0	0	0	0	0	13.0	
i 1	18.265340136054423	0.7575000000000001	77	195	5	1	4	17	0	1	17	0	0	9.0	
i 1	18.484659863945577	0.2525	73	581	3	20	1	16	0	1	16	0	0	3.0	
i 1	18.488401360544216	0.2525	73	195	4	20	3	17	0	1	17	0	0	3.0	
i 1	18.492891156462584	1.7675	77	897	5	1	11	16	0	2	16	0	0	9.0	
i 1	18.49438775510204	1.7675	72	897	6	2	4	1	0	-1	1	0	0	14.0	
i 1	18.49812925170068	0.2525	76	195	4	20	4	17	0	2	17	0	0	3.0	
i 1	18.498877551020406	0.7575000000000001	74	195	5	5	15	16	0	1	16	0	0	11.0	
i 1	18.504115646258505	0.7575000000000001	74	195	7	1	1	17	0	1	17	0	0	9.0	
i 1	18.50561224489796	1.7675	77	897	6	5	11	16	0	1	16	0	0	11.0	
i 1	18.508605442176872	4.04	76	195	4	20	13	17	0	1	17	0	0	3.0	
i 1	18.51234693877551	1.7675	69	195	5	9	3	0	0	-1	0	0	0	13.0	
i 1	18.735408163265305	0.7575000000000001	74	897	5	1	10	17	0	1	17	0	0	9.0	
i 1	18.742891156462584	0.7575000000000001	74	581	6	1	13	16	0	1	16	0	0	9.0	
i 1	18.742891156462584	0.2525	73	897	4	20	7	17	0	1	17	0	0	3.0	
i 1	18.74438775510204	0.7575000000000001	74	897	6	5	3	16	0	2	16	0	0	11.0	
i 1	18.745884353741495	0.7575000000000001	77	581	4	5	14	17	0	2	17	0	0	11.0	
i 1	18.76234693877551	0.2525	76	897	4	24	16	16	0	2	16	0	0	7.0	
i 1	18.765340136054423	0.2525	73	897	4	20	1	16	0	1	16	0	0	3.0	
i 1	18.98391156462585	0.7575000000000001	74	897	6	5	12	16	0	1	16	0	0	11.0	
i 1	18.992142857142856	1.5150000000000001	76	195	4	20	3	17	0	2	17	0	0	3.0	
i 1	18.995884353741495	0.7575000000000001	74	581	4	5	3	17	0	1	17	0	0	11.0	
i 1	18.99812925170068	0.7575000000000001	74	581	4	24	13	16	0	1	16	0	0	12.0	
i 1	19.001122448979594	0.7575000000000001	69	581	4	4	9	0	0	0	0	0	0	14.0	
i 1	19.008605442176872	0.7575000000000001	77	897	4	24	3	17	0	1	17	0	0	12.0	
i 1	19.008605442176872	0.7575000000000001	73	581	3	24	13	16	0	1	16	0	0	7.0	
i 1	19.013843537414967	1.5150000000000001	73	195	4	20	4	17	0	2	17	0	0	3.0	
i 1	19.01608843537415	0.7575000000000001	72	897	4	4	4	1	0	-1	1	0	0	14.0	
i 1	19.242891156462584	1.2625	76	581	3	20	14	17	0	2	17	0	0	3.0	
i 1	19.24438775510204	0.7575000000000001	77	195	5	1	4	17	0	1	17	0	0	9.0	
i 1	19.25261904761905	2.525	76	581	3	24	13	16	0	1	16	0	0	7.0	
i 1	19.254863945578233	0.7575000000000001	72	195	6	9	10	0	0	0	0	0	0	13.0	
i 1	19.25561224489796	0.7575000000000001	77	195	7	5	14	17	0	2	17	0	0	11.0	
i 1	19.25636054421769	0.7575000000000001	77	897	5	1	14	17	0	2	17	0	0	9.0	
i 1	19.25636054421769	0.7575000000000001	74	897	6	5	9	17	0	2	17	0	0	11.0	
i 1	19.26234693877551	0.7575000000000001	72	897	6	2	15	1	0	-1	1	0	0	14.0	
i 1	19.49438775510204	0.7575000000000001	74	195	7	1	12	17	0	1	17	0	0	9.0	
i 1	19.510102040816328	0.7575000000000001	74	195	5	5	5	16	0	1	16	0	0	11.0	
i 1	19.735408163265305	0.7575000000000001	69	897	5	3	10	1	0	-1	1	0	0	14.0	
i 1	19.735408163265305	0.7575000000000001	77	581	4	5	13	17	0	2	17	0	0	11.0	
i 1	19.738401360544216	0.7575000000000001	73	581	1	24	7	16	0	252	16	307	0	7.0	
i 1	19.750374149659866	1.5150000000000001	74	897	6	5	12	16	0	2	16	0	0	11.0	
i 1	19.75261904761905	0.7575000000000001	72	581	4	3	1	0	0	0	0	0	0	14.0	
i 1	19.753367346938777	1.7675	74	897	5	1	5	17	0	1	17	0	0	9.0	
i 1	19.754115646258505	0.7575000000000001	74	581	6	1	1	16	0	1	16	0	0	9.0	
i 1	19.757108843537416	0.505	73	581	1	24	4	16	0	252	16	307	0	7.0	
i 1	19.989897959183672	0.7575000000000001	77	897	4	24	9	17	0	1	17	0	0	12.0	
i 1	19.99363945578231	0.7575000000000001	69	581	4	4	4	0	0	0	0	0	0	14.0	
i 1	19.998877551020406	0.7575000000000001	74	897	6	5	8	16	0	1	16	0	0	11.0	
i 1	20.010102040816328	0.7575000000000001	74	581	4	24	12	16	0	1	16	0	0	12.0	
i 1	20.01234693877551	0.7575000000000001	72	897	4	4	10	1	0	-1	1	0	0	14.0	
i 1	20.013843537414967	0.7575000000000001	74	581	4	5	13	17	0	1	17	0	0	11.0	
i 1	20.236156462585033	0.7575000000000001	77	195	5	1	13	17	0	1	17	0	0	9.0	
i 1	20.236156462585033	0.7575000000000001	72	897	6	2	9	1	0	-1	1	0	0	14.0	
i 1	20.23690476190476	0.7575000000000001	72	195	6	9	9	0	0	0	0	0	0	13.0	
i 1	20.239149659863944	0.2525	73	581	3	24	13	16	0	1	16	0	0	7.0	
i 1	20.241394557823128	0.7575000000000001	77	897	5	1	6	17	0	2	17	0	0	9.0	
i 1	20.264591836734695	0.7575000000000001	77	195	7	5	8	17	0	2	17	0	0	11.0	
i 1	20.26683673469388	0.7575000000000001	74	897	6	5	2	17	0	2	17	0	0	11.0	
i 1	20.4906462585034	0.7575000000000001	74	195	5	5	15	16	0	1	16	0	0	11.0	
i 1	20.491394557823128	3.0300000000000002	73	581	3	24	6	16	0	1	16	0	0	7.0	
i 1	20.492891156462584	0.7575000000000001	74	195	7	1	10	17	0	1	17	0	0	9.0	
i 1	20.500374149659866	0.2525	73	897	4	20	14	17	0	1	17	0	0	3.0	
i 1	20.50261904761905	0.2525	73	897	4	20	4	16	0	1	16	0	0	3.0	
i 1	20.504115646258505	0.2525	73	897	4	20	13	17	0	1	17	0	0	3.0	
i 1	20.504863945578233	0.7575000000000001	77	897	5	1	12	16	0	2	16	0	0	9.0	
i 1	20.504863945578233	0.7575000000000001	69	195	5	9	1	0	0	-1	0	0	0	13.0	
i 1	20.510102040816328	0.2525	73	897	4	24	11	16	0	1	16	0	0	7.0	
i 1	20.51234693877551	1.7675	72	897	6	2	12	1	0	-1	1	0	0	14.0	
i 1	20.51309523809524	0.7575000000000001	77	897	6	5	14	16	0	1	16	0	0	11.0	
i 1	20.736156462585033	0.7575000000000001	73	581	3	20	9	16	0	1	16	0	0	3.0	
i 1	20.741394557823128	0.7575000000000001	74	581	6	1	16	16	0	1	16	0	0	9.0	
i 1	20.748877551020406	0.7575000000000001	76	195	4	20	3	16	0	1	16	0	0	3.0	
i 1	20.75187074829932	0.505	73	581	3	24	13	17	0	2	17	0	0	7.0	
i 1	20.757857142857144	0.7575000000000001	76	195	4	20	6	16	0	2	16	0	0	3.0	
i 1	20.764591836734695	0.7575000000000001	77	581	4	5	6	17	0	2	17	0	0	11.0	
i 1	20.986156462585033	0.7575000000000001	69	581	4	4	11	0	0	0	0	0	0	14.0	
i 1	20.989149659863944	0.2525	72	897	4	4	6	1	0	-1	1	0	0	14.0	
i 1	20.989149659863944	1.7675	74	897	6	5	15	16	0	1	16	0	0	11.0	
i 1	20.99363945578231	0.7575000000000001	74	581	4	24	10	16	0	1	16	0	0	12.0	
i 1	20.99738095238095	1.7675	77	897	4	24	16	17	0	1	17	0	0	12.0	
i 1	21.010102040816328	0.7575000000000001	74	581	4	5	11	17	0	1	17	0	0	11.0	
i 1	21.23391156462585	0.7575000000000001	74	897	6	5	6	17	0	2	17	0	0	11.0	
i 1	21.234659863945577	0.2525	74	897	6	5	14	16	0	2	16	0	0	11.0	
i 1	21.25261904761905	1.5150000000000001	72	897	4	4	16	1	0	-1	1	0	0	14.0	
i 1	21.254863945578233	0.7575000000000001	72	195	6	9	12	0	0	0	0	0	0	13.0	
i 1	21.258605442176872	1.01	69	195	6	9	5	0	0	-1	0	0	0	13.0	
i 1	21.2593537414966	0.7575000000000001	77	195	5	1	12	17	0	1	17	0	0	9.0	
i 1	21.26309523809524	0.7575000000000001	77	195	7	5	12	17	0	2	17	0	0	11.0	
i 1	21.264591836734695	0.7575000000000001	77	897	6	1	11	17	0	2	17	0	0	9.0	
i 1	21.265340136054423	0.7575000000000001	72	897	6	2	7	1	0	-1	1	0	0	14.0	
i 1	21.48316326530612	0.7575000000000001	77	897	6	5	12	16	0	1	16	0	0	11.0	
i 1	21.492891156462584	0.7575000000000001	74	195	7	5	9	16	0	1	16	0	0	11.0	
i 1	21.49438775510204	0.2525	73	897	4	20	10	17	0	2	17	0	0	3.0	
i 1	21.495884353741495	0.2525	76	897	4	20	4	17	0	2	17	0	0	3.0	
i 1	21.498877551020406	0.7575000000000001	77	897	5	1	10	16	0	2	16	0	0	9.0	
i 1	21.498877551020406	0.7575000000000001	74	195	5	1	16	17	0	1	17	0	0	9.0	
i 1	21.51234693877551	0.2525	73	897	4	24	2	17	0	1	17	0	0	7.0	
i 1	21.734659863945577	0.7575000000000001	74	897	6	5	8	16	0	2	16	0	0	11.0	
i 1	21.735408163265305	0.7575000000000001	72	581	4	3	13	0	0	0	0	0	0	14.0	
i 1	21.735408163265305	0.7575000000000001	77	581	4	5	8	17	0	2	17	0	0	11.0	
i 1	21.73765306122449	0.2525	73	581	3	20	10	17	0	2	17	0	0	3.0	
i 1	21.74438775510204	0.7575000000000001	74	581	6	1	9	16	0	1	16	0	0	9.0	
i 1	21.751122448979594	0.7575000000000001	74	897	5	1	9	17	0	1	17	0	0	9.0	
i 1	21.76309523809524	0.2525	76	195	4	20	3	16	0	2	16	0	0	3.0	
i 1	21.764591836734695	0.7575000000000001	69	897	5	3	11	1	0	-1	1	0	0	14.0	
i 1	21.984659863945577	0.7575000000000001	74	581	4	5	5	17	0	1	17	0	0	11.0	
i 1	21.988401360544216	0.505	76	897	4	20	13	16	0	2	16	0	0	3.0	
i 1	21.99363945578231	11.11	76	581	3	24	12	16	0	1	16	0	0	7.0	
i 1	21.998877551020406	0.505	76	897	4	20	14	16	0	2	16	0	0	3.0	
i 1	22.007108843537416	0.505	73	897	4	20	13	17	0	2	17	0	0	3.0	
i 1	22.0093537414966	0.7575000000000001	69	581	4	4	14	0	0	0	0	0	0	14.0	
i 1	22.013843537414967	0.2525	73	897	4	24	16	17	0	1	17	0	0	7.0	
i 1	22.017585034013607	0.7575000000000001	74	581	4	24	7	16	0	1	16	0	0	12.0	
i 1	22.231666666666666	1.7675	77	897	6	1	6	17	0	2	17	0	0	9.0	
i 1	22.236156462585033	0.7575000000000001	72	195	6	9	12	0	0	0	0	0	0	13.0	
i 1	22.25261904761905	1.7675	74	897	6	5	1	17	0	2	17	0	0	11.0	
i 1	22.257108843537416	0.7575000000000001	77	195	7	5	2	17	0	2	17	0	0	11.0	
i 1	22.26309523809524	0.7575000000000001	77	195	5	1	12	17	0	1	17	0	0	9.0	
i 1	22.264591836734695	1.7675	72	897	6	2	10	1	0	-1	1	0	0	14.0	
i 1	22.495136054421767	1.7675	69	195	6	9	8	0	0	-1	0	0	0	13.0	
i 1	22.495136054421767	0.7575000000000001	73	195	4	20	10	16	0	2	16	0	0	3.0	
i 1	22.496632653061223	3.7875	72	897	6	2	4	1	0	-1	1	0	0	14.0	
i 1	22.498877551020406	0.7575000000000001	74	195	5	1	4	17	0	1	17	0	0	9.0	
i 1	22.503367346938777	0.2525	73	195	4	20	15	16	0	2	16	0	0	3.0	
i 1	22.5093537414966	0.7575000000000001	77	897	6	5	15	16	0	1	16	0	0	11.0	
i 1	22.514591836734695	0.7575000000000001	77	897	5	1	14	16	0	2	16	0	0	9.0	
i 1	22.515340136054423	0.7575000000000001	74	195	7	5	7	16	0	1	16	0	0	11.0	
i 1	22.518333333333334	0.7575000000000001	76	581	3	20	2	17	0	1	17	0	0	3.0	
i 1	22.736156462585033	0.505	73	581	3	24	7	16	0	2	16	0	0	7.0	
i 1	22.74738095238095	0.7575000000000001	74	897	5	1	11	17	0	1	17	0	0	9.0	
i 1	22.748877551020406	0.7575000000000001	74	581	6	1	13	16	0	1	16	0	0	9.0	
i 1	22.754115646258505	0.7575000000000001	77	581	4	5	15	17	0	2	17	0	0	11.0	
i 1	22.76234693877551	0.7575000000000001	74	897	6	5	4	16	0	2	16	0	0	11.0	
i 1	22.991394557823128	0.7575000000000001	74	581	4	5	6	17	0	1	17	0	0	11.0	
i 1	22.99363945578231	0.7575000000000001	74	581	4	24	15	16	0	1	16	0	0	12.0	
i 1	23.001122448979594	0.7575000000000001	69	581	4	4	9	0	0	0	0	0	0	14.0	
i 1	23.001122448979594	0.2525	73	195	4	20	7	16	0	2	16	0	0	3.0	
i 1	23.011598639455784	0.7575000000000001	72	897	4	4	1	1	0	-1	1	0	0	14.0	
i 1	23.01309523809524	0.7575000000000001	77	897	4	24	3	17	0	1	17	0	0	12.0	
i 1	23.01309523809524	0.7575000000000001	74	897	6	5	13	16	0	1	16	0	0	11.0	
i 1	23.231666666666666	0.7575000000000001	77	195	7	5	10	17	0	2	17	0	0	11.0	
i 1	23.23391156462585	0.7575000000000001	77	195	5	1	12	17	0	1	17	0	0	9.0	
i 1	23.246632653061223	0.2525	73	897	4	20	11	17	0	1	17	0	0	3.0	
i 1	23.2593537414966	0.2525	73	897	4	20	4	16	0	1	16	0	0	3.0	
i 1	23.261598639455784	0.7575000000000001	72	195	6	9	12	0	0	0	0	0	0	13.0	
i 1	23.264591836734695	0.2525	73	897	4	24	2	16	0	1	16	0	0	7.0	
i 1	23.48391156462585	1.7675	77	897	6	5	10	16	0	1	16	0	0	11.0	
i 1	23.48391156462585	0.7575000000000001	74	195	7	5	1	16	0	1	16	0	0	11.0	
i 1	23.489149659863944	0.7575000000000001	74	195	5	1	2	17	0	1	17	0	0	9.0	
i 1	23.489149659863944	0.2525	73	581	3	24	14	17	0	1	17	0	0	7.0	
i 1	23.489897959183672	0.7575000000000001	73	195	4	20	13	16	0	1	16	0	0	3.0	
i 1	23.4906462585034	0.2525	73	195	4	20	7	17	0	2	17	0	0	3.0	
i 1	23.499625850340134	0.7575000000000001	76	581	3	20	15	16	0	2	16	0	0	3.0	
i 1	23.5093537414966	1.7675	77	897	5	1	6	16	0	2	16	0	0	9.0	
i 1	23.73391156462585	0.7575000000000001	72	581	4	3	7	0	0	0	0	0	0	14.0	
i 1	23.736156462585033	0.7575000000000001	77	581	4	5	13	17	0	2	17	0	0	11.0	
i 1	23.749625850340134	0.7575000000000001	74	897	6	5	11	16	0	2	16	0	0	11.0	
i 1	23.75561224489796	0.7575000000000001	69	897	5	3	6	1	0	-1	1	0	0	14.0	
i 1	23.76309523809524	0.7575000000000001	74	581	6	1	8	16	0	1	16	0	0	9.0	
i 1	23.767585034013607	0.7575000000000001	74	897	5	1	8	17	0	1	17	0	0	9.0	
i 1	23.981666666666666	0.7575000000000001	77	897	4	24	4	17	0	1	17	0	0	12.0	
i 1	23.985408163265305	0.7575000000000001	74	581	4	5	6	17	0	1	17	0	0	11.0	
i 1	23.985408163265305	0.2525	73	581	3	24	15	17	0	1	17	0	0	7.0	
i 1	23.988401360544216	1.01	76	195	4	20	6	17	0	1	17	0	0	3.0	
i 1	24.00261904761905	0.7575000000000001	74	581	4	24	11	16	0	1	16	0	0	12.0	
i 1	24.003367346938777	0.7575000000000001	72	897	4	4	1	1	0	-1	1	0	0	14.0	
i 1	24.008605442176872	0.7575000000000001	69	581	4	4	14	0	0	0	0	0	0	14.0	
i 1	24.015340136054423	0.7575000000000001	74	897	6	5	6	16	0	1	16	0	0	11.0	
i 1	24.236156462585033	0.7575000000000001	77	195	7	5	7	17	0	2	17	0	0	11.0	
i 1	24.2406462585034	0.505	73	897	4	24	10	16	0	2	16	0	0	7.0	
i 1	24.245884353741495	0.7575000000000001	72	897	6	2	10	1	0	-1	1	0	0	14.0	
i 1	24.24738095238095	0.7575000000000001	77	195	5	1	11	17	0	1	17	0	0	9.0	
i 1	24.24812925170068	0.7575000000000001	74	897	6	5	5	17	0	2	17	0	0	11.0	
i 1	24.250374149659866	0.7575000000000001	72	195	6	9	15	0	0	0	0	0	0	13.0	
i 1	24.25636054421769	0.505	73	897	4	20	1	17	0	1	17	0	0	3.0	
i 1	24.258605442176872	0.505	73	897	4	20	10	16	0	1	16	0	0	3.0	
i 1	24.260850340136056	0.7575000000000001	73	581	3	24	11	16	0	1	16	0	0	7.0	
i 1	24.26234693877551	0.7575000000000001	77	897	6	1	9	17	0	2	17	0	0	9.0	
i 1	24.495884353741495	0.7575000000000001	74	195	5	1	2	17	0	1	17	0	0	9.0	
i 1	24.50187074829932	1.7675	69	195	6	9	5	0	0	-1	0	0	0	13.0	
i 1	24.51234693877551	0.7575000000000001	74	195	7	5	15	16	0	1	16	0	0	11.0	
i 1	24.736156462585033	0.7575000000000001	77	581	4	5	3	17	0	2	17	0	0	11.0	
i 1	24.742142857142856	0.7575000000000001	74	581	6	1	3	16	0	1	16	0	0	9.0	
i 1	24.742142857142856	0.7575000000000001	76	195	4	20	3	17	0	1	17	0	0	3.0	
i 1	24.749625850340134	1.7675	74	897	5	1	14	17	0	1	17	0	0	9.0	
i 1	24.75261904761905	1.7675	74	897	6	5	13	16	0	2	16	0	0	11.0	
i 1	24.76608843537415	0.7575000000000001	76	581	3	20	6	17	0	2	17	0	0	3.0	
i 1	24.991394557823128	0.7575000000000001	69	581	4	4	5	0	0	0	0	0	0	14.0	
i 1	24.995136054421767	0.505	74	897	6	5	5	16	0	1	16	0	0	11.0	
i 1	24.996632653061223	0.7575000000000001	74	581	4	5	9	17	0	1	17	0	0	11.0	
i 1	25.00261904761905	0.7575000000000001	72	897	4	4	15	1	0	-1	1	0	0	14.0	
i 1	25.003367346938777	0.7575000000000001	77	897	4	24	10	17	0	1	17	0	0	12.0	
i 1	25.018333333333334	0.7575000000000001	74	581	4	24	4	16	0	1	16	0	0	12.0	
i 1	25.23316326530612	0.7575000000000001	77	195	5	1	12	17	0	1	17	0	0	9.0	
i 1	25.23316326530612	0.2525	72	195	6	9	2	0	0	0	0	0	0	13.0	
i 1	25.236156462585033	0.7575000000000001	77	195	7	5	2	17	0	2	17	0	0	11.0	
i 1	25.23765306122449	1.5150000000000001	73	581	3	24	4	16	0	1	16	0	0	7.0	
i 1	25.238401360544216	0.7575000000000001	77	897	6	1	8	17	0	2	17	0	0	9.0	
i 1	25.239897959183672	0.7575000000000001	72	897	6	2	12	1	0	-1	1	0	0	14.0	
i 1	25.26608843537415	0.2525	74	897	6	5	8	17	0	2	17	0	0	11.0	
i 1	25.26683673469388	1.5150000000000001	76	195	4	20	1	17	0	1	17	0	0	3.0	
i 1	25.48316326530612	1.01	69	897	5	3	13	1	0	-1	1	0	0	14.0	
i 1	25.485408163265305	0.2525	74	897	6	5	5	16	0	1	16	0	0	11.0	
i 1	25.486156462585033	0.7575000000000001	74	195	7	5	10	16	0	1	16	0	0	11.0	
i 1	25.496632653061223	0.7575000000000001	74	195	5	1	4	17	0	1	17	0	0	9.0	
i 1	25.49738095238095	0.505	72	195	6	9	13	0	0	0	0	0	0	13.0	
i 1	25.499625850340134	0.7575000000000001	77	897	6	5	3	16	0	1	16	0	0	11.0	
i 1	25.501122448979594	0.2525	73	897	4	20	13	17	0	1	17	0	0	3.0	
i 1	25.504863945578233	0.2525	73	897	4	20	13	16	0	2	16	0	0	3.0	
i 1	25.50561224489796	0.7575000000000001	77	897	6	1	10	16	0	2	16	0	0	9.0	
i 1	25.518333333333334	0.505	74	897	6	5	11	17	0	2	17	0	0	11.0	
i 1	25.734659863945577	0.505	73	581	3	20	13	17	0	1	17	0	0	3.0	
i 1	25.745884353741495	0.505	76	195	4	20	15	17	0	1	17	0	0	3.0	
i 1	25.74738095238095	0.7575000000000001	72	581	5	3	12	0	0	0	0	0	0	14.0	
i 1	25.75187074829932	0.7575000000000001	77	581	6	5	9	17	0	2	17	0	0	11.0	
i 1	25.7593537414966	0.7575000000000001	74	581	4	1	3	16	0	1	16	0	0	9.0	
i 1	25.98765306122449	0.7575000000000001	74	581	4	5	9	17	0	1	17	0	0	11.0	
i 1	25.995136054421767	1.7675	72	897	4	4	2	1	0	-1	1	0	0	14.0	
i 1	26.000374149659866	1.7675	77	897	4	24	10	17	0	1	17	0	0	12.0	
i 1	26.004863945578233	0.7575000000000001	74	581	4	24	14	16	0	1	16	0	0	12.0	
i 1	26.007108843537416	1.7675	74	897	6	5	5	16	0	1	16	0	0	11.0	
i 1	26.0093537414966	0.7575000000000001	69	581	4	4	1	0	0	0	0	0	0	14.0	
i 1	26.236156462585033	0.7575000000000001	77	897	6	1	1	17	0	2	17	0	0	9.0	
i 1	26.236156462585033	0.7575000000000001	77	195	7	5	1	17	0	2	17	0	0	11.0	
i 1	26.23765306122449	0.2525	76	897	4	20	7	16	0	1	16	0	0	3.0	
i 1	26.23765306122449	0.2525	73	897	4	20	11	17	0	2	17	0	0	3.0	
i 1	26.2406462585034	0.7575000000000001	77	195	5	1	8	17	0	1	17	0	0	9.0	
i 1	26.24363945578231	0.7575000000000001	72	897	6	2	6	1	0	-1	1	0	0	14.0	
i 1	26.245884353741495	0.7575000000000001	74	897	6	5	6	17	0	2	17	0	0	11.0	
i 1	26.251122448979594	0.7575000000000001	72	195	6	9	14	0	0	0	0	0	0	13.0	
i 1	26.489149659863944	0.7575000000000001	77	897	6	1	8	16	0	2	16	0	0	9.0	
i 1	26.496632653061223	0.7575000000000001	74	195	7	5	7	16	0	1	16	0	0	11.0	
i 1	26.49812925170068	0.7575000000000001	73	581	3	20	11	17	0	1	17	0	0	3.0	
i 1	26.504863945578233	1.7675	69	195	6	9	2	0	0	-1	0	0	0	13.0	
i 1	26.507108843537416	0.7575000000000001	74	195	5	1	15	17	0	1	17	0	0	9.0	
i 1	26.510850340136056	1.7675	72	897	6	2	7	1	0	-1	1	0	0	14.0	
i 1	26.511598639455784	0.7575000000000001	73	195	4	20	2	17	0	2	17	0	0	3.0	
i 1	26.515340136054423	0.7575000000000001	77	897	6	5	16	16	0	1	16	0	0	11.0	
i 1	26.73391156462585	0.7575000000000001	74	581	4	1	1	16	0	1	16	0	0	9.0	
i 1	26.741394557823128	0.7575000000000001	77	581	6	5	14	17	0	2	17	0	0	11.0	
i 1	26.742142857142856	0.7575000000000001	74	897	6	5	13	16	0	2	16	0	0	11.0	
i 1	26.754115646258505	0.7575000000000001	74	897	5	1	15	17	0	1	17	0	0	9.0	
i 1	26.982414965986393	0.7575000000000001	74	581	4	24	11	16	0	1	16	0	0	12.0	
i 1	26.995884353741495	0.7575000000000001	69	581	4	4	5	0	0	0	0	0	0	14.0	
i 1	27.010850340136056	0.7575000000000001	74	581	4	5	6	17	0	1	17	0	0	11.0	
i 1	27.01234693877551	1.01	76	195	4	20	3	17	0	1	17	0	0	3.0	
i 1	27.015340136054423	0.2525	73	195	4	20	3	16	0	1	16	0	0	3.0	
i 1	27.232414965986393	0.7575000000000001	72	195	6	9	16	0	0	0	0	0	0	13.0	
i 1	27.239897959183672	1.7675	77	897	6	1	13	17	0	2	17	0	0	9.0	
i 1	27.2406462585034	1.7675	74	897	6	5	2	17	0	2	17	0	0	11.0	
i 1	27.24363945578231	0.7575000000000001	77	195	5	1	5	17	0	1	17	0	0	9.0	
i 1	27.245136054421767	0.7575000000000001	77	195	7	5	10	17	0	2	17	0	0	11.0	
i 1	27.254115646258505	0.7575000000000001	73	581	3	24	12	16	0	1	16	0	0	7.0	
i 1	27.257857142857144	1.7675	72	897	6	2	6	1	0	-1	1	0	0	14.0	
i 1	27.260102040816328	0.505	73	897	4	20	5	17	0	2	17	0	0	3.0	
i 1	27.260850340136056	0.505	73	897	4	20	10	17	0	2	17	0	0	3.0	
i 1	27.265340136054423	0.505	73	897	4	20	16	17	0	2	17	0	0	3.0	
i 1	27.489149659863944	0.7575000000000001	74	195	7	5	13	16	0	1	16	0	0	11.0	
i 1	27.496632653061223	0.7575000000000001	77	897	6	1	16	16	0	2	16	0	0	9.0	
i 1	27.504863945578233	0.7575000000000001	74	195	5	1	14	17	0	1	17	0	0	9.0	
i 1	27.518333333333334	0.7575000000000001	77	897	6	5	12	16	0	1	16	0	0	11.0	
i 1	27.734659863945577	0.7575000000000001	73	195	4	20	16	16	0	2	16	0	0	3.0	
i 1	27.742891156462584	0.7575000000000001	72	581	5	3	1	0	0	0	0	0	0	14.0	
i 1	27.74738095238095	0.7575000000000001	74	897	6	5	4	16	0	2	16	0	0	11.0	
i 1	27.753367346938777	0.7575000000000001	74	581	4	1	10	16	0	1	16	0	0	9.0	
i 1	27.754863945578233	0.7575000000000001	77	581	6	5	10	17	0	2	17	0	0	11.0	
i 1	27.75561224489796	0.7575000000000001	76	581	3	20	5	17	0	1	17	0	0	3.0	
i 1	27.758605442176872	0.7575000000000001	74	897	5	1	15	17	0	1	17	0	0	9.0	
i 1	27.7593537414966	0.7575000000000001	69	897	5	3	3	1	0	-1	1	0	0	14.0	
i 1	27.99438775510204	0.7575000000000001	72	897	4	4	1	1	0	-1	1	0	0	14.0	
i 1	27.998877551020406	0.7575000000000001	77	897	4	24	15	17	0	1	17	0	0	12.0	
i 1	27.999625850340134	0.7575000000000001	74	581	4	24	3	16	0	1	16	0	0	12.0	
i 1	28.007857142857144	0.7575000000000001	74	581	4	5	5	17	0	1	17	0	0	11.0	
i 1	28.0093537414966	0.7575000000000001	69	581	4	4	3	0	0	0	0	0	0	14.0	
i 1	28.014591836734695	0.7575000000000001	74	897	6	5	7	16	0	1	16	0	0	11.0	
i 1	28.23316326530612	5.3025	76	195	4	20	14	17	0	1	17	0	0	3.0	
i 1	28.236156462585033	0.7575000000000001	77	195	7	5	16	17	0	2	17	0	0	11.0	
i 1	28.26234693877551	0.7575000000000001	72	195	6	9	16	0	0	0	0	0	0	13.0	
i 1	28.26683673469388	1.2625	73	581	3	24	1	16	0	1	16	0	0	7.0	
i 1	28.267585034013607	0.7575000000000001	77	195	5	1	3	17	0	1	17	0	0	9.0	
i 1	28.48316326530612	1.2625	77	897	6	5	4	16	0	1	16	0	0	11.0	
i 1	28.489149659863944	1.7675	72	897	6	2	8	1	0	-1	1	0	0	14.0	
i 1	28.49438775510204	0.7575000000000001	73	897	4	20	13	17	0	1	17	0	0	3.0	
i 1	28.49812925170068	0.7575000000000001	74	195	7	5	9	16	0	1	16	0	0	11.0	
i 1	28.50261904761905	1.7675	77	897	6	1	14	16	0	2	16	0	0	9.0	
i 1	28.50561224489796	0.7575000000000001	73	897	4	20	11	16	0	2	16	0	0	3.0	
i 1	28.508605442176872	1.2625	69	195	6	9	15	0	0	-1	0	0	0	13.0	
i 1	28.510102040816328	0.7575000000000001	76	897	4	20	9	17	0	2	17	0	0	3.0	
i 1	28.513843537414967	0.7575000000000001	74	195	5	1	13	17	0	1	17	0	0	9.0	
i 1	28.7406462585034	0.7575000000000001	77	581	6	5	12	17	0	2	17	0	0	11.0	
i 1	28.745136054421767	0.7575000000000001	74	897	6	5	15	16	0	2	16	0	0	11.0	
i 1	28.7593537414966	0.7575000000000001	74	581	4	1	8	16	0	1	16	0	0	9.0	
i 1	28.76683673469388	0.7575000000000001	74	897	5	1	16	17	0	1	17	0	0	9.0	
i 1	28.984659863945577	0.7575000000000001	74	581	4	24	14	16	0	1	16	0	0	12.0	
i 1	28.98765306122449	0.7575000000000001	69	581	4	4	6	0	0	0	0	0	0	14.0	
i 1	28.992891156462584	4.04	73	195	4	24	7	16	0	1	16	0	0	7.0	
i 1	28.99363945578231	0.7575000000000001	74	897	6	5	12	16	0	1	16	0	0	11.0	
i 1	29.013843537414967	0.7575000000000001	72	897	4	4	1	1	0	-1	1	0	0	14.0	
i 1	29.015340136054423	0.7575000000000001	74	581	4	5	2	17	0	1	17	0	0	11.0	
i 1	29.018333333333334	0.7575000000000001	77	897	4	24	11	17	0	1	17	0	0	12.0	
i 1	29.23391156462585	0.7575000000000001	72	897	6	2	7	1	0	-1	1	0	0	14.0	
i 1	29.235408163265305	1.01	76	195	4	20	2	17	0	1	17	0	0	3.0	
i 1	29.24438775510204	0.7575000000000001	77	195	5	1	11	17	0	1	17	0	0	9.0	
i 1	29.24438775510204	0.505	77	195	7	5	7	17	0	2	17	0	0	11.0	
i 1	29.246632653061223	0.7575000000000001	77	897	6	1	8	17	0	2	17	0	0	9.0	
i 1	29.248877551020406	0.7575000000000001	72	195	6	9	5	0	0	0	0	0	0	13.0	
i 1	29.248877551020406	1.01	76	195	4	20	16	17	0	1	17	0	0	3.0	
i 1	29.251122448979594	0.7575000000000001	74	897	6	5	3	17	0	2	17	0	0	11.0	
i 1	29.26608843537415	0.7575000000000001	73	581	3	20	4	16	0	1	16	0	0	3.0	
i 1	29.49438775510204	0.7575000000000001	74	195	5	1	15	17	0	1	17	0	0	9.0	
i 1	29.5093537414966	1.7675	73	581	1	24	10	16	0	248	16	308	0	7.0	
i 1	29.511598639455784	0.7575000000000001	74	195	7	5	13	16	0	1	16	0	0	11.0	
i 1	29.73316326530612	0.505	77	897	6	5	16	16	0	1	16	0	0	11.0	
i 1	29.741394557823128	0.7575000000000001	74	581	4	1	7	16	0	1	16	0	0	9.0	
i 1	29.741394557823128	0.7575000000000001	72	581	5	3	2	0	0	0	0	0	0	14.0	
i 1	29.74363945578231	1.7675	74	897	6	1	12	17	0	1	17	0	0	9.0	
i 1	29.749625850340134	0.7575000000000001	69	897	5	3	8	1	0	-1	1	0	0	14.0	
i 1	29.754115646258505	0.2525	77	195	6	5	6	17	0	2	17	0	0	11.0	
i 1	29.754863945578233	0.7575000000000001	77	581	6	5	16	17	0	2	17	0	0	11.0	
i 1	29.761598639455784	1.7675	74	897	6	5	7	16	0	2	16	0	0	11.0	
i 1	29.765340136054423	0.505	69	195	6	9	3	0	0	-1	0	0	0	13.0	
i 1	29.988401360544216	0.7575000000000001	74	897	6	5	11	16	0	1	16	0	0	11.0	
i 1	29.9906462585034	0.7575000000000001	74	581	6	5	8	17	0	1	17	0	0	11.0	
i 1	29.996632653061223	0.7575000000000001	69	581	4	4	16	0	0	0	0	0	0	14.0	
i 1	30.000374149659866	0.7575000000000001	72	897	4	4	12	1	0	-1	1	0	0	14.0	
i 1	30.013843537414967	0.7575000000000001	74	581	4	24	3	16	0	1	16	0	0	12.0	
i 1	30.018333333333334	0.7575000000000001	77	897	4	24	13	17	0	1	17	0	0	12.0	
i 1	30.231666666666666	0.2525	76	897	4	20	1	16	0	2	16	0	0	3.0	
i 1	30.242142857142856	0.7575000000000001	72	195	6	9	12	0	0	0	0	0	0	13.0	
i 1	30.242142857142856	0.7575000000000001	74	897	6	5	2	17	0	2	17	0	0	11.0	
i 1	30.246632653061223	0.7575000000000001	72	897	6	2	11	1	0	-1	1	0	0	14.0	
i 1	30.25187074829932	0.2525	76	897	4	20	3	17	0	2	17	0	0	3.0	
i 1	30.25261904761905	0.7575000000000001	77	195	6	5	15	17	0	2	17	0	0	11.0	
i 1	30.257108843537416	0.7575000000000001	77	195	5	1	1	17	0	1	17	0	0	9.0	
i 1	30.2593537414966	0.7575000000000001	77	897	6	1	11	17	0	2	17	0	0	9.0	
i 1	30.26683673469388	0.2525	76	897	4	20	12	17	0	1	17	0	0	3.0	
i 1	30.482414965986393	1.7675	69	195	6	9	6	0	0	-1	0	0	0	13.0	
i 1	30.48316326530612	0.7575000000000001	76	581	3	20	10	17	0	2	17	0	0	3.0	
i 1	30.491394557823128	1.7675	72	897	6	2	1	1	0	-1	1	0	0	14.0	
i 1	30.495136054421767	0.7575000000000001	73	195	4	20	13	16	0	1	16	0	0	3.0	
i 1	30.50187074829932	0.7575000000000001	77	897	6	5	4	16	0	1	16	0	0	11.0	
i 1	30.507857142857144	0.7575000000000001	74	195	5	1	9	17	0	1	17	0	0	9.0	
i 1	30.511598639455784	0.7575000000000001	77	897	6	1	15	16	0	2	16	0	0	9.0	
i 1	30.513843537414967	0.7575000000000001	76	195	4	20	1	16	0	2	16	0	0	3.0	
i 1	30.514591836734695	0.7575000000000001	74	195	7	5	12	16	0	1	16	0	0	11.0	
i 1	30.757857142857144	0.7575000000000001	77	581	6	5	15	17	0	2	17	0	0	11.0	
i 1	30.760102040816328	0.7575000000000001	74	581	4	1	14	16	0	1	16	0	0	9.0	
i 1	30.99438775510204	1.7675	74	897	6	5	14	16	0	1	16	0	0	11.0	
i 1	30.995884353741495	0.7575000000000001	74	581	6	5	11	17	0	1	17	0	0	11.0	
i 1	30.996632653061223	0.7575000000000001	74	581	4	24	10	16	0	1	16	0	0	12.0	
i 1	31.0093537414966	0.7575000000000001	69	581	4	4	5	0	0	0	0	0	0	14.0	
i 1	31.010850340136056	1.7675	77	897	4	24	9	17	0	1	17	0	0	12.0	
i 1	31.014591836734695	1.7675	72	897	4	4	12	1	0	-1	1	0	0	14.0	
i 1	31.01608843537415	0.2525	76	581	3	24	4	16	0	2	16	0	0	7.0	
i 1	31.239897959183672	0.7575000000000001	74	897	6	5	3	17	0	2	17	0	0	11.0	
i 1	31.245136054421767	0.7575000000000001	73	581	3	24	16	16	0	1	16	0	0	7.0	
i 1	31.24738095238095	0.2525	76	897	4	20	11	16	0	2	16	0	0	3.0	
i 1	31.250374149659866	0.2525	73	897	4	20	4	17	0	2	17	0	0	3.0	
i 1	31.254115646258505	0.2525	76	897	4	24	16	16	0	2	16	0	0	7.0	
i 1	31.254863945578233	0.2525	76	897	4	20	10	16	0	2	16	0	0	3.0	
i 1	31.257857142857144	0.7575000000000001	72	195	6	9	12	0	0	0	0	0	0	13.0	
i 1	31.261598639455784	0.7575000000000001	72	897	6	2	13	1	0	-1	1	0	0	14.0	
i 1	31.26309523809524	0.7575000000000001	77	195	5	1	10	17	0	1	17	0	0	9.0	
i 1	31.26608843537415	0.7575000000000001	77	897	6	1	16	17	0	2	17	0	0	9.0	
i 1	31.26683673469388	0.7575000000000001	77	195	6	5	5	17	0	2	17	0	0	11.0	
i 1	31.48391156462585	0.7575000000000001	74	195	5	1	15	17	0	1	17	0	0	9.0	
i 1	31.4906462585034	1.2625	76	581	3	20	13	16	0	1	16	0	0	3.0	
i 1	31.491394557823128	0.7575000000000001	77	897	6	1	6	16	0	2	16	0	0	9.0	
i 1	31.49363945578231	1.5150000000000001	74	195	7	5	16	16	0	1	16	0	0	11.0	
i 1	31.504115646258505	0.7575000000000001	77	897	6	5	11	16	0	1	16	0	0	11.0	
i 1	31.50636054421769	1.2625	73	195	4	20	11	17	0	2	17	0	0	3.0	
i 1	31.510850340136056	0.505	76	581	3	24	10	16	0	2	16	0	0	7.0	
i 1	31.515340136054423	1.2625	73	195	4	20	9	17	0	2	17	0	0	3.0	
i 1	31.732414965986393	0.7575000000000001	72	581	5	3	7	0	0	0	0	0	0	14.0	
i 1	31.745136054421767	0.7575000000000001	69	897	5	3	4	1	0	-1	1	0	0	14.0	
i 1	31.746632653061223	0.505	74	897	6	5	3	16	0	2	16	0	0	11.0	
i 1	31.74738095238095	0.505	77	581	6	5	8	17	0	2	17	0	0	11.0	
i 1	31.75187074829932	0.7575000000000001	74	581	4	1	1	16	0	1	16	0	0	9.0	
i 1	31.767585034013607	0.7575000000000001	74	897	6	1	3	17	0	1	17	0	0	9.0	
i 1	31.986156462585033	0.7575000000000001	74	581	4	24	9	16	0	1	16	0	0	12.0	
i 1	32.00187074829932	0.7575000000000001	69	581	4	4	3	0	0	0	0	0	0	14.0	
i 1	32.01833333333333	0.7575000000000001	74	581	6	5	10	17	0	1	17	0	0	11.0	
i 1	32.01833333333333	0.7575000000000001	73	581	1	24	4	16	0	252	16	307	0	7.0	
i 1	32.23465986394558	1.2625	72	897	6	2	15	1	0	-1	1	0	0	14.0	
i 1	32.245884353741495	0.7575000000000001	72	195	6	9	14	0	0	0	0	0	0	13.0	
i 1	32.246632653061226	0.7575000000000001	77	195	5	1	4	17	0	1	17	0	0	9.0	
i 1	32.264591836734695	1.2625	77	897	6	1	4	17	0	2	17	0	0	9.0	
i 1	32.485408163265305	0.7575000000000001	74	195	5	1	8	17	0	1	17	0	0	9.0	
i 1	32.485408163265305	1.01	72	897	6	2	7	1	0	-1	1	0	0	14.0	
i 1	32.48690476190476	1.01	77	897	6	1	3	16	0	2	16	0	0	9.0	
i 1	32.501122448979594	0.505	77	195	6	5	16	17	0	2	17	0	0	11.0	
i 1	32.514591836734695	0.505	74	897	6	5	12	17	0	2	17	0	0	11.0	
i 1	32.51534013605442	0.2525	76	581	3	24	3	16	0	2	16	0	0	7.0	
i 1	32.51608843537415	1.01	69	195	6	9	9	0	0	-1	0	0	0	13.0	
i 1	32.51833333333333	0.505	77	897	6	5	15	16	0	1	16	0	0	11.0	
i 1	32.73166666666667	0.2525	76	897	4	20	14	17	0	2	17	0	0	3.0	
i 1	32.743639455782315	0.2525	73	897	4	20	9	16	0	1	16	0	0	3.0	
i 1	32.74438775510204	0.7575000000000001	73	581	3	24	16	16	0	1	16	0	0	7.0	
i 1	32.756360544217685	0.7575000000000001	74	581	4	1	13	16	0	1	16	0	0	9.0	
i 1	32.756360544217685	0.7575000000000001	74	897	6	5	4	16	0	2	16	0	0	11.0	
i 1	32.761598639455784	0.7575000000000001	77	581	6	5	10	17	0	2	17	0	0	11.0	
i 1	32.76234693877551	0.2525	73	897	4	24	7	16	0	1	16	0	0	7.0	
i 1	32.763843537414964	0.2525	73	897	4	20	7	17	0	2	17	0	0	3.0	
i 1	32.76758503401361	0.7575000000000001	74	897	6	1	2	17	0	1	17	0	0	9.0	
i 1	32.9906462585034	0.505	74	581	4	24	14	16	0	1	16	0	0	12.0	
i 1	32.99438775510204	0.505	77	897	4	24	10	17	0	1	17	0	0	12.0	
i 1	33.006360544217685	0.505	72	897	4	4	12	1	0	-1	1	0	0	14.0	
i 1	33.01758503401361	0.505	69	581	4	4	4	0	0	0	0	0	0	14.0	
i 1	33.23465986394558	0.2525	72	581	5	3	5	0	0	0	0	0	0	14.0	
i 1	33.23989795918367	0.2525	73	897	4	20	4	16	0	1	16	0	0	3.0	
i 1	33.2406462585034	0.2525	77	897	6	5	11	16	0	1	16	0	0	11.0	
i 1	33.25187074829932	0.7575000000000001	73	195	4	24	12	16	0	1	16	0	0	7.0	
i 1	33.253367346938774	0.2525	73	897	4	20	4	16	0	2	16	0	0	3.0	
i 1	33.25561224489796	0.2525	74	897	6	5	13	16	0	1	16	0	0	11.0	
i 1	33.26085034013605	0.2525	76	581	3	24	8	16	0	1	16	0	0	7.0	
i 1	33.26234693877551	0.2525	74	897	6	5	9	17	0	2	17	0	0	11.0	
i 1	33.26309523809524	0.2525	74	581	6	5	1	17	0	1	17	0	0	11.0	
i 1	33.48241496598639	0.505	77	693	6	5	9	17	0	2	17	0	0	11.0	
i 1	33.48765306122449	1.5150000000000001	74	1079	6	1	13	16	0	2	16	0	0	9.0	
i 1	33.48765306122449	0.7575000000000001	74	693	6	5	16	17	0	2	17	0	0	11.0	
i 1	33.488401360544216	0.505	74	693	6	5	6	16	0	2	16	0	0	11.0	
i 1	33.49289115646258	0.2525	77	1079	6	1	13	17	0	2	17	0	0	9.0	
i 1	33.493639455782315	0.505	74	693	4	1	7	17	0	1	17	0	0	9.0	
i 1	33.49438775510204	2.2725	72	1079	6	2	16	0	0	-1	0	0	0	14.0	
i 1	33.49513605442177	0.505	69	693	5	3	4	0	0	-1	0	0	0	14.0	
i 1	33.495884353741495	0.505	73	693	3	20	11	17	0	2	17	0	0	3.0	
i 1	33.496632653061226	0.7575000000000001	77	693	4	24	11	16	0	1	16	0	0	12.0	
i 1	33.49812925170068	0.505	77	693	4	24	8	16	0	2	16	0	0	12.0	
i 1	33.49962585034014	0.7575000000000001	69	693	4	4	7	0	0	-1	0	0	0	14.0	
i 1	33.50037414965986	0.7575000000000001	74	693	6	1	9	17	0	1	17	0	0	9.0	
i 1	33.50261904761905	0.2525	76	195	4	20	6	16	0	1	16	0	0	3.0	
i 1	33.506360544217685	0.2525	69	1079	6	2	9	1	0	-1	1	0	0	14.0	
i 1	33.5093537414966	1.01	74	693	6	5	16	16	0	1	16	0	0	11.0	
i 1	33.5093537414966	0.2525	76	693	3	24	5	17	0	2	17	0	0	7.0	
i 1	33.51010204081633	1.5150000000000001	77	1079	6	5	13	17	0	2	17	0	0	11.0	
i 1	33.51309523809524	0.7575000000000001	69	693	5	3	3	0	0	0	0	0	0	14.0	
i 1	33.513843537414964	1.01	72	693	4	4	13	0	0	0	0	0	0	14.0	
i 1	33.514591836734695	0.505	73	693	3	24	4	16	0	1	16	0	0	7.0	
i 1	33.51833333333333	0.505	76	195	4	20	1	17	0	2	17	0	0	3.0	
i 1	33.74289115646258	0.7575000000000001	72	195	6	9	9	0	0	0	0	0	0	13.0	
i 1	33.75187074829932	0.7575000000000001	77	195	6	5	13	17	0	2	17	0	0	11.0	
i 1	33.754115646258505	0.505	77	195	5	1	4	17	0	1	17	0	0	9.0	
i 1	33.98166666666667	0.7575000000000001	74	195	5	1	3	17	0	1	17	0	0	9.0	
i 1	33.985408163265305	1.01	76	195	4	20	1	17	0	2	17	0	0	1.9999999999999982	
i 1	33.986156462585036	0.7575000000000001	74	195	6	5	12	16	0	1	16	0	0	11.0	
i 1	33.986156462585036	11.3625	73	693	3	24	15	16	0	1	16	0	0	5.999999999999998	
i 1	33.99214285714286	1.01	73	693	3	20	13	17	0	2	17	0	0	1.9999999999999982	
i 1	33.99438775510204	0.2525	74	693	6	5	4	16	0	2	16	0	0	11.0	
i 1	33.99513605442177	0.2525	77	693	4	24	6	16	0	2	16	0	0	12.0	
i 1	34.003367346938774	2.02	73	195	4	24	9	16	0	1	16	0	0	5.999999999999998	
i 1	34.00860544217687	0.7575000000000001	77	1079	6	1	9	17	0	2	17	0	0	9.0	
i 1	34.01010204081633	0.7575000000000001	69	195	6	9	1	0	0	-1	0	0	0	13.0	
i 1	34.01085034013605	0.7575000000000001	74	1079	4	5	3	16	0	2	16	0	0	11.0	
i 1	34.01234693877551	1.5150000000000001	69	1079	5	2	13	1	0	-1	1	0	0	14.0	
i 1	34.23765306122449	1.5150000000000001	69	693	5	3	4	0	0	-1	0	0	0	14.0	
i 1	34.2593537414966	1.2625	76	195	4	20	15	17	0	1	17	0	0	1.9999999999999982	
i 1	34.26010204081633	0.7575000000000001	76	195	4	20	13	16	0	1	16	0	0	1.9999999999999982	
i 1	34.26758503401361	0.7575000000000001	77	693	6	5	14	17	0	2	17	0	0	11.0	
i 1	34.48989795918367	1.7675	74	693	6	1	1	17	0	1	17	0	0	9.0	
i 1	34.495884353741495	0.7575000000000001	77	693	4	24	3	16	0	1	16	0	0	12.0	
i 1	34.49738095238095	0.505	74	693	4	1	9	17	0	1	17	0	0	9.0	
i 1	34.50785714285714	0.7575000000000001	74	693	6	5	9	17	0	2	17	0	0	11.0	
i 1	34.514591836734695	1.7675	74	693	6	5	6	16	0	2	16	0	0	11.0	
i 1	34.736156462585036	0.7575000000000001	77	195	5	1	11	17	0	1	17	0	0	9.0	
i 1	34.73914965986395	0.7575000000000001	76	693	3	24	9	17	0	2	17	0	0	5.999999999999998	
i 1	34.7406462585034	0.7575000000000001	77	693	4	24	2	16	0	2	16	0	0	12.0	
i 1	34.756360544217685	0.7575000000000001	77	195	6	5	9	17	0	2	17	0	0	11.0	
i 1	34.75710884353742	0.7575000000000001	74	693	6	5	6	16	0	1	16	0	0	11.0	
i 1	34.986156462585036	0.505	72	195	6	9	16	0	0	0	0	0	0	13.0	
i 1	34.995884353741495	0.505	69	195	6	9	15	0	0	-1	0	0	0	13.0	
i 1	34.995884353741495	0.2525	73	693	4	20	7	17	0	2	17	0	0	1.9999999999999982	
i 1	34.996632653061226	0.2525	74	1079	4	20	10	2	0	-2	2	0	0	1.9999999999999982	
i 1	34.99738095238095	0.505	72	693	4	4	4	0	0	0	0	0	0	14.0	
i 1	34.99962585034014	0.7575000000000001	74	1079	4	5	8	16	0	2	16	0	0	11.0	
i 1	35.00037414965986	1.7675	77	1079	6	1	2	17	0	2	17	0	0	9.0	
i 1	35.011598639455784	0.7575000000000001	74	195	6	5	15	16	0	1	16	0	0	11.0	
i 1	35.01608843537415	0.7575000000000001	74	195	5	1	2	17	0	1	17	0	0	9.0	
i 1	35.23465986394558	0.505	74	1079	6	1	12	16	0	2	16	0	0	9.0	
i 1	35.23465986394558	1.01	73	693	3	20	6	17	0	2	17	0	0	1.9999999999999982	
i 1	35.245884353741495	0.7575000000000001	74	195	4	20	13	2	0	-2	2	0	0	1.9999999999999982	
i 1	35.26010204081633	0.7575000000000001	77	1079	6	5	7	17	0	2	17	0	0	11.0	
i 1	35.26234693877551	0.7575000000000001	69	693	5	3	10	0	0	0	0	0	0	14.0	
i 1	35.263843537414964	0.505	74	693	4	1	12	17	0	1	17	0	0	9.0	
i 1	35.26833333333333	0.7575000000000001	77	693	6	5	6	17	0	2	17	0	0	11.0	
i 1	35.49812925170068	0.7575000000000001	74	693	6	5	3	17	0	2	17	0	0	11.0	
i 1	35.49962585034014	0.7575000000000001	76	693	1	24	10	17	0	252	17	307	0	5.999999999999998	
i 1	35.50785714285714	0.7575000000000001	77	693	4	24	6	16	0	1	16	0	0	12.0	
i 1	35.733163265306125	0.505	72	195	6	9	4	0	0	0	0	0	0	13.0	
i 1	35.733163265306125	0.505	77	195	6	5	4	17	0	2	17	0	0	11.0	
i 1	35.74962585034014	0.2525	69	693	4	4	16	0	0	-1	0	0	0	14.0	
i 1	35.756360544217685	1.5150000000000001	74	693	6	5	12	16	0	1	16	0	0	11.0	
i 1	35.983163265306125	0.7575000000000001	73	195	1	24	3	16	0	252	16	307	0	5.999999999999998	
i 1	35.986156462585036	0.7575000000000001	74	195	6	5	2	16	0	1	16	0	0	11.0	
i 1	35.993639455782315	0.505	77	195	5	1	7	17	0	1	17	0	0	9.0	
i 1	35.99812925170068	1.5150000000000001	77	693	4	24	3	16	0	2	16	0	0	12.0	
i 1	36.001122448979594	2.02	76	195	4	20	9	17	0	1	17	0	0	1.9999999999999982	
i 1	36.00486394557823	0.2525	71	195	4	20	6	8	0	-2	8	0	0	1.9999999999999982	
i 1	36.00860544217687	0.7575000000000001	74	195	5	1	9	17	0	1	17	0	0	9.0	
i 1	36.0093537414966	0.2525	69	693	5	3	4	0	0	-1	0	0	0	14.0	
i 1	36.01309523809524	0.2525	72	693	4	4	4	0	0	0	0	0	0	14.0	
i 1	36.01758503401361	0.7575000000000001	74	1079	4	5	6	16	0	2	16	0	0	11.0	
i 1	36.243639455782315	0.7575000000000001	74	1079	6	1	15	16	0	2	16	0	0	9.0	
i 1	36.251122448979594	0.7575000000000001	74	693	4	1	5	17	0	1	17	0	0	9.0	
i 1	36.251122448979594	0.2525	73	693	4	20	12	17	0	2	17	0	0	1.9999999999999982	
i 1	36.25486394557823	0.2525	76	693	3	24	11	17	0	2	17	0	0	5.999999999999998	
i 1	36.26234693877551	0.2525	74	1079	4	20	13	2	0	-2	2	0	0	1.9999999999999982	
i 1	36.263843537414964	0.505	69	195	6	9	14	0	0	-1	0	0	0	13.0	
i 1	36.26534013605442	0.2525	69	693	5	3	3	0	0	0	0	0	0	14.0	
i 1	36.266836734693875	0.505	69	1079	5	2	3	1	0	-1	1	0	0	14.0	
i 1	36.488401360544216	1.2625	77	1079	6	5	14	17	0	2	17	0	0	11.0	
i 1	36.49139455782313	1.2625	73	693	3	20	7	17	0	2	17	0	0	1.9999999999999982	
i 1	36.49438775510204	0.505	77	693	6	5	10	17	0	2	17	0	0	11.0	
i 1	36.49513605442177	0.505	69	693	5	3	8	0	0	-1	0	0	0	14.0	
i 1	36.50037414965986	0.505	74	693	6	5	7	16	0	2	16	0	0	11.0	
i 1	36.50187074829932	1.5150000000000001	72	1079	6	2	10	0	0	-1	0	0	0	14.0	
i 1	36.506360544217685	0.505	77	693	4	24	8	16	0	1	16	0	0	12.0	
i 1	36.50710884353742	1.01	72	693	4	4	9	0	0	0	0	0	0	14.0	
i 1	36.51010204081633	0.505	74	693	6	1	6	17	0	1	17	0	0	9.0	
i 1	36.51309523809524	0.505	74	693	6	5	1	17	0	2	17	0	0	11.0	
i 1	36.51833333333333	1.2625	71	195	4	20	15	2	0	1	2	0	0	1.9999999999999982	
i 1	36.73465986394558	0.7575000000000001	77	195	5	1	15	17	0	1	17	0	0	9.0	
i 1	36.73914965986395	0.2525	73	195	4	24	11	16	0	1	16	0	0	5.999999999999998	
i 1	36.743639455782315	0.7575000000000001	72	195	6	9	4	0	0	0	0	0	0	13.0	
i 1	36.743639455782315	0.505	77	195	6	5	7	17	0	2	17	0	0	11.0	
i 1	37.233163265306125	0.505	71	195	4	20	4	2	0	1	2	0	0	1.9999999999999982	
i 1	37.238401360544216	0.7575000000000001	69	693	5	3	2	0	0	-1	0	0	0	14.0	
i 1	37.238401360544216	0.505	73	195	4	24	7	16	0	1	16	0	0	5.999999999999998	
i 1	37.24289115646258	0.505	74	1079	4	5	4	16	0	2	16	0	0	11.0	
i 1	37.24513605442177	0.505	74	195	6	5	11	16	0	1	16	0	0	11.0	
i 1	37.253367346938774	0.7575000000000001	74	693	4	1	4	17	0	1	17	0	0	9.0	
i 1	37.25561224489796	0.505	69	195	6	9	9	0	0	-1	0	0	0	13.0	
i 1	37.26234693877551	0.7575000000000001	74	1079	6	1	5	16	0	2	16	0	0	9.0	
i 1	37.26608843537415	0.2525	77	1079	6	1	15	17	0	2	17	0	0	9.0	
i 1	37.266836734693875	1.2625	69	1079	5	2	13	1	0	-1	1	0	0	14.0	
i 1	37.26758503401361	0.505	74	195	5	1	16	17	0	1	17	0	0	9.0	
i 1	37.48166666666667	0.7575000000000001	76	693	3	24	7	17	0	2	17	0	0	5.999999999999998	
i 1	37.493639455782315	0.7575000000000001	74	693	6	5	12	17	0	2	17	0	0	11.0	
i 1	37.50261904761905	0.7575000000000001	69	693	5	3	14	0	0	0	0	0	0	14.0	
i 1	37.50710884353742	0.2525	77	693	6	5	16	17	0	2	17	0	0	11.0	
i 1	37.51534013605442	0.7575000000000001	69	693	4	4	14	0	0	-1	0	0	0	14.0	
i 1	37.51534013605442	0.7575000000000001	74	693	6	5	6	16	0	2	16	0	0	11.0	
i 1	37.73391156462585	0.505	74	693	6	1	1	17	0	1	17	0	0	9.0	
i 1	37.735408163265305	0.505	72	693	4	4	9	0	0	0	0	0	0	14.0	
i 1	37.736156462585036	0.505	72	195	6	9	6	0	0	0	0	0	0	13.0	
i 1	37.73914965986395	0.2525	74	1079	4	20	12	2	0	1	2	0	0	1.9999999999999982	
i 1	37.745884353741495	0.505	77	195	5	1	5	17	0	1	17	0	0	9.0	
i 1	37.746632653061226	0.505	77	1079	6	1	7	17	0	2	17	0	0	9.0	
i 1	37.75037414965986	0.7575000000000001	77	693	4	24	11	16	0	2	16	0	0	12.0	
i 1	37.751122448979594	0.2525	73	693	4	20	12	17	0	2	17	0	0	1.9999999999999982	
i 1	37.76608843537415	0.505	77	693	4	24	13	16	0	1	16	0	0	12.0	
i 1	37.983163265306125	1.2625	73	195	4	24	5	16	0	1	16	0	0	5.999999999999998	
i 1	37.988401360544216	0.2525	74	693	6	5	9	16	0	1	16	0	0	11.0	
i 1	37.9906462585034	0.505	69	195	6	9	11	0	0	-1	0	0	0	13.0	
i 1	37.99139455782313	1.2625	71	195	4	20	2	2	0	1	2	0	0	1.9999999999999982	
i 1	37.996632653061226	0.505	74	195	6	5	10	16	0	1	16	0	0	11.0	
i 1	37.99738095238095	0.2525	71	195	4	20	5	2	0	1	2	0	0	1.9999999999999982	
i 1	38.011598639455784	0.2525	77	195	6	5	7	17	0	2	17	0	0	11.0	
i 1	38.014591836734695	1.2625	73	693	3	20	9	17	0	2	17	0	0	1.9999999999999982	
i 1	38.016836734693875	0.7575000000000001	74	195	5	1	6	17	0	1	17	0	0	9.0	
i 1	38.01758503401361	0.505	74	1079	4	5	1	16	0	2	16	0	0	11.0	
i 1	38.23391156462585	0.2525	77	195	6	1	7	17	0	1	17	0	0	9.0	
i 1	38.235408163265305	0.7575000000000001	74	1079	6	1	13	16	0	2	16	0	0	9.0	
i 1	38.25860544217687	0.7575000000000001	74	693	4	1	16	17	0	1	17	0	0	9.0	
i 1	38.266836734693875	0.505	77	1079	6	1	13	17	0	2	17	0	0	9.0	
i 1	38.266836734693875	3.7875	66	1079	5	14	4	6	0	2	6	0	0	11.0	
i 1	38.485408163265305	1.2625	72	1079	5	2	4	0	0	-1	0	0	0	14.0	
i 1	38.488401360544216	0.505	74	693	6	1	15	17	0	1	17	0	0	9.0	
i 1	38.493639455782315	0.505	77	693	4	24	12	16	0	1	16	0	0	12.0	
i 1	38.49438775510204	0.505	77	693	5	5	1	17	0	2	17	0	0	11.0	
i 1	38.498877551020406	1.2625	69	693	5	3	2	0	0	-1	0	0	0	14.0	
i 1	38.50037414965986	0.505	77	1079	4	5	5	17	0	2	17	0	0	11.0	
i 1	38.51234693877551	0.505	74	693	6	5	11	17	0	2	17	0	0	11.0	
i 1	38.736156462585036	0.7575000000000001	72	693	4	4	10	0	0	0	0	0	0	14.0	
i 1	38.73989795918367	0.7575000000000001	72	195	6	9	11	0	0	0	0	0	0	13.0	
i 1	38.745884353741495	0.7575000000000001	77	195	6	1	1	17	0	1	17	0	0	9.0	
i 1	38.75037414965986	0.7575000000000001	77	693	4	24	14	16	0	2	16	0	0	12.0	
i 1	38.76234693877551	0.505	74	693	6	5	8	16	0	1	16	0	0	11.0	
i 1	38.76608843537415	0.505	77	195	6	5	5	17	0	2	17	0	0	11.0	
i 1	38.76833333333333	0.2525	74	693	6	5	13	16	0	2	16	0	0	11.0	
i 1	38.98690476190476	0.2525	76	195	4	20	3	17	0	1	17	0	0	1.9999999999999982	
i 1	38.996632653061226	0.7575000000000001	69	195	6	9	7	0	0	-1	0	0	0	13.0	
i 1	39.004115646258505	0.7575000000000001	69	1079	5	2	14	1	0	-1	1	0	0	14.0	
i 1	39.01085034013605	0.2525	71	195	4	20	1	2	0	1	2	0	0	1.9999999999999982	
i 1	39.014591836734695	0.7575000000000001	76	693	3	24	15	17	0	2	17	0	0	5.999999999999998	
i 1	39.23166666666667	0.2525	71	1079	4	20	2	2	0	1	2	0	0	1.9999999999999982	
i 1	39.23241496598639	0.2525	74	1079	4	5	7	16	0	2	16	0	0	11.0	
i 1	39.23690476190476	0.7575000000000001	74	693	4	1	15	17	0	1	17	0	0	9.0	
i 1	39.23765306122449	0.2525	77	1079	6	1	5	17	0	2	17	0	0	9.0	
i 1	39.23914965986395	0.7575000000000001	74	1079	6	1	14	16	0	2	16	0	0	9.0	
i 1	39.24962585034014	0.2525	73	693	4	20	3	17	0	2	17	0	0	1.9999999999999982	
i 1	39.254115646258505	0.2525	74	195	6	5	14	16	0	1	16	0	0	11.0	
i 1	39.26234693877551	0.7575000000000001	77	1079	4	5	16	17	0	2	17	0	0	11.0	
i 1	39.266836734693875	0.505	74	195	5	1	7	17	0	1	17	0	0	9.0	
i 1	39.486156462585036	0.505	71	195	4	20	16	2	0	1	2	0	0	1.9999999999999982	
i 1	39.49513605442177	0.505	73	195	4	24	15	16	0	1	16	0	0	5.999999999999998	
i 1	39.50261904761905	0.2525	73	693	3	24	8	17	0	2	17	0	0	5.999999999999998	
i 1	39.506360544217685	0.505	77	693	5	5	13	17	0	2	17	0	0	11.0	
i 1	39.50710884353742	0.505	69	693	5	3	12	0	0	0	0	0	0	14.0	
i 1	39.51085034013605	0.7575000000000001	73	693	3	20	13	17	0	2	17	0	0	1.9999999999999982	
i 1	39.513843537414964	0.2525	71	195	4	20	6	2	0	1	2	0	0	1.9999999999999982	
i 1	39.51608843537415	0.505	69	693	4	4	8	0	0	-1	0	0	0	14.0	
i 1	39.51833333333333	0.505	74	693	6	5	12	16	0	2	16	0	0	11.0	
i 1	39.73989795918367	0.2525	77	693	4	24	7	16	0	1	16	0	0	12.0	
i 1	39.74738095238095	0.2525	74	693	6	1	6	17	0	1	17	0	0	9.0	
i 1	39.748877551020406	0.7575000000000001	74	693	6	5	3	16	0	1	16	0	0	11.0	
i 1	39.751122448979594	0.7575000000000001	77	195	6	5	11	17	0	2	17	0	0	11.0	
i 1	39.75187074829932	0.2525	74	693	6	5	2	17	0	2	17	0	0	11.0	
i 1	39.754115646258505	0.7575000000000001	77	195	6	1	7	17	0	1	17	0	0	9.0	
i 1	39.75860544217687	0.7575000000000001	77	693	4	24	1	16	0	2	16	0	0	12.0	
i 1	39.99513605442177	0.505	72	693	4	4	11	0	0	0	0	0	0	14.0	
i 1	40.00037414965986	0.7575000000000001	73	195	1	24	7	16	0	252	16	307	0	5.999999999999998	
i 1	40.00261904761905	1.01	72	1079	5	2	6	0	0	-1	0	0	0	14.0	
i 1	40.01010204081633	0.505	76	693	3	24	3	17	0	2	17	0	0	5.999999999999998	
i 1	40.01085034013605	0.2525	73	693	3	24	6	17	0	2	17	0	0	5.999999999999998	
i 1	40.01234693877551	0.505	72	195	6	9	9	0	0	0	0	0	0	13.0	
i 1	40.23391156462585	0.2525	74	195	5	1	1	17	0	1	17	0	0	9.0	
i 1	40.23391156462585	1.01	74	693	6	5	7	16	0	2	16	0	0	11.0	
i 1	40.23765306122449	0.7575000000000001	74	693	6	1	10	17	0	1	17	0	0	9.0	
i 1	40.23765306122449	0.2525	69	195	6	9	8	0	0	-1	0	0	0	13.0	
i 1	40.238401360544216	0.7575000000000001	74	693	4	1	10	17	0	1	17	0	0	9.0	
i 1	40.23989795918367	0.505	74	195	6	5	6	16	0	1	16	0	0	11.0	
i 1	40.24139455782313	0.505	77	1079	4	5	10	17	0	2	17	0	0	11.0	
i 1	40.243639455782315	0.505	74	1079	4	5	1	16	0	2	16	0	0	11.0	
i 1	40.248877551020406	0.2525	74	1079	4	20	5	2	0	-2	2	0	0	1.9999999999999982	
i 1	40.251122448979594	0.7575000000000001	69	693	5	3	1	0	0	-1	0	0	0	14.0	
i 1	40.25261904761905	0.505	77	693	5	5	16	17	0	2	17	0	0	11.0	
i 1	40.25710884353742	0.2525	69	1079	5	2	3	1	0	-1	1	0	0	14.0	
i 1	40.25860544217687	0.7575000000000001	74	1079	6	1	4	16	0	2	16	0	0	9.0	
i 1	40.263843537414964	0.2525	77	1079	6	1	7	17	0	2	17	0	0	9.0	
i 1	40.26534013605442	0.2525	73	693	4	20	2	17	0	2	17	0	0	1.9999999999999982	
i 1	40.48465986394558	0.505	71	195	4	20	16	2	0	-2	2	0	0	1.9999999999999982	
i 1	40.49139455782313	0.505	73	693	3	20	3	17	0	2	17	0	0	1.9999999999999982	
i 1	40.49812925170068	0.7575000000000001	74	693	6	5	4	17	0	2	17	0	0	11.0	
i 1	40.516836734693875	1.01	76	195	4	20	3	17	0	1	17	0	0	1.9999999999999982	
i 1	40.73914965986395	0.7575000000000001	77	195	6	1	4	17	0	1	17	0	0	9.0	
i 1	40.745884353741495	0.7575000000000001	76	693	3	24	5	17	0	2	17	0	0	5.999999999999998	
i 1	40.74962585034014	2.2725	73	195	4	24	7	16	0	1	16	0	0	5.999999999999998	
i 1	40.754115646258505	0.2525	77	693	4	24	7	16	0	1	16	0	0	12.0	
i 1	40.756360544217685	0.505	77	693	4	24	3	16	0	2	16	0	0	12.0	
i 1	40.98391156462585	0.2525	71	1079	4	20	9	8	0	1	8	0	0	1.9999999999999982	
i 1	40.98465986394558	0.505	74	1079	4	5	13	16	0	2	16	0	0	11.0	
i 1	40.986156462585036	0.505	74	195	6	5	10	16	0	1	16	0	0	11.0	
i 1	41.00187074829932	0.2525	69	693	4	4	3	0	0	-1	0	0	0	14.0	
i 1	41.00486394557823	0.2525	73	693	4	20	14	17	0	2	17	0	0	1.9999999999999982	
i 1	41.01085034013605	1.01	72	693	4	4	13	0	0	0	0	0	0	14.0	
i 1	41.01085034013605	0.2525	72	195	6	9	15	0	0	0	0	0	0	13.0	
i 1	41.01085034013605	0.2525	74	693	6	5	5	16	0	1	16	0	0	11.0	
i 1	41.016836734693875	0.2525	77	195	6	5	12	17	0	2	17	0	0	11.0	
i 1	41.23241496598639	0.505	69	195	6	9	14	0	0	-1	0	0	0	13.0	
i 1	41.23391156462585	4.04	73	693	3	20	7	17	0	2	17	0	0	1.9999999999999982	
i 1	41.243639455782315	0.7575000000000001	69	1079	5	2	14	1	0	-1	1	0	0	14.0	
i 1	41.25561224489796	0.7575000000000001	77	1079	6	1	1	17	0	2	17	0	0	9.0	
i 1	41.261598639455784	0.505	74	195	5	1	15	17	0	1	17	0	0	9.0	
i 1	41.264591836734695	1.7675	74	195	4	20	13	8	0	1	8	0	0	1.9999999999999982	
i 1	41.48765306122449	0.505	72	1079	5	2	3	0	0	-1	0	0	0	14.0	
i 1	41.48989795918367	0.7575000000000001	74	693	6	5	11	17	0	2	17	0	0	11.0	
i 1	41.4906462585034	0.2525	77	1079	4	5	4	17	0	2	17	0	0	11.0	
i 1	41.49214285714286	0.505	77	693	4	24	3	16	0	1	16	0	0	12.0	
i 1	41.50187074829932	0.505	74	693	4	1	13	17	0	1	17	0	0	9.0	
i 1	41.503367346938774	0.505	74	693	6	1	11	17	0	1	17	0	0	9.0	
i 1	41.50561224489796	0.7575000000000001	69	693	5	3	15	0	0	0	0	0	0	14.0	
i 1	41.50785714285714	0.505	74	1079	6	1	9	16	0	2	16	0	0	9.0	
i 1	41.51010204081633	0.2525	77	693	5	5	14	17	0	2	17	0	0	11.0	
i 1	41.511598639455784	0.505	77	693	4	24	11	16	0	2	16	0	0	12.0	
i 1	41.511598639455784	0.505	69	693	5	3	14	0	0	-1	0	0	0	14.0	
i 1	41.51234693877551	0.505	69	693	4	4	14	0	0	-1	0	0	0	14.0	
i 1	41.73765306122449	0.505	74	693	6	5	8	16	0	1	16	0	0	11.0	
i 1	41.74812925170068	0.7575000000000001	77	195	6	1	9	17	0	1	17	0	0	9.0	
i 1	41.748877551020406	0.7575000000000001	72	195	6	9	4	0	0	0	0	0	0	13.0	
i 1	41.753367346938774	0.7575000000000001	74	693	6	5	12	16	0	2	16	0	0	11.0	
i 1	41.98989795918367	0.7575000000000001	74	195	6	5	14	16	0	1	16	0	0	11.0	
i 1	41.99738095238095	0.505	67	75	6	14	15	5	0	1	5	0	0	11.0	
i 1	41.99962585034014	0.2525	72	75	6	2	10	2	0	1	2	0	0	14.0	
i 1	42.00261904761905	0.505	77	195	6	5	9	17	0	2	17	0	0	11.0	
i 1	42.00561224489796	0.505	72	75	5	5	13	1	0	0	1	0	0	11.0	
i 1	42.006360544217685	0.505	72	75	7	1	16	0	0	-1	0	0	0	9.0	
i 1	42.014591836734695	0.505	72	75	5	5	15	1	0	-1	1	0	0	11.0	
i 1	42.23765306122449	0.505	74	693	6	1	10	17	0	1	17	0	0	9.0	
i 1	42.24438775510204	0.505	72	75	6	2	14	2	0	-2	2	0	0	14.0	
i 1	42.245884353741495	0.2525	69	75	7	1	7	1	0	-1	1	0	0	9.0	
i 1	42.245884353741495	0.505	74	693	4	1	11	17	0	1	17	0	0	9.0	
i 1	42.251122448979594	0.505	76	693	3	24	10	17	0	2	17	0	0	5.999999999999998	
i 1	42.25261904761905	0.505	73	693	3	24	15	17	0	2	17	0	0	5.999999999999998	
i 1	42.253367346938774	0.505	69	195	6	9	14	0	0	-1	0	0	0	13.0	
i 1	42.26010204081633	0.2525	74	195	5	1	12	17	0	1	17	0	0	9.0	
i 1	42.26010204081633	0.505	77	693	5	5	2	17	0	2	17	0	0	11.0	
i 1	42.496632653061226	0.505	72	693	4	4	6	0	0	0	0	0	0	14.0	
i 1	42.49812925170068	0.2525	74	693	4	5	9	16	0	2	16	0	0	11.0	
i 1	42.50561224489796	4.2925	60	75	6	13	13	0	0	0	0	0	0	8.0	
i 1	42.50785714285714	7.575	67	75	6	14	8	5	0	1	5	0	0	11.0	
i 1	42.50785714285714	0.7575000000000001	72	75	6	2	7	2	0	1	2	0	0	14.0	
i 1	42.513843537414964	0.505	69	693	4	4	12	0	0	-1	0	0	0	14.0	
i 1	42.736156462585036	0.2525	74	693	6	5	9	16	0	1	16	0	0	11.0	
i 1	42.7406462585034	0.2525	74	693	5	5	6	17	0	2	17	0	0	11.0	
i 1	42.74139455782313	0.505	77	693	4	24	3	16	0	1	16	0	0	12.0	
i 1	42.74289115646258	0.505	72	75	7	1	4	0	0	-1	0	0	0	9.0	
i 1	42.75785714285714	0.505	77	693	4	24	15	16	0	2	16	0	0	12.0	
i 1	42.763843537414964	0.505	72	75	6	5	15	1	0	-1	1	0	0	11.0	
i 1	42.986156462585036	0.7575000000000001	69	75	7	1	6	1	0	-1	1	0	0	9.0	
i 1	42.986156462585036	0.2525	77	195	6	1	1	17	0	1	17	0	0	9.0	
i 1	42.99139455782313	0.2525	77	195	7	5	10	17	0	2	17	0	0	11.0	
i 1	42.995884353741495	1.5150000000000001	74	195	6	1	11	17	0	1	17	0	0	9.0	
i 1	43.00187074829932	0.2525	73	693	3	24	5	17	0	2	17	0	0	5.999999999999998	
i 1	43.00785714285714	0.2525	76	693	3	24	6	17	0	2	17	0	0	5.999999999999998	
i 1	43.01534013605442	0.2525	72	195	6	9	5	0	0	0	0	0	0	13.0	
i 1	43.23391156462585	0.505	72	75	5	5	2	1	0	0	1	0	0	11.0	
i 1	43.243639455782315	0.2525	72	75	6	2	11	2	0	-2	2	0	0	14.0	
i 1	43.245884353741495	2.02	73	195	4	24	3	16	0	1	16	0	0	5.999999999999998	
i 1	43.24812925170068	0.2525	69	195	6	9	2	0	0	-1	0	0	0	13.0	
i 1	43.251122448979594	2.02	74	195	4	20	12	8	0	1	8	0	0	1.9999999999999982	
i 1	43.266836734693875	0.505	74	195	6	5	5	16	0	1	16	0	0	11.0	
i 1	43.483163265306125	1.2625	74	693	4	1	13	17	0	1	17	0	0	9.0	
i 1	43.485408163265305	0.505	69	693	5	3	3	0	0	-1	0	0	0	14.0	
i 1	43.48914965986395	0.505	69	693	5	3	14	0	0	0	0	0	0	14.0	
i 1	43.50037414965986	1.2625	74	693	6	1	9	17	0	1	17	0	0	9.0	
i 1	43.501122448979594	0.2525	74	693	4	5	2	16	0	2	16	0	0	11.0	
i 1	43.50710884353742	1.01	77	195	7	5	7	17	0	2	17	0	0	11.0	
i 1	43.51234693877551	1.01	72	75	6	5	3	1	0	-1	1	0	0	11.0	
i 1	43.516836734693875	0.2525	77	693	5	5	3	17	0	2	17	0	0	11.0	
i 1	43.73989795918367	1.01	72	75	6	2	4	2	0	-2	2	0	0	14.0	
i 1	43.74139455782313	0.7575000000000001	72	75	6	2	5	2	0	1	2	0	0	14.0	
i 1	43.763843537414964	0.2525	72	693	4	4	15	0	0	0	0	0	0	14.0	
i 1	43.76534013605442	0.2525	69	693	4	4	6	0	0	-1	0	0	0	14.0	
i 1	43.76758503401361	0.7575000000000001	72	195	6	9	2	0	0	0	0	0	0	13.0	
i 1	43.98166666666667	0.505	72	75	7	1	15	0	0	-1	0	0	0	9.0	
i 1	43.98765306122449	0.505	77	195	6	1	4	17	0	1	17	0	0	9.0	
i 1	44.01085034013605	0.505	69	75	7	1	16	1	0	-1	1	0	0	9.0	
i 1	44.011598639455784	0.505	72	75	5	5	2	1	0	0	1	0	0	11.0	
i 1	44.233163265306125	1.5150000000000001	74	693	4	5	16	16	0	2	16	0	0	11.0	
i 1	44.256360544217685	0.2525	74	195	6	5	1	16	0	1	16	0	0	11.0	
i 1	44.26534013605442	0.505	69	195	6	9	3	0	0	-1	0	0	0	13.0	
i 1	44.26833333333333	0.7575000000000001	77	693	5	5	5	17	0	2	17	0	0	11.0	
i 1	44.485408163265305	0.7575000000000001	69	693	4	4	12	0	0	-1	0	0	0	14.0	
i 1	44.496632653061226	0.2525	76	693	3	24	7	17	0	2	17	0	0	5.999999999999998	
i 1	44.49962585034014	0.2525	73	693	3	24	13	17	0	2	17	0	0	5.999999999999998	
i 1	44.51534013605442	0.7575000000000001	72	693	4	4	8	0	0	0	0	0	0	14.0	
i 1	44.516836734693875	0.7575000000000001	74	693	5	5	15	17	0	2	17	0	0	11.0	
i 1	44.733163265306125	0.505	77	195	7	5	8	17	0	2	17	0	0	11.0	
i 1	44.748877551020406	0.505	72	75	6	5	2	1	0	-1	1	0	0	11.0	
i 1	44.74962585034014	0.505	74	693	6	5	5	16	0	1	16	0	0	11.0	
i 1	44.75486394557823	0.505	77	693	4	24	16	16	0	1	16	0	0	12.0	
i 1	44.75561224489796	0.505	77	693	4	24	6	16	0	2	16	0	0	12.0	
i 1	44.98765306122449	0.505	76	693	3	24	15	17	0	2	17	0	0	5.999999999999998	
i 1	44.98989795918367	0.7575000000000001	72	195	6	9	3	0	0	0	0	0	0	13.0	
i 1	44.9906462585034	0.2525	72	75	7	1	2	0	0	-1	0	0	0	9.0	
i 1	44.9906462585034	0.7575000000000001	74	195	6	1	5	17	0	1	17	0	0	9.0	
i 1	44.993639455782315	0.505	76	195	4	20	14	17	0	1	17	0	0	1.9999999999999982	
i 1	44.995884353741495	1.01	74	693	6	1	12	17	0	1	17	0	0	9.0	
i 1	45.00261904761905	0.2525	77	195	6	1	10	17	0	1	17	0	0	9.0	
i 1	45.00261904761905	0.505	72	75	5	5	16	1	0	0	1	0	0	11.0	
i 1	45.00710884353742	0.2525	73	693	3	24	14	17	0	2	17	0	0	5.999999999999998	
i 1	45.0093537414966	0.505	69	195	6	9	15	0	0	-1	0	0	0	13.0	
i 1	45.01309523809524	0.505	74	195	6	5	16	16	0	1	16	0	0	11.0	
i 1	45.01534013605442	0.505	72	75	6	2	10	2	0	1	2	0	0	14.0	
i 1	45.01534013605442	0.7575000000000001	69	693	5	3	16	0	0	0	0	0	0	14.0	
i 1	45.01758503401361	0.505	72	75	6	2	5	2	0	-2	2	0	0	14.0	
i 1	45.01833333333333	0.7575000000000001	69	75	7	1	15	1	0	-1	1	0	0	9.0	
i 1	45.23765306122449	0.2525	71	75	4	20	1	2	0	1	2	0	0	1.9999999999999982	
i 1	45.25261904761905	0.2525	73	693	4	20	10	17	0	2	17	0	0	1.9999999999999982	
i 1	45.25785714285714	0.505	69	693	5	3	10	0	0	-1	0	0	0	14.0	
i 1	45.48391156462585	0.505	73	195	4	24	13	16	0	1	16	0	0	5.999999999999998	
i 1	45.4906462585034	0.505	73	693	3	24	14	16	0	1	16	0	0	5.999999999999998	
i 1	45.493639455782315	0.505	73	693	3	20	12	17	0	2	17	0	0	1.9999999999999982	
i 1	45.498877551020406	0.505	74	195	4	20	2	2	0	-2	2	0	0	1.9999999999999982	
i 1	45.50261904761905	0.2525	77	693	5	5	14	17	0	2	17	0	0	11.0	
i 1	45.51234693877551	0.505	74	693	4	1	16	17	0	1	17	0	0	9.0	
i 1	45.73241496598639	0.505	77	195	7	5	1	17	0	2	17	0	0	11.0	
i 1	45.73914965986395	0.505	72	693	4	4	9	0	0	0	0	0	0	14.0	
i 1	45.7406462585034	0.505	72	75	6	5	13	1	0	-1	1	0	0	11.0	
i 1	45.76309523809524	0.505	69	693	4	4	10	0	0	-1	0	0	0	14.0	
i 1	45.98241496598639	0.2525	72	195	6	9	6	0	0	0	0	0	0	13.0	
i 1	46.00261904761905	0.2525	72	75	7	1	6	0	0	-1	0	0	0	9.0	
i 1	46.00261904761905	0.2525	72	75	6	2	6	2	0	1	2	0	0	14.0	
i 1	46.004115646258505	0.2525	77	195	6	1	14	17	0	1	17	0	0	9.0	
i 1	46.004115646258505	0.2525	71	75	4	20	16	8	0	-2	8	0	0	1.9999999999999982	
i 1	46.00561224489796	0.2525	76	195	4	20	4	17	0	1	17	0	0	1.9999999999999982	
i 1	46.00860544217687	0.7575000000000001	72	75	6	2	13	2	0	-2	2	0	0	14.0	
i 1	46.01309523809524	0.7575000000000001	73	693	4	20	9	17	0	2	17	0	0	1.9999999999999982	
i 1	46.01608843537415	0.7575000000000001	69	195	6	9	6	0	0	-1	0	0	0	13.0	
i 1	46.01758503401361	1.2625	76	693	3	24	11	17	0	2	17	0	0	5.999999999999998	
i 1	46.23465986394558	0.2525	69	693	5	3	3	0	0	-1	0	0	0	14.0	
i 1	46.236156462585036	0.2525	74	195	6	1	14	17	0	1	17	0	0	9.0	
i 1	46.236156462585036	0.2525	74	195	6	5	12	16	0	1	16	0	0	11.0	
i 1	46.245884353741495	0.505	73	693	4	24	16	17	0	2	17	0	0	5.999999999999998	
i 1	46.25710884353742	1.2625	73	195	4	24	12	16	0	1	16	0	0	5.999999999999998	
i 1	46.25785714285714	1.01	77	693	4	24	12	16	0	2	16	0	0	12.0	
i 1	46.25785714285714	0.2525	72	75	5	5	12	1	0	0	1	0	0	11.0	
i 1	46.26608843537415	0.2525	69	75	7	1	11	1	0	-1	1	0	0	9.0	
i 1	46.495884353741495	0.2525	74	693	4	5	13	16	0	2	16	0	0	11.0	
i 1	46.49812925170068	0.2525	74	693	4	1	9	17	0	1	17	0	0	9.0	
i 1	46.503367346938774	0.2525	74	693	6	1	13	17	0	1	17	0	0	9.0	
i 1	46.511598639455784	0.2525	77	693	5	5	4	17	0	2	17	0	0	11.0	
i 1	46.51309523809524	0.2525	76	195	4	20	7	17	0	1	17	0	0	1.9999999999999982	
i 1	46.514591836734695	0.2525	74	693	6	5	9	16	0	1	16	0	0	11.0	
i 1	46.514591836734695	0.2525	71	75	4	20	4	8	0	-2	8	0	0	1.9999999999999982	
i 1	46.733163265306125	0.505	77	693	4	24	2	16	0	1	16	0	0	12.0	
i 1	46.738401360544216	0.2525	74	693	5	5	1	17	0	2	17	0	0	11.0	
i 1	46.73914965986395	0.2525	74	693	4	5	7	16	0	1	16	0	0	11.0	
i 1	46.73989795918367	0.505	73	693	3	24	1	17	0	2	17	0	0	5.999999999999998	
i 1	46.74289115646258	0.505	77	195	6	1	7	17	0	1	17	0	0	9.0	
i 1	46.74438775510204	0.2525	72	693	4	4	14	0	0	0	0	0	0	14.0	
i 1	46.75261904761905	0.7575000000000001	71	195	4	20	13	2	0	1	2	0	0	1.9999999999999982	
i 1	46.75785714285714	3.2825	60	75	6	13	15	0	0	0	0	0	0	8.0	
i 1	46.764591836734695	3.2825	61	693	5	15	9	9	0	1	9	0	0	9.0	
i 1	46.98465986394558	0.2525	72	75	7	1	10	0	0	-1	0	0	0	9.0	
i 1	46.99289115646258	0.505	74	195	6	1	11	17	0	1	17	0	0	9.0	
i 1	46.996632653061226	0.505	69	195	6	9	9	0	0	-1	0	0	0	13.0	
i 1	47.001122448979594	0.505	72	75	6	5	3	1	0	-1	1	0	0	11.0	
i 1	47.00187074829932	0.505	69	75	7	1	13	1	0	-1	1	0	0	9.0	
i 1	47.004115646258505	1.2625	73	693	3	20	3	17	0	2	17	0	0	1.9999999999999982	
i 1	47.014591836734695	0.2525	72	75	6	2	9	2	0	1	2	0	0	14.0	
i 1	47.016836734693875	0.505	77	195	7	5	2	17	0	2	17	0	0	11.0	
i 1	47.01758503401361	1.2625	73	693	3	24	8	16	0	1	16	0	0	5.999999999999998	
i 1	47.23391156462585	0.2525	72	75	6	5	4	1	0	0	1	0	0	11.0	
i 1	47.23914965986395	0.505	77	693	5	5	7	17	0	2	17	0	0	11.0	
i 1	47.26309523809524	0.2525	74	195	7	5	10	16	0	1	16	0	0	11.0	
i 1	47.26833333333333	0.505	74	693	4	5	5	16	0	2	16	0	0	11.0	
i 1	47.49513605442177	0.7575000000000001	73	693	3	24	6	17	0	2	17	0	0	5.999999999999998	
i 1	47.50860544217687	0.505	74	693	5	1	6	17	0	1	17	0	0	9.0	
i 1	47.511598639455784	0.505	74	693	6	1	6	17	0	1	17	0	0	9.0	
i 1	47.51534013605442	1.01	76	693	3	24	8	17	0	2	17	0	0	5.999999999999998	
i 1	47.516836734693875	0.2525	69	693	5	3	12	0	0	0	0	0	0	14.0	
i 1	47.73989795918367	0.505	72	75	7	1	9	0	0	-1	0	0	0	9.0	
i 1	47.75037414965986	0.7575000000000001	77	195	7	5	9	17	0	2	17	0	0	11.0	
i 1	47.75561224489796	0.2525	73	195	4	24	3	16	0	1	16	0	0	5.999999999999998	
i 1	47.76085034013605	0.2525	72	693	4	4	10	0	0	0	0	0	0	14.0	
i 1	47.76608843537415	0.505	72	75	6	2	13	2	0	1	2	0	0	14.0	
i 1	47.766836734693875	0.2525	71	195	4	20	4	2	0	1	2	0	0	1.9999999999999982	
i 1	47.76833333333333	0.7575000000000001	72	75	6	5	11	1	0	-1	1	0	0	11.0	
i 1	47.9906462585034	0.505	73	195	1	24	16	16	0	248	16	308	0	5.999999999999998	
i 1	48.00785714285714	0.2525	77	195	6	1	4	17	0	1	17	0	0	9.0	
i 1	48.01608843537415	0.2525	72	195	6	9	11	0	0	0	0	0	0	13.0	
i 1	48.23166666666667	0.505	74	693	4	5	12	16	0	2	16	0	0	11.0	
i 1	48.23465986394558	0.2525	74	195	7	5	16	16	0	1	16	0	0	11.0	
i 1	48.23465986394558	0.2525	71	75	4	20	13	8	0	1	8	0	0	1.9999999999999982	
i 1	48.23989795918367	0.505	77	693	5	5	9	17	0	2	17	0	0	11.0	
i 1	48.243639455782315	0.505	74	195	6	1	14	17	0	1	17	0	0	9.0	
i 1	48.24738095238095	0.2525	72	75	6	5	14	1	0	0	1	0	0	11.0	
i 1	48.24962585034014	0.505	69	75	7	1	11	1	0	-1	1	0	0	9.0	
i 1	48.253367346938774	0.2525	76	195	4	20	13	17	0	1	17	0	0	1.9999999999999982	
i 1	48.26085034013605	1.2625	72	75	6	2	11	2	0	-2	2	0	0	14.0	
i 1	48.26608843537415	0.505	69	195	6	9	16	0	0	-1	0	0	0	13.0	
i 1	48.26608843537415	0.2525	73	693	4	20	14	17	0	2	17	0	0	1.9999999999999982	
i 1	48.483163265306125	0.2525	73	693	3	20	3	17	0	2	17	0	0	1.9999999999999982	
i 1	48.485408163265305	0.2525	74	693	6	1	13	17	0	1	17	0	0	9.0	
i 1	48.49214285714286	0.505	77	693	4	24	9	16	0	2	16	0	0	12.0	
i 1	48.49812925170068	0.505	77	693	4	24	9	16	0	1	16	0	0	12.0	
i 1	48.50187074829932	0.2525	74	693	5	1	13	17	0	1	17	0	0	9.0	
i 1	48.50486394557823	0.505	73	195	4	24	15	16	0	1	16	0	0	5.999999999999998	
i 1	48.51010204081633	0.2525	73	693	3	24	8	16	0	1	16	0	0	5.999999999999998	
i 1	48.7406462585034	0.2525	72	693	4	4	9	0	0	0	0	0	0	14.0	
i 1	48.74214285714286	0.2525	69	693	4	4	4	0	0	-1	0	0	0	14.0	
i 1	48.745884353741495	0.7575000000000001	76	693	3	24	9	17	0	2	17	0	0	5.999999999999998	
i 1	48.75261904761905	0.2525	74	693	5	5	6	17	0	2	17	0	0	11.0	
i 1	48.76534013605442	0.7575000000000001	72	75	6	5	7	1	0	0	1	0	0	11.0	
i 1	48.76608843537415	0.2525	73	693	4	20	8	17	0	2	17	0	0	1.9999999999999982	
i 1	48.76758503401361	0.2525	74	693	4	5	7	16	0	1	16	0	0	11.0	
i 1	48.98391156462585	0.505	72	75	7	1	10	0	0	-1	0	0	0	9.0	
i 1	48.98465986394558	0.2525	72	195	6	9	16	0	0	0	0	0	0	13.0	
i 1	48.98690476190476	0.505	73	693	3	24	8	17	0	2	17	0	0	5.999999999999998	
i 1	48.99812925170068	0.505	77	195	6	1	12	17	0	1	17	0	0	9.0	
i 1	49.00037414965986	0.2525	73	693	3	24	6	16	0	1	16	0	0	5.999999999999998	
i 1	49.001122448979594	0.2525	73	693	3	20	11	17	0	2	17	0	0	1.9999999999999982	
i 1	49.00261904761905	0.2525	72	75	6	2	5	2	0	1	2	0	0	14.0	
i 1	49.00261904761905	0.2525	72	75	6	5	9	1	0	-1	1	0	0	11.0	
i 1	49.01309523809524	0.2525	77	195	7	5	12	17	0	2	17	0	0	11.0	
i 1	49.01534013605442	0.505	69	75	7	1	10	1	0	-1	1	0	0	9.0	
i 1	49.24289115646258	0.7575000000000001	74	693	6	1	15	17	0	1	17	0	0	9.0	
i 1	49.248877551020406	0.7575000000000001	73	195	4	24	1	16	0	1	16	0	0	5.999999999999998	
i 1	49.25037414965986	0.7575000000000001	74	693	5	1	5	17	0	1	17	0	0	9.0	
i 1	49.25261904761905	0.2525	74	195	6	1	13	17	0	1	17	0	0	9.0	
i 1	49.25860544217687	1.01	71	195	4	20	16	8	0	-2	8	0	0	1.9999999999999982	
i 1	49.48166666666667	0.2525	73	693	3	20	9	17	0	2	17	0	0	1.9999999999999982	
i 1	49.49738095238095	0.2525	74	693	4	5	11	16	0	2	16	0	0	11.0	
i 1	49.516836734693875	0.2525	69	693	5	3	9	0	0	-1	0	0	0	14.0	
i 1	49.74139455782313	0.2525	77	195	7	5	5	17	0	2	17	0	0	11.0	
i 1	49.745884353741495	0.2525	76	693	3	24	14	17	0	2	17	0	0	5.999999999999998	
i 1	49.74738095238095	0.2525	69	693	4	4	12	0	0	-1	0	0	0	14.0	
i 1	49.75486394557823	0.2525	73	693	3	24	7	17	0	2	17	0	0	5.999999999999998	
i 1	49.7593537414966	0.2525	72	693	4	4	6	0	0	0	0	0	0	14.0	
i 1	49.985408163265305	0.505	75	195	6	2	8	2	0	1	2	0	0	14.0	
i 1	49.98765306122449	0.2525	69	195	7	1	9	0	0	-1	0	0	0	9.0	
i 1	49.98914965986395	0.2525	72	581	5	1	15	1	0	0	1	0	0	9.0	
i 1	49.9906462585034	0.505	72	897	6	1	7	0	0	0	0	0	0	9.0	
i 1	49.99289115646258	1.01	67	897	5	15	2	5	0	0	5	0	0	9.0	
i 1	49.99738095238095	1.01	67	195	6	14	10	5	0	1	5	0	0	11.0	
i 1	50.00561224489796	0.2525	74	195	4	20	8	8	0	-2	8	0	0	1.9999999999999982	
i 1	50.00710884353742	0.2525	72	581	5	5	15	0	0	-1	0	0	0	11.0	
i 1	50.00710884353742	0.2525	76	195	4	20	2	17	0	1	17	0	0	1.9999999999999982	
i 1	50.00860544217687	0.505	69	897	4	5	10	1	0	0	1	0	0	11.0	
i 1	50.0093537414966	0.505	72	581	5	3	6	2	0	-2	2	0	0	14.0	
i 1	50.013843537414964	5.3025	60	195	6	13	9	0	0	0	0	0	0	8.0	
i 1	50.23391156462585	0.2525	74	581	3	24	10	2	0	1	2	0	0	5.999999999999998	
i 1	50.24139455782313	1.01	71	581	3	24	9	2	0	1	2	0	0	5.999999999999998	
i 1	50.24139455782313	1.01	73	195	4	24	8	16	0	1	16	0	0	5.999999999999998	
i 1	50.26608843537415	0.2525	69	581	4	24	10	1	0	0	1	0	0	12.0	
i 1	50.483163265306125	0.2525	72	195	6	9	11	0	0	0	0	0	0	13.0	
i 1	50.49738095238095	0.2525	74	195	4	20	8	8	0	-2	8	0	0	1.9999999999999982	
i 1	50.501122448979594	0.2525	72	897	4	24	15	0	0	-1	0	0	0	12.0	
i 1	50.50261904761905	0.2525	77	195	7	5	13	17	0	2	17	0	0	11.0	
i 1	50.50710884353742	0.2525	72	897	4	4	6	2	0	-2	2	0	0	14.0	
i 1	50.73690476190476	0.2525	69	195	6	9	5	0	0	-1	0	0	0	13.0	
i 1	50.74214285714286	0.2525	74	581	3	24	1	2	0	1	2	0	0	5.999999999999998	
i 1	50.743639455782315	0.2525	74	195	6	1	1	17	0	1	17	0	0	9.0	
i 1	50.74962585034014	0.2525	69	195	6	5	10	1	0	0	1	0	0	11.0	
i 1	50.75037414965986	0.2525	75	195	6	2	6	8	0	1	8	0	0	14.0	
i 1	50.76309523809524	0.2525	71	581	3	20	9	2	0	1	2	0	0	1.9999999999999982	
i 1	50.98465986394558	4.2925	60	897	5	15	8	0	0	0	0	0	0	9.0	
i 1	50.98914965986395	8.585	67	897	5	15	8	5	0	0	5	0	0	9.0	
i 1	50.99513605442177	0.2525	75	195	6	2	7	2	0	1	2	0	0	14.0	
i 1	51.00785714285714	0.2525	69	195	7	1	10	0	0	-1	0	0	0	9.0	
i 1	51.014591836734695	0.2525	69	195	6	5	3	1	0	-1	1	0	0	11.0	
i 1	51.01534013605442	0.2525	72	581	5	1	15	1	0	0	1	0	0	9.0	
i 1	51.01833333333333	4.2925	67	195	6	14	6	5	0	1	5	0	0	11.0	
i 1	51.236156462585036	0.2525	69	897	5	5	2	1	0	0	1	0	0	11.0	
i 1	51.23765306122449	0.505	72	897	4	4	1	2	0	-2	2	0	0	14.0	
i 1	51.238401360544216	0.2525	69	581	5	5	15	1	0	-1	1	0	0	11.0	
i 1	51.23914965986395	1.01	71	195	4	20	9	8	0	-2	8	0	0	1.9999999999999982	
i 1	51.2406462585034	0.7575000000000001	69	195	6	5	10	1	0	0	1	0	0	11.0	
i 1	51.24214285714286	1.01	76	195	4	20	9	17	0	1	17	0	0	1.9999999999999982	
i 1	51.24214285714286	0.2525	74	581	3	24	11	2	0	1	2	0	0	5.999999999999998	
i 1	51.246632653061226	0.505	72	897	6	1	16	0	0	0	0	0	0	9.0	
i 1	51.26309523809524	0.2525	71	581	3	20	12	2	0	1	2	0	0	1.9999999999999982	
i 1	51.26608843537415	0.505	69	581	4	24	14	1	0	0	1	0	0	12.0	
i 1	51.26758503401361	0.2525	75	581	4	4	13	2	0	1	2	0	0	14.0	
i 1	51.51085034013605	0.505	74	195	7	5	12	16	0	1	16	0	0	11.0	
i 1	51.51534013605442	0.2525	71	581	3	24	13	2	0	1	2	0	0	5.999999999999998	
i 1	51.51608843537415	0.2525	73	195	4	24	12	16	0	1	16	0	0	5.999999999999998	
i 1	51.73465986394558	0.2525	69	195	6	9	12	0	0	-1	0	0	0	13.0	
i 1	51.736156462585036	0.2525	71	581	3	20	3	2	0	1	2	0	0	1.9999999999999982	
i 1	51.7406462585034	0.2525	72	195	7	1	15	0	0	0	0	0	0	9.0	
i 1	51.74738095238095	0.2525	75	195	6	2	8	8	0	1	8	0	0	14.0	
i 1	51.74962585034014	0.2525	74	195	6	1	6	17	0	1	17	0	0	9.0	
i 1	51.985408163265305	0.505	75	195	6	2	13	2	0	1	2	0	0	14.0	
i 1	51.99289115646258	0.2525	72	581	5	1	9	1	0	0	1	0	0	9.0	
i 1	51.998877551020406	0.2525	72	581	6	5	16	0	0	-1	0	0	0	11.0	
i 1	52.006360544217685	0.2525	69	195	6	5	13	1	0	-1	1	0	0	11.0	
i 1	52.0093537414966	0.505	72	581	5	3	5	2	0	-2	2	0	0	14.0	
i 1	52.01608843537415	0.2525	69	195	7	1	4	0	0	-1	0	0	0	9.0	
i 1	52.01608843537415	0.2525	74	195	4	20	11	8	0	-2	8	0	0	1.9999999999999982	
i 1	52.23241496598639	0.2525	71	581	3	20	4	2	0	1	2	0	0	1.9999999999999982	
i 1	52.246632653061226	0.2525	69	897	5	5	13	1	0	0	1	0	0	11.0	
i 1	52.25037414965986	0.2525	69	581	5	5	3	1	0	-1	1	0	0	11.0	
i 1	52.251122448979594	0.2525	69	581	4	24	1	1	0	0	1	0	0	12.0	
i 1	52.25785714285714	1.5150000000000001	73	195	4	24	1	16	0	1	16	0	0	5.999999999999998	
i 1	52.26534013605442	0.7575000000000001	71	581	3	24	6	2	0	1	2	0	0	5.999999999999998	
i 1	52.486156462585036	0.2525	72	897	4	4	13	2	0	-2	2	0	0	14.0	
i 1	52.48914965986395	0.505	72	195	7	1	15	0	0	0	0	0	0	9.0	
i 1	52.49438775510204	0.2525	72	195	5	9	8	0	0	0	0	0	0	13.0	
i 1	52.495884353741495	0.2525	72	897	4	24	3	0	0	-1	0	0	0	12.0	
i 1	52.504115646258505	0.505	69	195	6	5	14	1	0	0	1	0	0	11.0	
i 1	52.50561224489796	0.2525	74	195	4	20	4	8	0	-2	8	0	0	1.9999999999999982	
i 1	52.51010204081633	0.505	75	195	6	2	1	8	0	1	8	0	0	14.0	
i 1	52.51534013605442	0.2525	77	195	4	5	9	17	0	2	17	0	0	11.0	
i 1	52.748877551020406	0.2525	69	195	6	9	2	0	0	-1	0	0	0	13.0	
i 1	52.75187074829932	0.2525	71	581	3	20	16	2	0	1	2	0	0	1.9999999999999982	
i 1	52.99214285714286	1.01	71	195	4	20	8	8	0	-2	8	0	0	1.9999999999999982	
i 1	52.99962585034014	0.2525	75	195	6	2	14	2	0	1	2	0	0	14.0	
i 1	53.001122448979594	0.2525	72	581	6	5	13	0	0	-1	0	0	0	11.0	
i 1	53.003367346938774	0.2525	69	195	7	1	10	0	0	-1	0	0	0	9.0	
i 1	53.006360544217685	0.2525	74	581	3	24	10	8	0	-2	8	0	0	5.999999999999998	
i 1	53.00785714285714	0.2525	72	581	5	1	7	1	0	0	1	0	0	9.0	
i 1	53.23914965986395	0.505	69	581	4	24	9	1	0	0	1	0	0	12.0	
i 1	53.245884353741495	0.2525	73	897	4	24	1	8	0	-1	8	0	0	5.999999999999998	
i 1	53.254115646258505	0.2525	69	897	5	5	5	1	0	0	1	0	0	11.0	
i 1	53.25561224489796	0.2525	69	581	5	5	2	1	0	-1	1	0	0	11.0	
i 1	53.25710884353742	0.2525	75	581	4	4	6	2	0	1	2	0	0	14.0	
i 1	53.261598639455784	0.505	72	897	6	1	11	0	0	0	0	0	0	9.0	
i 1	53.483163265306125	0.505	69	195	6	5	4	1	0	0	1	0	0	11.0	
i 1	53.49139455782313	0.2525	72	897	4	4	11	2	0	-2	2	0	0	14.0	
i 1	53.498877551020406	0.505	74	195	7	5	2	16	0	1	16	0	0	11.0	
i 1	53.73690476190476	0.505	69	195	6	5	16	1	0	-1	1	0	0	11.0	
i 1	53.738401360544216	0.505	69	195	7	1	16	0	0	-1	0	0	0	9.0	
i 1	53.73914965986395	0.7575000000000001	75	195	6	2	15	2	0	1	2	0	0	14.0	
i 1	53.746632653061226	0.2525	74	581	3	24	15	2	0	1	2	0	0	5.999999999999998	
i 1	53.74812925170068	0.2525	74	195	6	1	3	17	0	1	17	0	0	9.0	
i 1	53.748877551020406	0.2525	75	195	6	2	6	8	0	1	8	0	0	14.0	
i 1	53.75037414965986	0.2525	72	195	7	1	10	0	0	0	0	0	0	9.0	
i 1	53.75037414965986	0.2525	69	195	6	9	15	0	0	-1	0	0	0	13.0	
i 1	53.76608843537415	0.2525	76	195	4	20	11	17	0	1	17	0	0	1.9999999999999982	
i 1	53.98241496598639	0.2525	72	581	5	1	4	1	0	0	1	0	0	9.0	
i 1	53.99962585034014	0.505	72	581	5	3	7	2	0	-2	2	0	0	14.0	
i 1	54.004115646258505	0.2525	74	581	3	24	1	8	0	-2	8	0	0	5.999999999999998	
i 1	54.00710884353742	0.2525	72	581	6	5	2	0	0	-1	0	0	0	11.0	
i 1	54.0093537414966	0.2525	70	581	3	24	6	2	0	-2	2	0	0	5.999999999999998	
i 1	54.014591836734695	0.2525	73	195	4	24	8	16	0	1	16	0	0	5.999999999999998	
i 1	54.2406462585034	0.2525	70	581	3	20	2	2	0	-1	2	0	0	1.9999999999999982	
i 1	54.25261904761905	0.2525	72	897	6	1	8	0	0	0	0	0	0	9.0	
i 1	54.261598639455784	0.2525	69	897	5	5	12	1	0	0	1	0	0	11.0	
i 1	54.26234693877551	0.2525	69	581	5	5	7	1	0	-1	1	0	0	11.0	
i 1	54.26833333333333	0.2525	71	195	4	20	7	8	0	-2	8	0	0	1.9999999999999982	
i 1	54.483163265306125	0.2525	72	897	4	5	6	0	0	0	0	0	0	11.0	
i 1	54.48391156462585	0.2525	72	195	5	9	15	0	0	0	0	0	0	13.0	
i 1	54.50187074829932	0.2525	77	195	6	1	16	17	0	1	17	0	0	9.0	
i 1	54.50785714285714	0.2525	72	897	4	4	7	2	0	-2	2	0	0	14.0	
i 1	54.743639455782315	0.2525	69	195	6	9	16	0	0	-1	0	0	0	13.0	
i 1	54.745884353741495	0.2525	74	581	3	24	3	2	0	1	2	0	0	5.999999999999998	
i 1	54.74962585034014	1.2625	71	195	4	20	11	8	0	-2	8	0	0	1.9999999999999982	
i 1	54.75037414965986	0.2525	74	195	7	5	10	16	0	1	16	0	0	11.0	
i 1	54.75561224489796	0.2525	72	195	7	1	1	0	0	0	0	0	0	9.0	
i 1	54.75561224489796	0.7575000000000001	76	195	4	20	11	17	0	1	17	0	0	1.9999999999999982	
i 1	54.76085034013605	0.2525	75	195	6	2	15	8	0	1	8	0	0	14.0	
i 1	54.98914965986395	0.2525	69	195	7	1	2	0	0	-1	0	0	0	9.0	
i 1	54.98914965986395	0.505	69	897	5	5	12	1	0	0	1	0	0	11.0	
i 1	54.99438775510204	0.2525	70	581	3	24	5	2	0	-2	2	0	0	5.999999999999998	
i 1	54.99812925170068	0.505	72	897	5	3	16	2	0	1	2	0	0	14.0	
i 1	54.998877551020406	0.2525	72	581	6	5	9	0	0	-1	0	0	0	11.0	
i 1	55.00037414965986	0.2525	72	581	5	1	7	1	0	0	1	0	0	9.0	
i 1	55.00187074829932	0.2525	72	581	5	3	2	2	0	-2	2	0	0	14.0	
i 1	55.00785714285714	0.7575000000000001	73	195	4	24	3	16	0	1	16	0	0	5.999999999999998	
i 1	55.016836734693875	0.7575000000000001	72	897	6	1	13	0	0	0	0	0	0	9.0	
i 1	55.23166666666667	8.585	60	897	5	15	14	0	0	0	0	0	0	9.0	
i 1	55.253367346938774	3.2825	60	195	6	13	6	0	0	0	0	0	0	8.0	
i 1	55.254115646258505	3.2825	67	195	6	14	7	5	0	1	5	0	0	11.0	
i 1	55.25860544217687	0.505	69	581	4	24	8	1	0	0	1	0	0	12.0	
i 1	55.26309523809524	4.2925	66	195	5	16	8	6	0	2	6	0	0	10.0	
i 1	55.264591836734695	0.2525	69	581	6	5	8	1	0	-1	1	0	0	11.0	
i 1	55.483163265306125	0.505	74	195	4	5	12	16	0	1	16	0	0	11.0	
i 1	55.49139455782313	0.2525	72	897	4	4	6	2	0	-2	2	0	0	14.0	
i 1	55.49513605442177	0.505	69	195	6	5	8	1	0	0	1	0	0	11.0	
i 1	55.516836734693875	0.2525	74	581	3	24	16	8	0	-2	8	0	0	5.999999999999998	
i 1	55.74214285714286	0.2525	75	195	6	2	8	8	0	1	8	0	0	14.0	
i 1	55.74214285714286	0.2525	69	195	5	9	6	0	0	-1	0	0	0	13.0	
i 1	55.74289115646258	0.2525	74	581	3	24	10	2	0	1	2	0	0	5.999999999999998	
i 1	55.74513605442177	0.2525	74	195	6	1	12	17	0	1	17	0	0	9.0	
i 1	55.75561224489796	0.2525	72	195	7	1	3	0	0	0	0	0	0	9.0	
i 1	55.756360544217685	0.2525	73	581	3	20	4	2	0	-1	2	0	0	1.9999999999999982	
i 1	55.998877551020406	0.2525	72	581	5	1	9	1	0	0	1	0	0	9.0	
i 1	55.99962585034014	0.2525	73	195	4	24	4	16	0	1	16	0	0	5.999999999999998	
i 1	56.001122448979594	0.2525	69	195	7	1	14	0	0	-1	0	0	0	9.0	
i 1	56.00187074829932	0.2525	72	581	6	5	11	0	0	-1	0	0	0	11.0	
i 1	56.011598639455784	0.2525	69	195	6	5	11	1	0	-1	1	0	0	11.0	
i 1	56.014591836734695	0.505	72	581	5	3	8	2	0	-2	2	0	0	14.0	
i 1	56.01758503401361	0.505	75	195	6	2	14	2	0	1	2	0	0	14.0	
i 1	56.23391156462585	0.2525	69	581	6	5	6	1	0	-1	1	0	0	11.0	
i 1	56.235408163265305	0.2525	74	581	3	24	11	2	0	1	2	0	0	5.999999999999998	
i 1	56.24139455782313	0.505	72	897	4	24	9	0	0	-1	0	0	0	12.0	
i 1	56.24812925170068	0.505	72	897	4	4	8	2	0	-2	2	0	0	14.0	
i 1	56.248877551020406	0.2525	76	195	4	20	8	17	0	1	17	0	0	1.9999999999999982	
i 1	56.254115646258505	0.7575000000000001	71	195	4	20	2	8	0	-2	8	0	0	1.9999999999999982	
i 1	56.256360544217685	0.2525	69	581	4	24	7	1	0	0	1	0	0	12.0	
i 1	56.261598639455784	0.505	72	897	5	5	4	0	0	0	0	0	0	11.0	
i 1	56.266836734693875	0.2525	69	897	5	5	10	1	0	0	1	0	0	11.0	
i 1	56.49962585034014	0.2525	73	897	4	20	2	8	0	-2	8	0	0	1.9999999999999982	
i 1	56.506360544217685	0.2525	72	195	5	9	9	0	0	0	0	0	0	13.0	
i 1	56.5093537414966	0.2525	73	195	4	24	13	16	0	1	16	0	0	5.999999999999998	
i 1	56.736156462585036	0.2525	75	195	6	2	13	8	0	1	8	0	0	14.0	
i 1	56.73765306122449	0.2525	72	195	7	1	2	0	0	0	0	0	0	9.0	
i 1	56.74139455782313	0.2525	70	581	3	20	1	8	0	-2	8	0	0	1.9999999999999982	
i 1	56.74214285714286	0.2525	74	581	3	24	15	2	0	1	2	0	0	5.999999999999998	
i 1	56.75261904761905	0.2525	69	195	5	9	2	0	0	-1	0	0	0	13.0	
i 1	56.76534013605442	0.2525	74	195	4	5	15	16	0	1	16	0	0	11.0	
i 1	56.9906462585034	0.2525	72	581	5	1	1	1	0	0	1	0	0	9.0	
i 1	56.99738095238095	0.2525	72	581	5	3	12	2	0	-2	2	0	0	14.0	
i 1	57.0093537414966	0.2525	74	195	4	20	9	8	0	-2	8	0	0	1.9999999999999982	
i 1	57.01085034013605	0.2525	69	195	7	1	1	0	0	-1	0	0	0	9.0	
i 1	57.016836734693875	0.2525	73	195	4	24	1	16	0	1	16	0	0	5.999999999999998	
i 1	57.01833333333333	0.2525	72	581	6	5	4	0	0	-1	0	0	0	11.0	
i 1	57.24139455782313	0.2525	69	581	6	5	4	1	0	-1	1	0	0	11.0	
i 1	57.256360544217685	0.505	69	581	4	24	13	1	0	0	1	0	0	12.0	
i 1	57.25785714285714	0.2525	72	897	5	3	16	2	0	1	2	0	0	14.0	
i 1	57.2593537414966	0.2525	76	195	4	20	9	17	0	1	17	0	0	1.9999999999999982	
i 1	57.26085034013605	0.2525	71	195	4	20	11	8	0	-2	8	0	0	1.9999999999999982	
i 1	57.26309523809524	0.505	72	897	6	1	3	0	0	0	0	0	0	9.0	
i 1	57.264591836734695	0.2525	69	897	5	5	10	1	0	0	1	0	0	11.0	
i 1	57.26758503401361	0.2525	74	581	3	24	9	2	0	1	2	0	0	5.999999999999998	
i 1	57.48765306122449	0.505	75	195	6	2	4	8	0	1	8	0	0	14.0	
i 1	57.48765306122449	0.505	74	195	4	5	16	16	0	1	16	0	0	11.0	
i 1	57.4906462585034	0.2525	72	897	4	4	14	2	0	-2	2	0	0	14.0	
i 1	57.495884353741495	0.505	72	195	7	1	9	0	0	0	0	0	0	9.0	
i 1	57.516836734693875	0.505	69	195	6	5	10	1	0	0	1	0	0	11.0	
i 1	57.735408163265305	0.2525	70	581	3	20	15	8	0	-2	8	0	0	1.9999999999999982	
i 1	57.738401360544216	0.2525	69	195	5	9	10	0	0	-1	0	0	0	13.0	
i 1	57.73914965986395	0.2525	71	195	4	20	8	8	0	-2	8	0	0	1.9999999999999982	
i 1	57.746632653061226	0.2525	76	195	4	20	2	17	0	1	17	0	0	1.9999999999999982	
i 1	57.75187074829932	0.2525	74	195	6	1	15	17	0	1	17	0	0	9.0	
i 1	57.98241496598639	0.2525	74	581	3	24	1	8	0	-2	8	0	0	5.999999999999998	
i 1	57.986156462585036	0.505	75	195	6	2	13	2	0	1	2	0	0	14.0	
i 1	57.988401360544216	0.505	72	581	5	3	1	2	0	-2	2	0	0	14.0	
i 1	57.9906462585034	0.2525	74	195	4	20	1	8	0	-2	8	0	0	1.9999999999999982	
i 1	57.99962585034014	0.2525	69	195	6	5	5	1	0	-1	1	0	0	11.0	
i 1	58.00486394557823	0.2525	69	195	7	1	14	0	0	-1	0	0	0	9.0	
i 1	58.00561224489796	0.2525	72	581	5	1	14	1	0	0	1	0	0	9.0	
i 1	58.01085034013605	0.2525	72	581	6	5	16	0	0	-1	0	0	0	11.0	
i 1	58.01758503401361	0.2525	70	581	3	24	16	8	0	-1	8	0	0	5.999999999999998	
i 1	58.23989795918367	0.2525	69	581	4	24	9	1	0	0	1	0	0	12.0	
i 1	58.25037414965986	0.2525	69	581	6	5	10	1	0	-1	1	0	0	11.0	
i 1	58.25486394557823	0.2525	76	195	4	20	8	17	0	1	17	0	0	1.9999999999999982	
i 1	58.25860544217687	0.2525	69	897	5	5	10	1	0	0	1	0	0	11.0	
i 1	58.26309523809524	0.2525	70	581	3	20	2	8	0	-2	8	0	0	1.9999999999999982	
i 1	58.26309523809524	0.2525	74	581	3	24	4	2	0	1	2	0	0	5.999999999999998	
i 1	58.48166666666667	5.3025	61	399	5	14	2	9	0	0	9	0	0	11.0	
i 1	58.48241496598639	0.505	72	399	6	5	7	8	0	-2	8	0	0	11.0	
i 1	58.48465986394558	0.2525	74	399	6	2	9	16	0	1	16	0	0	14.0	
i 1	58.4906462585034	0.505	71	399	6	1	2	8	0	-1	8	0	0	9.0	
i 1	58.495884353741495	1.01	66	399	5	13	13	9	0	0	9	0	0	8.0	
i 1	58.496632653061226	0.2525	73	195	4	24	15	16	0	1	16	0	0	5.999999999999998	
i 1	58.50037414965986	0.2525	72	195	5	9	10	0	0	0	0	0	0	13.0	
i 1	58.50037414965986	0.2525	77	195	4	5	11	17	0	2	17	0	0	11.0	
i 1	58.501122448979594	0.2525	71	399	6	1	8	8	0	-2	8	0	0	9.0	
i 1	58.50261904761905	0.2525	70	399	4	20	14	2	0	-2	2	0	0	1.9999999999999982	
i 1	58.50710884353742	0.7575000000000001	77	399	6	2	4	16	0	1	16	0	0	14.0	
i 1	58.51309523809524	0.2525	70	897	4	20	3	8	0	-2	8	0	0	1.9999999999999982	
i 1	58.735408163265305	0.2525	73	897	4	24	6	2	0	-2	2	0	0	5.999999999999998	
i 1	58.74139455782313	0.2525	74	581	3	24	12	2	0	1	2	0	0	5.999999999999998	
i 1	58.74513605442177	0.7575000000000001	74	581	1	24	1	8	0	252	8	307	0	5.999999999999998	
i 1	58.766836734693875	0.505	69	195	5	9	10	0	0	-1	0	0	0	13.0	
i 1	58.986156462585036	0.2525	73	195	4	24	16	16	0	1	16	0	0	5.999999999999998	
i 1	58.99139455782313	0.2525	72	581	6	5	5	0	0	-1	0	0	0	11.0	
i 1	59.01833333333333	0.2525	69	581	4	24	16	1	0	0	1	0	0	12.0	
i 1	59.245884353741495	0.2525	72	897	6	1	5	0	0	0	0	0	0	9.0	
i 1	59.254115646258505	0.2525	73	581	3	20	5	8	0	-1	8	0	0	1.9999999999999982	
i 1	59.25561224489796	0.2525	75	581	4	4	11	2	0	1	2	0	0	14.0	
i 1	59.25860544217687	0.2525	76	195	4	20	12	17	0	1	17	0	0	1.9999999999999982	
i 1	59.263843537414964	0.2525	73	195	4	20	1	8	0	-2	8	0	0	1.9999999999999982	
i 1	59.266836734693875	0.2525	72	897	4	4	16	2	0	-2	2	0	0	14.0	
i 1	59.266836734693875	0.505	72	399	6	5	9	8	0	-2	8	0	0	11.0	
i 1	59.483163265306125	4.2925	66	195	5	16	3	6	0	2	6	0	0	10.0	
i 1	59.48765306122449	0.2525	72	195	5	9	10	0	0	0	0	0	0	13.0	
i 1	59.48914965986395	4.2925	66	399	5	13	6	9	0	0	9	0	0	8.0	
i 1	59.48989795918367	4.2925	61	195	5	16	16	9	0	1	9	0	0	10.0	
i 1	59.4906462585034	0.2525	74	581	3	24	7	8	0	-2	8	0	0	5.999999999999998	
i 1	59.493639455782315	0.2525	73	195	4	20	2	8	0	-2	8	0	0	1.9999999999999982	
i 1	59.49513605442177	0.2525	74	399	6	2	15	16	0	1	16	0	0	14.0	
i 1	59.50561224489796	0.2525	71	399	6	1	8	8	0	-2	8	0	0	9.0	
i 1	59.506360544217685	0.2525	70	581	3	24	16	2	0	-1	2	0	0	5.999999999999998	
i 1	59.51534013605442	4.2925	67	897	5	15	7	5	0	0	5	0	0	9.0	
i 1	59.73914965986395	0.2525	73	581	3	20	13	8	0	-1	8	0	0	1.9999999999999982	
i 1	59.73989795918367	0.505	69	897	5	5	6	1	0	0	1	0	0	11.0	
i 1	59.73989795918367	0.7575000000000001	73	195	1	24	5	16	0	252	16	307	0	5.999999999999998	
i 1	59.74214285714286	0.505	77	399	6	2	2	16	0	1	16	0	0	14.0	
i 1	59.746632653061226	0.2525	71	399	6	1	15	8	0	-1	8	0	0	9.0	
i 1	59.748877551020406	0.2525	72	399	6	5	13	8	0	-2	8	0	0	11.0	
i 1	59.75561224489796	0.505	72	897	6	1	7	0	0	0	0	0	0	9.0	
i 1	59.764591836734695	0.2525	74	581	3	24	3	2	0	1	2	0	0	5.999999999999998	
i 1	59.766836734693875	0.505	69	195	5	9	13	0	0	-1	0	0	0	13.0	
i 1	60.235408163265305	0.2525	75	581	4	4	2	2	0	1	2	0	0	14.0	
i 1	60.246632653061226	0.2525	72	897	4	4	14	2	0	-2	2	0	0	14.0	
i 1	60.25486394557823	0.2525	73	195	4	20	7	8	0	-2	8	0	0	1.9999999999999982	
i 1	60.26085034013605	0.2525	69	581	4	24	16	1	0	0	1	0	0	12.0	
i 1	60.26309523809524	0.2525	69	581	6	5	15	1	0	-1	1	0	0	11.0	
i 1	60.26758503401361	0.2525	76	195	4	20	14	17	0	1	17	0	0	1.9999999999999982	
i 1	60.48690476190476	0.2525	74	399	6	2	15	16	0	1	16	0	0	14.0	
i 1	60.49139455782313	0.2525	77	195	5	5	6	17	0	2	17	0	0	11.0	
i 1	60.496632653061226	0.2525	72	195	5	9	1	0	0	0	0	0	0	13.0	
i 1	60.51309523809524	0.2525	73	195	4	20	1	8	0	-2	8	0	0	1.9999999999999982	
i 1	60.51608843537415	0.2525	73	195	4	24	7	16	0	1	16	0	0	5.999999999999998	
i 1	60.516836734693875	0.2525	77	195	7	1	13	17	0	1	17	0	0	9.0	
i 1	60.735408163265305	0.2525	71	399	6	1	1	8	0	-1	8	0	0	9.0	
i 1	60.735408163265305	0.2525	74	195	4	5	10	16	0	1	16	0	0	11.0	
i 1	60.74139455782313	0.2525	76	195	4	20	16	17	0	1	17	0	0	1.9999999999999982	
i 1	60.74438775510204	0.2525	72	399	6	5	14	8	0	-2	8	0	0	11.0	
i 1	60.74812925170068	0.2525	73	581	3	20	8	8	0	-1	8	0	0	1.9999999999999982	
i 1	60.748877551020406	0.2525	73	195	4	20	10	8	0	-2	8	0	0	1.9999999999999982	
i 1	60.75037414965986	0.2525	69	195	5	9	3	0	0	-1	0	0	0	13.0	
i 1	60.75037414965986	0.2525	74	581	3	24	1	2	0	1	2	0	0	5.999999999999998	
i 1	60.756360544217685	0.2525	77	399	6	2	3	16	0	1	16	0	0	14.0	
i 1	60.764591836734695	0.2525	74	195	7	1	3	17	0	1	17	0	0	9.0	
i 1	63.73465986394558	3.2825	61	399	5	14	14	9	0	0	9	0	0	9.350702218603706	
i 1	63.73690476190476	3.2825	60	897	5	15	16	0	0	0	0	0	0	7.350702218603706	
i 1	63.745884353741495	3.2825	66	399	5	13	15	9	0	0	9	0	0	6.350702218603706	
i 1	63.74962585034014	3.2825	66	195	5	16	7	6	0	2	6	0	0	8.350702218603706	
i 1	63.753367346938774	3.2825	60	581	4	12	15	0	0	1	0	0	0	8.350702218603706	
i 1	63.754115646258505	3.2825	61	195	5	16	2	9	0	1	9	0	0	8.350702218603706	
i 1	63.76010204081633	3.2825	67	897	5	15	8	5	0	0	5	0	0	7.350702218603706	
t0 110
</CsScore>
</CsoundSynthesizer>

