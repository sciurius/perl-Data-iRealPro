#!/usr/bin/perl -w

# splitlist -- split a playlist into individual files

# Author          : Johan Vromans
# Created On      : Wed Sep 14 18:50:49 2016
# Last Modified By: Johan Vromans
# Last Modified On: Wed Sep 14 20:49:15 2016
# Update Count    : 33
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;

# Package name.
my $my_package = 'iRealProTools';
# Program name and version.
my ($my_name, $my_version) = qw( splitlist 0.01 );

################ Command line parameters ################

use Getopt::Long 2.13;
use Encode qw( decode_utf8 encode_utf8 );

# Command line options.
my $outdir;			# output dir ...
my $verbose = 0;		# verbose processing

# Development options (not shown with -help).
my $debug = 0;			# debugging
my $trace = 0;			# trace (show process)
my $test = 0;			# test mode.

# Process command line options.
app_options();

# Post-processing.

if ( $outdir ) {
    $outdir = decode_utf8($outdir);
    $outdir =~ s;/+$/;;;
    mkdir($outdir);
    $outdir .= "/";
}
else {
    $outdir = "";
}
$trace |= ($debug || $test);

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

################ The Process ################

use Data::iRealPro::Input;
use Data::iRealPro::Playlist;
use Data::iRealPro::URI;

foreach my $file ( @ARGV ) {
    my $u;
    if ( -f $file ) {
	$u = Data::iRealPro::Input->new->parsefile($file);
    }
    else {
	$u = Data::iRealPro::Input->new({ debug => 1 })->parsedata($file);
    }

    foreach my $song ( @{ $u->{playlist}->{songs} } ) {

	# Make a playlist with just this song.
	my $pls = Data::iRealPro::Playlist->new( song => $song );

	# Make an URI for this playlist.
	my $uri = Data::iRealPro::URI->new( playlist => $pls );

	# Write it out.
	my $title = $song->{title};
	my $file = $outdir.$title.".html";
	my $out = encode_utf8($file);
	open( my $fd, '>:utf8', $out )
	  or die( "$out: $!\n" );
	print { $fd } $uri->export( variant => "irealpro", html => 1 );
	close($fd);
	warn( "Wrote $out\n" )
	  if $verbose;
    }
}

################ Subroutines ################

sub app_options {
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally
    my $man = 0;		# handled locally

    my $pod2usage = sub {
        # Load Pod::Usage only if needed.
        require Pod::Usage;
        Pod::Usage->import;
        &pod2usage;
    };

    if ( !GetOptions(
		     'outdir=s'	=> \$outdir,
		     'ident'	=> \$ident,
		     'verbose+'	=> \$verbose,
		     'trace'	=> \$trace,
		     'help|?'	=> \$help,
		     'man'	=> \$man,
		     'debug'	=> \$debug,
		    ) or $help )
    {
	$pod2usage->(2);
    }
    if ( $man or $help ) {
	$pod2usage->(1) if $help;
	$pod2usage->(VERBOSE => 2) if $man;
    }
    app_ident() if $ident;
    $pod2usage->(1) unless @ARGV <= 1;
}

sub app_ident {
    print STDERR ("This is $my_package [$my_name $my_version]\n");
}

=head1 NAME

splitlist - split an iRealPro playlist into individual songs

=head1 SYNOPSIS

splitlist [options] playlist ...

Splits an iRealPro playlist into individual songs.

 Options:
    --outdir=XXX	directory to contain the individual songs.
    --ident		shows identification
    --help		shows a brief help message and exits
    --man               shows full documentation and exits
    --verbose		provides more verbose information

=head1 DESCRIPTION

This program will process the playlist and write all the songs from
the playlist into individual files.

The resultant files are written in the designated I<outdir>, which also
defaults to the current directory.

=head1 OPTIONS

=over 8

=item B<--outdir=>I<XXX>

Specifies the directory where the resultant files are to be written.

=item B<--help>

Prints a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=item B<--ident>

Prints program identification.

=item B<--verbose>

Provides more verbose information.

=item I<playlist>

The playlist to process.

=back

=cut

__DATA__
Xbegin 0644 mscore.jpg
XM_]C_X``02D9)1@`!`0```0`!``#_VP!#``,"`@("`@,"`@(#`P,#!`8$!`0$
XM!`@&!@4&"0@*"@D("0D*#`\,"@L."PD)#1$-#@\0$!$0"@P2$Q(0$P\0$!#_
XMVP!#`0,#`P0#!`@$!`@0"PD+$!`0$!`0$!`0$!`0$!`0$!`0$!`0$!`0$!`0
XM$!`0$!`0$!`0$!`0$!`0$!`0$!`0$!#_P``1"``R`#(#`1$``A$!`Q$!_\0`
XM&P`!`0$``@,```````````````8%`00"`PG_Q``P$``!`P,#`P$&!@,`````
XM```!`@,$``4&!Q$2$R%!,14R45)A<106(C1"8H*1M/_$`!@!`0$!`0$`````
XM```````````$`@,!_\0`+1$``0,"!`4#!`,!`````````0`"$0,$(3%1L1(3
XM06&!%"+P<7*1H045P>'_V@`,`P$``A$#$0`_`/JG1$HB41*(E$2B)1$HB41*
XM(L+,,F.+VQN1'@JG3ILAN%`B)6$=>0O?BDJ/NI`"E*5X2DG8^E4VMOZA\$PT
XM"2=`/D#NI[JOZ=D@2XF`-2?F/98I@:L_N/S?C?XSAU/9WLMSH;?+U>KU-O'/
XMC_CXJGCL<N6Z->(3^(CQ/E3<%]GS&SIPF/S,^8\+;P_)1E-H,UV$J%,C/NPY
XMT52@HL2&U<5HY#WAZ$'RD@]MZFNK?T]3A!D$`@Z@Y?-53:W'J*?$1!!((T(S
XM^:+<J94)1%$R=48CLR5%QG%;]DC<%U3$F5;66N@AU)V4VE;KB`XI)[$(Y;'L
XM>_:KFV)#0:KPV<@9G]`QY4)O@7$4F%T9D1'[(GPO%S5_%7(D)5H8N5VN,]3J
XM&K3#BDS4*:/%T.H44AG@H@*+A2-R.YW%!_'U03QD-`ZDX8Y1K/9/["D0."7$
XM]`,<,YTCNO=:LQLV1WV+8[_C%RLUXC\IL!BZL(!<XI*5K8<0I:%*2E9!`5R`
XM5Z;'>O'V]2C3+Z;PYIP,;$&#T7K+AE:H*=1A:X8B=P1(ZJA./V4W].4FW-&Z
XMIB&")6QYA@KYEO[<AO4_.J<KDS[9F.^4JCDT^9SH]T1/;.%U<;N%AGOWI-CC
XM!ER)<W(\\]/AU)0;;*E?V_2I`W^GTK59M1H9S#F,/I)_ZLT7TW%_+&1Q^L!;
XM=<%W4_J#<I-FP/)+O"642(5IER&5#^*T,J4D_P"P*[VS0^LQIR)&ZX7+BR@]
XMS<P#LN<!M$*Q818;1;V@AB-;V$)`\G@"5'XDDDD^232YJ&K6<]V9)2VIMI46
XM,;D`%+:?V.V0M4M2[M'C)3*E3K>AQ?GB(3:MA\-RHD_$U3<U7.MJ+"<`#N5-
XM;4F-N:SP,21L%W=2@&[[@,I'9U&3);2KR$KAR0H?8BL6A]E5NK?]"W=CWTCH
XM[_"KNHE:H32X[S\[^F5R?^>/5MX9;2^T;E0V0AU7[CL%=U$KE-:FQ)4_3C*H
XM,&.X_)D66:TRTVDJ6XM3"PE*0/4DD`"NULX-K,<>A&ZXW+2ZB]HZ@[+5Q]MQ
XMFPVUEYM2'&X;*5)4-BDA`W!K%0R\GNMTQ#0%.X?`G1<XSN7)B.M,3)T)<=Q:
XM"$NI3":2HI/D!0(^XKK5<#2I@=`=RN5)I%1Y/4C9-3[1>9UKM=YL$$SYV.W5
XMB[)A)4$JE-H"T.-H)[!9;<64[]BH`';?>EL]K26N,!PA+ECG-#FB2TRNB]K3
XMC9C%%LL>3SKJ4[(M2+'*;D%SY5%:`VCOZJ4H)'KO6A:/G$@#60LF[9&`).D%
XM:6F.-7?',=><R,L^VKS/D7>XI95R;:>>5OTDJ\A"`A&_GCOYK-S5;5>.#(``
XH>%JVI&FP\69))\JNJ=4)1$HB41*(E$2B)1$HB41*(E$2B)1$HB__V0``
X`
Xend
Xbegin 0644 ireal.jpg
XM_]C_X``02D9)1@`!`0```0`!``#_VP!#``,"`@("`@,"`@(#`P,#!`8$!`0$
XM!`@&!@4&"0@*"@D("0D*#`\,"@L."PD)#1$-#@\0$!$0"@P2$Q(0$P\0$!#_
XMVP!#`0,#`P0#!`@$!`@0"PD+$!`0$!`0$!`0$!`0$!`0$!`0$!`0$!`0$!`0
XM$!`0$!`0$!`0$!`0$!`0$!`0$!`0$!#_P``1"``R`#(#`1$``A$!`Q$!_\0`
XM&P```@(#`0``````````````!P@&"0`#!`7_Q``Q$``!`P0!`P,"!0,%````
XM```!`@,$!08'$2$`"!(3(C%!410C,F%Q%4*1%QAR@;+_Q``;`0`!!0$!````
XM```````````%``(#!`8!!__$`#,1``$#`@,$"`4%`0````````$"`P0`$04A
XM,1)!46$3%#)Q@9'!\")2H;'1%2-"<N'Q_]H`#`,!``(1`Q$`/P"J^)$EU"6S
XM`@179,F2XEEEEE!6MQ:CI*4I')))``'))ZZE)60E(N37"H)%SI3)C#^%^W2`
XMQ4>Y&3*NF]WV42&<?466&4P0I/DG^IRT[+:B"-M-^X?<@\%>K,0DA<KXE'^(
XM]3[\107K<G$24POA1\YW_P!1ZFN#_>]DFW$N0<.VA9.-J<4E#;5$HC2W_$C^
XM^0^%K6KZ[XY`Z:,6=:R82$CD*?\`HK#F<E2G#S)^PM6J/WY=R+K)@W/<](NJ
XM`M7D[!KE!AR6'!K7B0&TG6B?@@\GI#&)5ME9"AS`_P`I'`H0-VTE)X@D>M2"
XM@4+&G=E$F4^T\+L8ZNZF)1-J=P4RHEFUXD$'\Y^8T]Y%C0"@A+1VI6OH#T]*
XM6<0N$-[*N([/CPRT^IM4+BW\*(+CNV@Y`$?&3N`MKSO0*RIBB],-W<_9M[TY
XM+$M"$OQY#*_4C38Z^6Y##@X<;4.0H?N"`00!\B,Y&7L.#\'NHK%E-3&^D:.7
XMU!X'G40Z@JS3+X?_``';IA=[N1J,5AZ^+I??HN/67VTK$(-^V75?%6P2@GTV
XMSKA6_D'@K'"8<?K*A\2LD^I]_8T$EWQ"3U)/83FOGP3ZFEQJ=3J-:J,JKU><
XM_-G375OR9+[A6X\XH[4M2CR22223T,4HK)4HW)HRE*4)"4BP%<W3:=1`PMA:
XMZ,V70Y1*(['IU,IS)FURN35>$*D0D\K?>6>!P#XIWM1X'U(L1HRY*]E.0WGA
XM5.;-;A-[2LR<@!J3P%37-&:+78M=&!,"-2*=CJG/!V?/=3X3;HFIX,N41R&]
XMC\MGX2-$C>@FQ)DH".KQ^P-3Q_SWP`K0H;A7UN7FX=!N2.`Y\34GP96FNXK'
XM\GM:OB2E^O08[T_&U4D$>I$EMH*W*85GGT'D)/BD\)4!K^T"6(H3&S%<UU2?
XM3WN\*@G(_3WA/:[)R6.(^;O%+/)C2(<AV)*96R^PM3;C:QI2%I.BDCZ$$:Z%
XMD$&QHV""+BF#[W"FW<E4+#L%U)IV-;8IM":0A6TE]3(?D.?\E./'?\#HGBP#
XM;J6$Z(`'OZ4'P3]QA4DZN*)]!]J7CH71FIWA_#]PY@N%^G4Z5&I5'I3!G5ZN
XMSCX0J1"3^I]Y7^0E`]RU:`^I$\>.J0JPR`U/"JDN6B(C:.9.0`U)X"FOH]M8
XMW[B<8N=NG:A?\RVG*%ZM3J=+KM-]!5WJ;4E(FNRVU**0"I/BPM("?(<#QV#;
XM33,UHQHB[6SL1VO'A[ME6?6X_A[_`%W$$;5\@0>QR`]:2Z\;/N3']T5*S+OI
XM+U-K%)?,>7%='N0L<_(X((((4-@@@@D'H"ZTME9;6+$5IF7D2&PZV;@UEEW3
XM4K'N^B7E1W5-S:'4(]0CJ!U[VG`L?^>DTX6G$K&XWI/-)?;4VK0@CSJTNO\`
XM8)C7(E=J.0&8[*6[FEO5A"4*/B$R5ET`:XU[^M@O"8[JBL[\ZPC>//QT!GY1
XM;RRI'N_".T[W(UJYX2U.4^ZJ=2Z[!=.M.,/0V@"-;&MH4/\`H]9_&`.M%8T4
XM`1Y6]*U&!$B$ELZI)!\":@N!,!7WW#7PS9UF0RAEOQ=J=3=03'IT?>BXX1\D
XM_"4#E1X'U(JQ(CDQS81XGA5N?/:P]KI'?`;R:=O(W8QFJL4"!A?%,RV+8QI3
XMW4R93LF<\NHUZ:!S-G!MDA1!X;9!*&QKZ\@^]@[Q`8:4`CO-SWY>_*V8C8Y&
XM0LR9`*G#R%DC@,_,ZFB/V]]L6+.S*)4K[OW)%,=KTN*8KU3GNH@QHL<J"E-L
XMMK45**BA.U'D^(`2.=WH,!C"@775YD=U4L0Q-_&2&64'9&X9DGG2`=XV7+:S
XM7GJN7I9Z%&C):CT^)(4@H5+0PV$>L4D`I"CO0//B$[T>!F,3DHE25.(TK6X/
XM$7"B):<US/=?=08B1)$^6S!B-*=?D.)::0D;*EJ.@!_)/5!(*B`*)DA(N:O6
XMI&6;`LJDPK-J5=:3+H,=NF/A2T!0<82&U`^[YVD]>@!;:!L[6E>5KBO/*+@&
XM1S\ZJXKL#_7[M;HUU4?\^[\*,*I%<BCEV1;[CBEQI21\D,**VU?9/N.AKK)J
XM3UR(%I[3>1[MWE^36Z0KJ$]3:NP[F/[;QXZT"K<R#?MG1GH=HWO7Z&Q(6'7F
XMJ;4GHR'%@:"E!M0"B!QL]#VWW6A9M1'<;45<CM/&[B0>\`UWS,PY;J+08J&4
XMKNE-!04$/5N2M(/WT5_/)Z<93ZLBL^9I@AQTFX;3Y"HQ,G3JB^J34)C\IY1)
XM4X\X5J.SL[)Y^23U"5%1N:L!(2+`5HZY7:/O:18U+-T3L[WXUZ=CXL0BM3EK
XM&A-GI.X4)O?ZEK>""1]$@[UL=$<.:&V9#G91GX[O?YH3BSZNC$1KMN9#D-Y\
XMJ$]TY$NR[;GJ]U5&LRTRZS/D5!\(?4$AQYQ2U`<_&U'JHX^MQ963J;U?:CMM
XM(2V!D`!Y5UXGRK=V&KUB7Q9DMMN7'2IE^.^CU(\V,OAR.^@\+;6!HC^"-$`C
XML:0J,X'$_P#1PILN*W,:+3FGU!XCG1MK6"\?=Q3+U\=K4Z)!KSX,BJ8VGR$,
XMRXCFMK-.<60F2QY;*4;"D@Z^R1>5%;F#I(ISWI/I[_%#$3GL//13Q=.Y8T/]
XMN!I>[ILJ\+'J2Z/>5KU6AS6R0IBH1'(Z_P#"P-C]QT.<9<:-EI([Z+M/-OIV
XMFE`CD:\N)$ESY"(D&*[(?=/BAII!6M1^P`Y/3`DJ-@*D)"1<T>+'[1[H_I:+
XM\SQ56\66.WI:YM9;*9\T?/IPX1_-=61\$I"1O?.M=$6<.7;I)!V$\]?`>_&A
XM+^+-[711!TB^`T'>=*\?.><J5>5*IN*L541VV\8VTX7*=3G"/Q-1DZTJ?-4/
XMUOJV=#9"`=#IDN6EU(99%FQ]>9J6#!4RHR)!VG5:G<!P'+[T&NJ%$JSI4JV1
XMI,B'(;EQ)#C#[*@MMUM92M"A\$$<@_OUT$@W%<(!%C5L/8+7Z[D/&C#-_P!:
XMGW,VEI2`BL25S4A.]:TZ5<:XUULL)6IU@](;Y;\ZP&/-HCO_`+(V>[+[4=LL
XM4BDV58-3J-FTR)09:6U*2_3&$Q7`?!7(4V`=]7E@(:5LY4*BK4\\D.&XYYU2
XM3D6ZKGNV[:C4+JN.J5F4F0ZA+]0F.2'`GR/`4X2=?MUA'W%N+)62>^O3H[2&
X1FPEM(`Y"U1KJ&IZSI4J__]D`
X`
Xend
