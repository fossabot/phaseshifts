C---------------------------------------------------------------------
C  program PHSH1.FOR
C---------------------------------------------------------------------
C
C  adapted from CAVPOT
C
      PROGRAM PHSH1
C  PHASE SHIFT PROGRAM FROM CAVLEED PACKAGE (PENDRY-TITTERINGTON).
C
C  MAIN PROGRAM FOR COMPUTATION OF MUFFIN-TIN POTENTIAL
C  AFTER MATTHEISS.   REF - LOUCKS, 'APW METHOD', 1967
C  INCLUDING? HARTREE POTENTIAL, SLATER-TYPE STATISTICAL
C  EXCHANGE TERM, AND MADELUNG CORRECTION FOR IONIC
C  MATERIALS
C  DIMENSIONED FOR UP TO NTOT (24) ATOMS IN THE UNIT CELL, OF NIEQ
C  INEQUIVALENT TYPES (BUT NIEQ<14)
c	modified by Liam Deacon
      CHARACTER(LEN=255) :: ATOMIC, CLUSTER, ARG, OUTPUT, STRING(3), MTZ
      INTEGER 			:: BULK, IBUFFER, I

      ATOMIC = 'atomic.i'
      CLUSTER = 'cluster.i'
      OUTPUT = 'bmtz.txt'
      BULK = 0
      I = 1
      MTZ = "0"

      DO
        CALL GETARG(I, ARG)
        IF ((ARG.EQ.'-a').OR.(ARG.EQ.'--atomic')) THEN
          I = I+1
          CALL GETARG(I, ATOMIC)
        ENDIF
        IF ((ARG.EQ.'-b').OR.(ARG.EQ.'--bulk')) THEN
          I = I+1
          CALL GETARG(I, ARG)
          READ(ARG, "(I1)", ERR=999) IBUFFER
          IF ((IBUFFER.EQ.1).OR.(IBUFFER.EQ.0)) THEN
            BULK = IBUFFER
          ENDIF
        ENDIF
        IF ((ARG.EQ.'-c').OR.(ARG.EQ.'--cluster')) THEN
          I = I+1
          CALL GETARG(I, CLUSTER)
        ENDIF
        IF ((ARG.EQ.'-m').OR.(ARG.EQ.'--mtz')) THEN
          I = I+1
          CALL GETARG(I, MTZ)
        ENDIF
        IF ((ARG.EQ.'-o').OR.(ARG.EQ.'--output')) THEN
          I = I+1
          CALL GETARG(I, OUTPUT)
        ENDIF
        IF ((ARG.EQ.'-h').OR.(ARG.EQ.'--help')) THEN
          WRITE(*,*) 'phsh1 usage:-'
          WRITE(*,*)
          STRING(1) = 'phsh1 -a <file> -b <flag>'
          STRING(2) = ' -c <file> -m <mtz> -o <file>'
          WRITE(*,*) TRIM(STRING(1))//TRIM(STRING(2))
		  WRITE(*,*) ''
          WRITE(*,*) 'where:-'
          STRING(1) = '-a or --atomic <file>'
          STRING(2) = ' specifies atomic file path'
          STRING(3) = ' (default: "atomic.i")'
          WRITE(*,*) TRIM(STRING(1))//TRIM(STRING(2))//TRIM(STRING(3))
          STRING(1) = '-b or --bulk <flag>'
          STRING(2) = ' perform bulk calculation if flag=0'
          STRING(3) = ' or slab calculation if flag=1'
          WRITE(*,*) TRIM(STRING(1))//TRIM(STRING(2))//TRIM(STRING(3))
          STRING(1) = '-c or --cluster <file>'
          STRING(2) = ' specifies cluster file path'
		  STRING(3) = ' (default: "cluster.i")'
          WRITE(*,*) TRIM(STRING(1))//TRIM(STRING(2))//TRIM(STRING(3))
          STRING(1) = '-m <mtz> specifies the muffin potential from a'
          STRING(2) = ' previous bulk calculation (for use with: -b 1)'
          WRITE(*,*) TRIM(STRING(1))//TRIM(STRING(2))
          STRING(1) = '-o or --output <output> specifies the output'
          STRING(2) = ' file path (default: "bmtz.txt")'
          WRITE(*,*) TRIM(STRING(1))//TRIM(STRING(2))
          STRING(1) = '-h or --help print help and exit'
          WRITE(*,*) TRIM(STRING(1))
          STOP
        ENDIF
        IF (I.GE.IARGC()) THEN
          EXIT
        ENDIF
        I = I+1
      END DO

      CALL CAVPOT(MTZ, BULK, ATOMIC, CLUSTER, OUTPUT)
      STOP

999   WRITE(*,*) 'Bad input.'
      STOP

      END
C---------------------------------------------------------------------
      SUBROUTINE CAVPOT(MTZ_STRING, SLAB_FLAG, ATOMIC_FILE,
     1   CLUSTER_FILE, OUTPUT_FILE)
      CHARACTER(LEN=*), INTENT(IN) :: ATOMIC_FILE
      CHARACTER(LEN=*), INTENT(IN) :: CLUSTER_FILE, OUTPUT_FILE
      CHARACTER(LEN=*), INTENT(IN) :: MTZ_STRING
      INTEGER, INTENT(IN)		   :: SLAB_FLAG
      PARAMETER (NIEQ=10,NTOT=40)
      DIMENSION SIG(250,NIEQ),RHO(250,NIEQ),VH(250,NIEQ)
      DIMENSION VS(250,NIEQ),VMAD(550,NIEQ),RX(550),RS(550),POT(550)
      DIMENSION RC(3,3),RK(3,NTOT),ZM(NTOT),Z(NIEQ),ZC(NIEQ)
      DIMENSION RMT(NIEQ),JRMT(NIEQ),JRMT2(NIEQ),NRR(NIEQ)
      DIMENSION NCON(NIEQ),NX(NIEQ)
      DIMENSION IA(30,NIEQ),NA(30,NIEQ),AD(30,NIEQ)
      REAL TITLE(20),NAME(4,NIEQ),WFN,WFN0,WFN1,WFN2,WFN3,SUM
C Replace the above line by a more appropriate ...
C      REAL TITLE(20),NAME(4,NIEQ),SUM
C      CHARACTER*4 WFN,WFN0,WFN1,WFN2,WFN3
      COMMON /WK/ WK1(250),WK2(250)
      COMMON /WF/ WF2(250,14),WC(14),LC(14)
      DATA NGRID,MC,PI/250,30,3.1415926536/,WFN0,WFN1,WFN2,WFN3/
     + 4HRELA,4HHERM,4HCLEM,4HPOTE/
      INDEX(X)=20.0*(ALOG(X)+8.8)+2.0

C
C First input channels
C
      OPEN (UNIT=4,FILE=ATOMIC_FILE,STATUS='OLD')
      OPEN (UNIT=7,FILE=CLUSTER_FILE,STATUS='OLD')
C
C Now output channels
C
      OPEN (UNIT=11,FILE='check.o',STATUS='UNKNOWN')
      OPEN (UNIT=9,FILE='mufftin.d',STATUS='UNKNOWN')
      OPEN (UNIT=10,FILE=OUTPUT_FILE,STATUS='UNKNOWN')
C
C  INITIALISATION OF LOUCKS' EXPONENTIAL MESH
      X=-8.8
      DO 1 IX=1,NGRID
      RX(IX)=EXP(X)
1     X=X+0.05
C
      READ(7,100)TITLE
      WRITE(11,200)TITLE
C
C  INPUT OF CRYSTALLOGRAPHIC DATA
C    SPA = LATTICE CONSTANT IN A.U.
C    RC(I,J) = I'TH COORDINATE OF THE J'TH AXIS OF UNIT CELL,
C    IN UNITS OF SPA
C    RK(I,J) = I'TH COORDINATE OF THE J'TH ATOM IN UNIT CELL,
C    IN UNITS OF SPA
C    NR = NUMBER OF INEQUIVALENT ATOMS IN UNIT CELL
C  FOR AN ATOM OF TYPE IR?
C    NRR(IR) = NUMBER IN UNIT CELL
C    Z(IR) = ATOMIC NUMBER
C    ZC(IR) = VALENCE CHARGE
C    RMT(IR) = MUFFIN-TIN RADIUS
      READ(7,101)SPA
      READ(7,101)((RC(I,J),I=1,3),J=1,3)
      DO 2 I=1,3
      DO 2 J=1,3
2     RC(I,J)=SPA*RC(I,J)
      READ(7,102)NR
      DO 3 IR=1,NR
      DO 3 I=1,NGRID
      VH(I,IR)=0.0
      VS(I,IR)=0.0
      VMAD(I,IR)=0.0
      SIG(I,IR)=0.0
3     RHO(I,IR)=0.0
      VHAR=0.0
      VEX=0.0
C
      JJ=0
      ZZ=0.0
      DO 4 IR=1,NR
      READ(7,100)(NAME(I,IR),I=1,4)
      READ(7,103)NRR(IR),Z(IR),ZC(IR),RMT(IR)
      ZZ=ZZ+ABS(ZC(IR))
      JRMT(IR)=INDEX(RMT(IR))
      N=NRR(IR)
      DO 4 J=1,N
      JJ=JJ+1
      ZM(JJ)=ZC(IR)
      READ(7,101)(RK(I,JJ),I=1,3)
      DO 4 I=1,3
4     RK(I,JJ)=SPA*RK(I,JJ)
C    N = TOTAL NUMBER OF ATOMS IN UNIT CELL
C    AV = TOTAL VOLUME OF UNIT CELL
C    OMA = ATOMIC VOLUME
C    RWS = WIGNER-SEITZ RADIUS
      N=JJ
      RCC1=RC(2,2)*RC(3,3)-RC(3,2)*RC(2,3)
      RCC2=RC(3,2)*RC(1,3)-RC(1,2)*RC(3,3)
      RCC3=RC(1,2)*RC(2,3)-RC(2,2)*RC(1,3)
      AV=ABS(RC(1,1)*RCC1+RC(2,1)*RCC2+RC(3,1)*RCC3)
      OMA=AV/FLOAT(N)
      RWS=(0.75*OMA/PI)**(1.0/3.0)
      JRWS=INDEX(RWS)
      WRITE(11,201)((RC(I,J),I=1,3),J=1,3)
      WRITE(11,202)AV,OMA,RWS
      JJ=0
      DO 6 IR=1,NR
      WRITE(11,203)IR,(NAME(I,IR),I=1,4),NRR(IR)
      INR=NRR(IR)
      DO 5 IIR=1,INR
      JJ=JJ+1
5     WRITE(11,204)(RK(I,JJ),I=1,3)
6     WRITE(11,205)Z(IR),ZC(IR),RMT(IR)
      WRITE(11,216)(RX(IX),IX=1,NGRID)
C
C  FOR EACH ATOMIC TYPE, READ IN ATOMIC WAVEFUNCTIONS FOR NEUTRAL
C  ATOM, IN EITHER THE HERMAN-SKILLMAN OR CLEMENTI FORM, PRODUCING?
C    RHO = 4*PI*CHARGE DENSITY * RADIUS**2
      MIX=0
      DO 11 IR=1,NR
      READ(4,100)WFN
C  OPTION 0)  RELATIVISTIC CHARGE DENSITY INPUT
      IF(WFN.EQ.WFN0)CALL RELA(RHO(1,IR),RX,NX(IR),NGRID)
C  OPTION 1)  HERMAN-SKILLMAN INPUT
      IF(WFN.EQ.WFN1)CALL HSIN(RHO(1,IR),RX,NX(IR),NGRID)
C  OPTION 2)  CLEMENTI INPUT
      IF(WFN.EQ.WFN2)CALL CLEMIN(RHO(1,IR),RX,NX(IR),NGRID)
C  OPTION 3)  POTENTIAL INPUT
      IF(WFN.EQ.WFN3)GOTO 14
C  RHO IS NORMALISED USING TOTAL ELECTRONIC CHARGE ON THE ATOM
C  CALCULATED BY THE TRAPEZOIDAL RULE
7     NIX=NX(IR)
      MIX=MAX0(NIX,MIX)
      SUM=0.0D0
      W1=0.025*RHO(1,IR)*RX(1)
C      JRXX=JRMT(IR)
      DO 8 IX=2,NIX
      W2=0.025*RHO(IX,IR)*RX(IX)
      SUM=SUM+W1+W2
8     W1=W2
      ZE=SUM
C      ANORM=Z(IR)/ZE
C      DO 9 IX=1,NIX
C9     RHO(IX,IR)=RHO(IX,IR)*ANORM
C  SOLVE POISSON'S EQUATION
C    SIG = COULOMB POTENTIAL
C    RHO = 4*PI*CHARGE DENSITY*RADIUS SQUARED
      CALL POISON(RHO(1,IR),Z(IR),NIX,SIG(1,IR))
      X=-8.8
      DO 10 IX=1,NIX
      CE=EXP(-0.5*X)
      SIG(IX,IR)=CE*(-2.0*Z(IR)*CE+SIG(IX,IR))
      RHO(IX,IR)=RHO(IX,IR)/(RX(IX)**2)
10    X=X+0.05
      WRITE(11,206)(NAME(I,IR),I=1,4),ZE,RX(NIX),NIX
      WRITE(11,207)(SIG(IX,IR),IX=1,NIX)
11    CONTINUE
C
C  DETAILS OF NEIGHBOURING SHELLS FOR EACH ATOMIC TYPE IR?
C    NCON(IR) = NUMBER OF SHELLS INCLUDED
C    IA(J,IR) = ATOMIC TYPE IN J'TH SHELL
C    NA(J,IR) = NUMBER OF ATOMS IN J'TH SHELL
C    AD(J,IR) = DISTANCE TO J'TH SHELL
      RMAX=RX(MIX)
      CALL NBR(IA,NA,AD,NCON,NRR,NR,RC,RK,N,RMAX,MC)
      WRITE(11,208)
      DO 12 IR=1,NR
      WRITE(11,209)IR
      NC=NCON(IR)
      IC=(NC-1)/12+1
      KC=0
      DO 12 I=1,IC
      JC=KC+1
      KC=MIN0(NC,KC+12)
      WRITE(11,210)(AD(J,IR),J=JC,KC)
      WRITE(11,211)(NA(J,IR),J=JC,KC)
12    WRITE(11,212)(IA(J,IR),J=JC,KC)
      READ(7,102) nform
C
C  CALCULATION OF THE MUFFIN-TIN POTENTIAL FOR EACH NEUTRAL
C  ATOM, FOLLOWING THE MATTHEISS PRESCRIPTION
C  READ IN ALPHA FOR THE SLATER EXCHANGE TERM
      READ(7,101)ALPHA
      WRITE(11,215)ALPHA
      PD=6.0/(PI*PI)
      DO 13 IR=1,NR
      JRX=MAX0(JRWS,JRMT(IR))
C  SUMMING THE POTENTIALS FROM NEUTRAL ATOMS
C    VH = HARTREE POTENTIAL
      CALL SUMAX(VH(1,IR),SIG,RX,NX,NCON(IR),IA(1,IR),NA(1,IR),
     + AD(1,IR),JRX,NGRID,NR)
C  SUMMING THE CHARGE DENSITY ABOUT EACH ATOMIC TYPE
C    VS = TOTAL CHARGE DENSITY, THEN SLATER EXCHANGE TERM
      CALL SUMAX(VS(1,IR),RHO,RX,NX,NCON(IR),IA(1,IR),NA(1,IR),
     + AD(1,IR),JRX,NGRID,NR)
      DO 13 IX=1,JRX
13    VS(IX,IR)=-1.5*ALPHA*(PD*VS(IX,IR))**(1.0/3.0)
C
C  CALCULATE THE MUFFIN-TIN ZERO
      VINT=0.
      READ(7,102)NH
      IF(NH.EQ.0.AND.NR.EQ.1)CALL MTZM(VH(1,1),VS(1,1),RX,NGRID,
     + RMT(1),RWS,JRMT(1),JRWS,VHAR,VEX)
      IF(NH.NE.0)CALL MTZ(SIG,RHO,RX,NGRID,RMT,NRR,NX,NR,RC,RK,N,
     + VHAR,VEX,ALPHA,AV,NH)
      write(*,*) 'Slab or Bulk calculation?'
      write(*,*) 'input 1 for Slab or 0 for Bulk'
c	modified by Liam Deacon
      if((SLAB_FLAG.eq.1).or.(SLAB_FLAG.eq.0)) then
	     read(SLAB_FLAG,*) nbulk
	     write(*,*) nbulk
      else
	     read(*,*) nbulk
      endif
      if (nbulk.eq.1) then
        write(*,*) 'Input the MTZ value from the substrate calculation'
        if (len_trim(MTZ_STRING).ge.1) then
          read(MTZ_STRING,*) esht
          write(*,*) esht
        else
          read(*,*) esht
      endif
c	    end modifications
	    esh=esht-(vhar+vex)
      else
        write(*,*) 'If you are interested in adatoms on this substrate'
        write(*,*) 'rerun a slab calculation with the adatoms'
        write(*,*) 'and use this MTZ value as input when asked '
        write(*,*) vhar+vex
        write(10,*) vhar+vex !modified by Liam Deacon
      endif
      GOTO 16
C
C  OPTION 3)  READ IN POTENTIAL OF NEUTRAL ATOM, VH, ON RADIAL
C  GRID, RX, FOR CORRECTION BY MADELUNG SUMMATION
14    READ(4,104)NGRID,(RX(IX),IX=1,NGRID)
      DO 15 IR=1,NR
      READ(4,104)JRX,(VH(IX,IR),IX=1,JRX)
15    JRMT(IR)=JRX
C
C  THE MADELUNG CORRECTION FOR IONIC MATERIALS.   SUBROUTINE MAD
C  COMPUTES THE SPHERICALLY AND SPATIALLY AVERAGED FIELDS FOR
C  THE LATTICE OF POINT CHARGES ABOUT EACH ATOMIC TYPE
16    IF(ZZ.NE.0)CALL MAD(VMAD,RX,NGRID,RMT,NRR,JRMT,NR,
     + RC,RK,ZM,N,AV)
C
C  THE TOTAL MUFFIN-TIN POTENTIAL IS ACCUMULATED INTO SIG,
C  REFERRED TO THE MUFFIN-TIN ZERO
      VINT=VHAR+VEX
      if (nform.eq.0)write(9,102)NR
      DO 17 IR=1,NR
      WRITE(11,213)(NAME(I,IR),I=1,4),VINT,RMT(IR)
      JRX=JRMT(IR)
      DO 17 IX=1,JRX
      VH(IX,IR)=VH(IX,IR)-VHAR
      VS(IX,IR)=VS(IX,IR)-VEX
      SIG(IX,IR)=VH(IX,IR)+VS(IX,IR)+VMAD(IX,IR)
17    WRITE(11,214)RX(IX),VH(IX,IR),VS(IX,IR),VMAD(IX,IR),SIG(IX,IR)
C
C     WRITE(9,219)NGRID,(RX(IX),IX=1,NGRID)
C write output in a format to be read by WILLIAMS phase shift program (NFORM=1)
C by CAVLEED phase shift program (NFORM=0), or by the relativistic phase
C shift program (NFORM=2)
C
C Also prepare to shift the potential by an amount of the order
C of the bulk muffintin zero.
C This is needed only if the cluster.i file correspond to a surface adsorbate
C      esh=SIG(JRX,IR)
C      esh=-1.07
      if (nform.eq.1) write(9,220) NR
      if (nform.eq.2) then
c
c define german grid RX and save old grid in RS
c
	 RM=60.0
	 DX=0.03125
	 NMX=421
	 RS(1)=RX(1)
	 RX(1)=RM*EXP(DX*(1-NMX))
	 J=1
	 RM= EXP(DX)
  110    K=J+1
	 RS(K)=RX(K)
	 RX(K)=RM*RX(J)
	 J=K
	 IF (J.LT.NMX)  GO TO 110
      endif
      DO 18 IR=1,NR
      JRX=JRMT(IR)
      if (nform.eq.0) then
	WRITE(9,217)(NAME(I,IR),I=1,4)
	WRITE(9,218)Z(IR),RMT(IR),VINT
      elseif(nform.eq.1)then
	WRITE(9,221)Z(IR),RMT(IR)
      else
c
c es=Emin for phase shift calculation (ev)
c de=delta E for phase shift calculation (ev)
c ue=Emax for phase shift calculation (ev)
c lsm=maximum number of phase shifts desired
	es=20.
	de=5.
	ue=300.
	lsm=12
	WRITE(9,217)(NAME(I,IR),I=1,4)
	WRITE(9,111)ES,DE,UE,LSM,VINT                                    C
111     FORMAT (3D12.4,4X,I3,4X,D12.4)
c
c  INTERPOLATION TO GRID RX
c
	 do 188 k=1,jrx
188      sig(k,IR)=(sig(k,IR)-esh)*rs(k)
	 NMXX=NMX
	 CALL CHGRID(SIG(1,IR),RS,JRX,POT,RX,NMXX)
	 IZ=Z(IR)
	 WRITE(9,105)IZ,RMT(IR),NMXX
105      FORMAT(I4,F10.6,I4)
	 JRX=NMXX
      endif
      if (nform.eq.0)write(9,102)JRX
      if(nform.eq.1)then
	DO 19 IX=1,JRX
19      WRITE(9,219)RX(IX),RX(IX)*(SIG(IX,IR)-esh)
	rneg=-1.
	WRITE(9,219) rneg
C        if (nform.eq.1) WRITE(9,219) rneg
      elseif(nform.eq.0) then
	DO 199 IX=1,JRX
199      WRITE(9,219)RX(IX),(SIG(IX,IR)-esh)
      else
	WRITE(9,106)(POT(IX),IX=1,JRX)
106     FORMAT(5E14.7)
      endif
18    CONTINUE
C
      STOP
C
100   FORMAT(20A4)
101   FORMAT(3F8.4)
102   FORMAT(I4)
103   FORMAT(I4,3F8.4)
104   FORMAT(I4/(5E14.5))
200   FORMAT(30H1MUFFIN-TIN POTENTIAL PROGRAM?,5X,20A4)
201   FORMAT(///18H AXES OF UNIT CELL/(6X,3F8.4))
202   FORMAT(18H0UNIT CELL VOLUME?,F15.4/
     + 15H ATOMIC VOLUME?,F18.4/
     + 21H WIGNER-SEITZ RADIUS?,F12.4)
203   FORMAT(///5H TYPE,I2,6H ATOM?,2X,4A4/
     + I4,19H ATOMS IN UNIT CELL)
204   FORMAT(6X,3F8.4)
205   FORMAT(15H0ATOMIC NUMBER?,F15.1/9H VALENCE?,F21.1/
     + 19H MUFFIN-TIN RADIUS?,F14.4)
206   FORMAT(///1H ,4A4,19H ELECTRONIC CHARGE?,F12.5/
     + 51H0COULOMB POTENTIAL FOR ISOLATED ATOM, OUT TO RADIUS,
     + F12.5,10X,3HNX?,I4/)
207   FORMAT(5(10E12.4/))
208   FORMAT(1H1)
209   FORMAT(//34H0NEAREST NEIGHBOUR SHELLS FOR TYPE,I2,5H ATOM)
210   FORMAT(9H DISTANCE,1X,15(F8.4))
211   FORMAT(7H NUMBER,3X,15(I5,3X))
212   FORMAT(5H TYPE,5X,15(I5,3X))
213   FORMAT(1H1,4A4,5X,33HPOTENTIALS IN RYDBERGS CORRECT TO,
     + 17H MUFFIN-TIN ZERO?,F8.4/19H0MUFFIN-TIN RADIUS?,F8.4//
     + 5X,6HRADIUS,5X,17HHARTREE POTENTIAL,9X,
     + 8HEXCHANGE,4X,19HMADELUNG CORRECTION,5X,
     + 15HTOTAL POTENTIAL)
214   FORMAT(F12.5,4E20.6)
215   FORMAT(///39H0STATISTICAL EXCHANGE PARAMETER, ALPHA?,F10.4)
216   FORMAT(///20H0LOUCKS' RADIAL MESH//5(10F11.5/))
217   FORMAT(4A4)
218   FORMAT(3F8.4)
219   FORMAT(2E14.5)
220   FORMAT(10H &NL2 NRR=,i2,5H &END)
221   FORMAT(9H &NL16 Z=,f7.4,4H,RT=,f7.4,5H &END)                                             C
      END
C---------------------------------------------------------------------
      SUBROUTINE CHGRID(FX,X,NX,FY,Y,NY)
      DIMENSION FX(NX),X(NX),FY(NY),Y(NY)
C  PIECEWISE QUADRATIC INTERPOLATION FROM GRID X TO GRID Y,  BY
C  AITKEN'S DIVIDED DIFFERENCE SCHEME.   NX,NY ARE ARRAY DIMENSIONS?
C  NOTE THAT NY IS RESET IN CHGRID
      IY=1
      DO 2 IX=3,NX
1     IF(IY.GT.NY)GOTO 3
      YY=Y(IY)
      IF(YY.GT.X(IX))GOTO 2
      A1=X(IX-2)-YY
      A2=X(IX-1)-YY
      A3=X(IX)-YY
      A12=(FX(IX-2)*A2-FX(IX-1)*A1)/(X(IX-1)-X(IX-2))
      A13=(FX(IX-2)*A3-FX(IX)*A1)/(X(IX)-X(IX-2))
      FY(IY)=(A12*A3-A13*A2)/(X(IX)-X(IX-1))
      IF(IY.GT.NY)GOTO 3
      IY=IY+1
      GOTO 1
2     CONTINUE
3     NY=IY-1
      RETURN
      END
C---------------------------------------------------------------------
      SUBROUTINE CLEMIN(RHO,RX,NX,NGRID)
      DIMENSION RHO(NGRID),RX(NGRID)
      REAL NAME(4),SUM
      COMMON /WK/ EX(20),FAC(20),FNT(20),NT(20)
      COMMON /WF/ WFC(250,14),WC(14),LC(14)
C  ROUTINE FOR INPUT OF WAVEFUNCTIONS IN THE CLEMENTI PARAMETRISED
C  FORM, AND CALCULATION OF CHARGE DENSITY ON RADIAL MESH RX
C    RHO = 4*PI*SUM OVER STATES OF (MODULUS(WAVE FN)**2) *
C          RADIUS**2
C    NC = NUMBER OF ATOMIC STATES
C  FOR EACH ATOMIC STATE I?
C    LC(I) = ANGULAR MOMENTUM
C    FRAC = FRACTIONAL OCCUPATION
C    WC(I) = NUMBER OF ELECTRONS
C    WFC(IX,I) = WAVEFUNCTION X RADIUS AT GRID POINT IX
      READ(4,100)NAME
      READ(4,101)IPRINT
      READ(4,101)NC

      DO 1 IC=1,NC
      DO 1 IG=1,NGRID
1     WFC(IG,IC)=0.0
C  INPUT OF CLEMENTI PARAMETERS
      IC=1
2     READ(4,101)NS
      IF(NS.LE.0)GOTO 8
      READ(4,102)(NT(I),EX(I),I=1,NS)
      DO 4 J=1,NS
      A=1.0
      B=2.0
      K=NT(J)
      C=FLOAT(K)
      KD=K+K
      DO 3 I=2,KD
      A=A*B
3     B=B+1.0
4     FNT(J)=EXP(-0.5*ALOG(A)+(C+0.5)*ALOG(2.0*EX(J)))
5     READ(4,101)LC(IC)
      IF(LC(IC).LT.0)GOTO 2
      READ(4,103)(FAC(J),J=1,NS)
      READ(4,103)FRAC
      WC(IC)=2.0*FLOAT(2*LC(IC)+1)*FRAC
      DO 7 IX=1,NGRID
      SUM=0.0D0
      DO 6 K=1,NS
      EXX=EX(K)*RX(IX)
      IF(EXX.GT.80.0)GOTO 6
      SUM=SUM+FAC(K)*FNT(K)*(RX(IX)**(NT(K)))*EXP(-EXX)
6     CONTINUE
7     WFC(IX,IC)=SUM
      IC=IC+1
      GOTO 5
C  CALCULATION OF CHARGE DENSITY
8     DO 10 IX=1,NGRID
      SUM=0.0D0
      DO 9 IC=1,NC
9     SUM=SUM+WC(IC)*WFC(IX,IC)*WFC(IX,IC)
      RHO(IX)=SUM
      IF(SUM.LT.1.0D-9)GOTO 11
10    CONTINUE
11    NX=IX
      IF(IPRINT.EQ.0)RETURN
      WRITE(11,200)NAME
      DO 12 IC=1,NC
12    WRITE(11,201)LC(IC),(WFC(IX,IC),IX=1,NGRID)
      WRITE(11,202)RX(NX),NX,(RHO(IX),IX=1,NX)
      RETURN
100   FORMAT(4A4)
101   FORMAT(I4)
102   FORMAT(I4,F11.5)
103   FORMAT(5F11.5)
200   FORMAT(1H1,4A4,32H ATOMIC WAVEFUNCTIONS (CLEMENTI),
     + 9H X RADIUS)
201   FORMAT(3H0L?,I3//5(10F11.5/))
202   FORMAT(29H0CHARGE DENSITY OUT TO RADIUS,F12.5,10X,
     + 3HNX?,I4//5(10E12.4/))
	  RETURN
      END
C---------------------------------------------------------------------
      SUBROUTINE HSIN(RHO,RX,NX,NGRID)
      DIMENSION RHO(NGRID),RX(NGRID)
      REAL NAME(4),SUM
      COMMON /WK/ RR(250),RS(250)
      COMMON /WF/ WFC(250,14),WC(14),LC(14)
C  ROUTINE FOR INPUT OF ATOMIC WAVEFUNCTIONS FROM HERMAN-SKILLMAN
C  TABLES, AND CALCULATION OF CHARGE DENSITY ON THE RADIAL MESH RX
C    RHO = 4*PI*SUM OVER STATES OF (MODULUS(WAVE FN)**2) *
C          RADIUS**2
C    NM ? H-S GRID INTERVAL DOUBLES EVERY NM MESH POINTS
C    NC = NUMBER OF ATOMIC STATES
C FOR EACH ATOMIC STATE I?
C    LC(I) = ANGULAR MOMENTUM
C    FRAC = FRACTIONAL OCCUPATION
C    WC(I) = NUMBER OF ELECTRONS
C    WFC(IX,I) = WAVEFUNCTION X RADIUS AT GRID POINT IX
      READ(4,100)NAME,Z
      READ(4,101)IPRINT
      READ(4,101)NM
      READ(4,101)NC
      DO 1 IG=1,250
      RS(IG)=0.0
      DO 1 IC=1,NC
1     WFC(IG,IC)=0.0
C INITIALISATION OF HERMAN-SKILLMAN MESH
      DR=0.005*0.88534138/EXP(ALOG(Z)/3.0)
      RR(1)=0.0
      DO 2 I=2,250
      IF(MOD(I,NM).EQ.2)DR=DR+DR
2     RR(I)=RR(I-1)+DR
      NS=0
      DO 3 IC=1,NC
      READ(4,101)LC(IC),N,FRAC
      NS=MAX0(NS,N)
      WC(IC)=2.0*FLOAT(2*LC(IC)+1)*FRAC
3     READ(4,102)(WFC(IX,IC),IX=1,N)
C  CALCULATION OF CHARGE DENSITY
      DO 5 IX=1,NS
      SUM=0.0D0
      DO 4 IC=1,NC
4     SUM=SUM+WC(IC)*WFC(IX,IC)*WFC(IX,IC)
5     RS(IX)=SUM
C  INTERPOLATION TO GRID RX
      NX=NGRID
      CALL CHGRID(RS,RR,NS,RHO,RX,NX)
      IF(IPRINT.EQ.0)RETURN
      WRITE(11,200)NAME,(RR(IX),IX=1,NS)
      DO 6 IC=1,NC
6     WRITE(11,201)LC(IC),(WFC(IX,IC),IX=1,NS)
      DO 7 IX=1,NX
      IF(RHO(IX).LT.1.0E-9)GOTO 8
7     CONTINUE
8     NX=IX
      WRITE(11,202)RX(NX),NX,(RHO(IX),IX=1,NX)
      RETURN
100   FORMAT(4A4/F9.4)
101   FORMAT(2I4,F9.4)
102   FORMAT(5F9.4)
200   FORMAT(1H1,4A4,39H ATOMIC WAVEFUNCTIONS (HERMAN-SKILLMAN),
     + 9H X RADIUS//21H HERMAN-SKILLMAN MESH//5(10F12.5/))
201   FORMAT(3H0L?,I3//5(10F11.5/))
202   FORMAT(29H0CHARGE DENSITY OUT TO RADIUS,F12.5,10X,
     + 3HNX?,I4//5(10E12.4/))
      END
C---------------------------------------------------------------------
      SUBROUTINE MAD(VMAD,RX,NGRID,RMT,NRR,NX,NR,RC,RK,ZM,N,AV)
      DIMENSION VMAD(NGRID,NR),RX(NGRID),RC(3,3),RK(3,N),ZM(N),
     + RMT(NR),NRR(NR),NX(NR)
      COMMON /WK/ G(3,3),VMM(5),FR(5),RA(3),GA(3)
      DATA PI,TEST/3.1415926536,1.0E-4/
      RAD(A1,A2,A3)=SQRT(A1*A1+A2*A2+A3*A3)
C  SUBROUTINE MAD CALCULATES THE SPHERICALLY AND SPATIALLY AVERAGED
C  FIELDS FROM A LATTICE OF POINT CHARGES, AND TABULATES THEM ON
C  A RADIAL MESH RX, ABOUT EACH ATOMIC TYPE IN THE UNIT CELL
C  ** NB THIS ROUTINE WORKS IN HARTREES, BUT CONVERTS TO RYDBERGS **
C  RC(I,J) = THE I'TH COORDINATE OF THE J'TH AXIS OF THE UNIT CELL
C  RK(I,J) = THE I'TH COORDINATE OF THE J'TH ATOM IN THE UNIT CELL
C  VMAD(J,IR) = THE J'TH TABULATED VALUE OF THE SPHERICALLY AVERAGED
C  POTENTIAL ABOUT A TYPE-IR ATOM
C  ZM(K)=CHARGE ON THE K'TH ATOM
C  RMT(IR) = MUFFIN-TIN RADIUS OF A TYPE-IR ATOM
C  NR = NUMBER OF INEQUIVALENT ATOMS IN THE CELL
C  AV = VOLUME OF UNIT CELL
C  G(I,J) = I'TH COORDINATE OF THE J'TH RECIPROCAL LATTICE VECTOR
C  VMM(IR) = THE INTEGRAL OF THE POTENTIAL ABOUT A TYPE-IR ATOM
C  OUT TO THE MUFFIN-TIN RADIUS
C
      DO 1 IR=1,NR
      FR(IR)=0.0
      DO 1 J=1,NGRID
1     VMAD(J,IR)=0.0
C  THE RECIPROCAL LATTICE IS DEFINED BY THREE VECTORS, G
      ATV=2.0*PI/AV
      G(1,1)=(RC(2,1)*RC(3,2)-RC(3,1)*RC(2,2))*ATV
      G(2,1)=(RC(3,1)*RC(1,2)-RC(1,1)*RC(3,2))*ATV
      G(3,1)=(RC(1,1)*RC(2,2)-RC(2,1)*RC(1,2))*ATV
C
      G(1,2)=(RC(2,2)*RC(3,3)-RC(3,2)*RC(2,3))*ATV
      G(2,2)=(RC(3,2)*RC(1,3)-RC(1,2)*RC(3,3))*ATV
      G(3,2)=(RC(1,2)*RC(2,3)-RC(2,2)*RC(1,3))*ATV
C
      G(1,3)=(RC(2,3)*RC(3,1)-RC(3,3)*RC(2,1))*ATV
      G(2,3)=(RC(3,3)*RC(1,1)-RC(1,3)*RC(3,1))*ATV
      G(3,3)=(RC(1,3)*RC(2,1)-RC(2,3)*RC(1,1))*ATV
C
C  MAXIMUM VALUE OF RK, AND MINIMUM VALUES OF RC,G - PRIOR TO
C  CHOOSING THE SEPARATION CONSTANT AL AND LIMITS FOR
C  SUMMATIONS
      RKMAX=0.0
      DO 2 J=1,N
2     RKMAX=AMAX1(RKMAX,RAD(RK(1,J),RK(2,J),RK(3,J)))
      RCMIN=1.0E6
      GMIN=1.0E6
      DO 3 J=1,3
      RCMIN=AMIN1(RCMIN,RAD(RC(1,J),RC(2,J),RC(3,J)))
3     GMIN=AMIN1(GMIN,RAD(G(1,J),G(2,J),G(3,J)))
C  AL IS CHOSEN TO GIVE EQUAL NUMBERS OF TERMS IN REAL AND
C  RECIPROCAL SPACE SUMMATIONS
      FAC1=TEST*ALOG(TEST)**4
      FAC2=(4.0*PI*RCMIN**4)/(AV*GMIN**4)
      AL=EXP(ALOG(FAC1/FAC2)/6.0)
      ITR=1+IFIX((AL*RKMAX-ALOG(TEST))/(AL*RCMIN))
      LIMR=ITR+ITR+1
      FAC1=4.0*PI*AL*AL/(AV*GMIN**4)
      ITG=1+IFIX(EXP(ALOG(FAC1/TEST)/4.0))
      LIMG=ITG+ITG+1
      WRITE(11,200)((G(I,J),I=1,3),J=1,3)
      WRITE(11,201)RCMIN,GMIN,RKMAX,TEST,AL
C
C  REAL SPACE SUMMATION
      WRITE(11,202)ITR
C  THE PREFACTORS FR FROM THE REAL SPACE SUMMATION ARE CALCULATED
      AS=-FLOAT(ITR)-1.0
      AX=AS
      DO 5 JX=1,LIMR
      AX=AX+1.0
      AY=AS
      DO 5 JY=1,LIMR
      AY=AY+1.0
      AZ=AS
      DO 5 JZ=1,LIMR
      AZ=AZ+1.0
      DO 4 I=1,3
4     RA(I)=AX*RC(I,1)+AY*RC(I,2)+AZ*RC(I,3)
      DO 5 J=1,N
      K=1
      DO 5 KR=1,NR
      R=RAD(RA(1)+RK(1,J)-RK(1,K),RA(2)+RK(2,J)-RK(2,K),
     + RA(3)+RK(3,J)-RK(3,K))
      IF(R.LT.1.0E-4)GOTO 5
      FR(KR)=FR(KR)+ZM(J)*EXP(-AL*R)/R
5     K=K+NRR(KR)
      K=1
      DO 7 KR=1,NR
      X=RMT(KR)
      A=EXP(-AL*X)
      AI1=((1.0-A)/AL-X*A)/AL
      AI2=(X*0.5*(1.0/A+A)-0.5*(1.0/A-A)/AL)/AL/AL
      VMM(KR)=4.0*PI*(ZM(K)*AI1+AI2*FR(KR))
      NIX=NX(KR)
      DO 6 J=1,NIX
      X=RX(J)
      A=EXP(AL*X)
6     VMAD(J,KR)=FR(KR)*0.5*(A-1.0/A)/(AL*X)+ZM(K)/(A*X)
7     K=K+NRR(KR)
      WRITE(11,203)(VMM(KR),KR=1,NR)
C
C  NEXT COMES THE SUMMATION IN RECIPROCAL SPACE
      WRITE(11,204)ITG
      AS=-FLOAT(ITG)-1.0
      AX=AS
      DO 13 JX=1,LIMG
      AX=AX+1.0
      AY=AS
      DO 13 JY=1,LIMG
      AY=AY+1.0
      AZ=AS
      DO 13 JZ=1,LIMG
      AZ=AZ+1.0
      DO 8 I=1,3
8     GA(I)=AX*G(I,1)+AY*G(I,2)+AZ*G(I,3)
      GM=RAD(GA(1),GA(2),GA(3))
      GS=GM*GM
      FAC1=0.0
      IF(GS.LT.1.0E-4)GOTO 13
      FAC1=4.0*PI*AL*AL/(AV*GS*(GS+AL*AL))
      K=1
      DO 12 KR=1,NR
      FAC2=0.0
      DO 10 J=1,N
      GR=0.0
      DO 9 I=1,3
9     GR=GR+GA(I)*(RK(I,K)-RK(I,J))
10    FAC2=FAC2+COS(GR)*ZM(J)
      X=RMT(KR)
      AI3=(SIN(GM*X)/GM-X*COS(GM*X))/GS
      VMM(KR)=VMM(KR)+4.0*PI*AI3*FAC1*FAC2
      NIX=NX(KR)
      DO 11 I=1,NIX
      X=RX(I)
11    VMAD(I,KR)=VMAD(I,KR)+FAC1*FAC2*SIN(GM*X)/(GM*X)
12    K=K+NRR(KR)
13    CONTINUE
      WRITE(11,203)(VMM(KR),KR=1,NR)
C  REFER TO MUFFIN-TIN ZERO
      VM=0.0
      AMT=0.0
      DO 14 IR=1,NR
      VM=VM+FLOAT(NRR(IR))*RMT(IR)**3
14    AMT=AMT+FLOAT(NRR(IR))*VMM(IR)
      AMT=AMT/(AV-4.0*PI*VM/3.0)
C  EXPRESS THE FINAL POTENTIAL IN RYDBERGS
      AMT=-2.0*AMT
      WRITE(11,205)AMT
      DO 15 KR=1,NR
      NIX=NX(KR)
      DO 15 J=1,NIX
15    VMAD(J,KR)=2.0*VMAD(J,KR)-AMT
      RETURN
C
200   FORMAT(///20H0MADELUNG CORRECTION//
     + 19H0RECIPROCAL LATTICE/(6X,3F8.4))
201   FORMAT(7H0RCMIN?,F10.4,10X,5HGMIN?,F10.4,10X,6HRKMAX?,F10.4,
     + 10X,5HTEST?,E12.4/21H SEPARATION CONSTANT?,E12.4)
202   FORMAT(21H0REAL SPACE SUMMATION,11X,4HITR?,I3)
203   FORMAT(17H VMM (HARTREES) ?,5E12.4)
204   FORMAT(27H0RECIPROCAL SPACE SUMMATION,5X,4HITG?,I3)
205   FORMAT(26H0MADELUNG MUFFIN-TIN ZERO?,5E12.4)
C
      END
C---------------------------------------------------------------------
      SUBROUTINE MTZ(SIG,RHO,RX,NGRID,RMT,NRR,NX,NR,
     + RC,RK,N,VHAR,VEX,ALPHA,AV,NH)
      DIMENSION SIG(NGRID,NR),RHO(NGRID,NR),RX(NGRID),RMT(NR),
     + NRR(NR),NX(NR),VG(20),RC(3,3),RK(3,N)
      COMMON /WK/ X(3),RB(3)
      DATA PI,NG/3.14159265358,20/
C  GRID REFERENCE FOR RADIUS ON LOUCKS' MESH
      INDEX(y)=20.0*(ALOG(y)+8.8)+1.0
      RAD(A1,A2,A3)=SQRT(A1*A1+A2*A2+A3*A3)
C  SUBROUTINE FOR CALCULATION OF THE MUFFIN-TIN ZERO LEVEL?
C  THE AVERAGE VALUE OF THE POTENTIAL BETWEEN THE MUFFIN-TIN
C  SPHERES IN THE UNIT CELL
C
      PD=6.0/PI/PI
      DO 12 IG=1,NG
12    VG(IG)=0.0
      IG=0
      VHAR=0.0
      VEX=0.0
      NPOINT=0
      NINT=0
      DH=1.0/FLOAT(NH)
1     AH=DH/2.0
      AX=-AH
      DO 7 IX=1,NH
      AX=AX+DH
      AY=-AH
      DO 7 IY=1,NH
      AY=AY+DH
      AZ=-AH
      DO 7 IZ=1,NH
      AZ=AZ+DH
      DO 2 I=1,3
2     X(I)=AX*RC(I,1)+AY*RC(I,2)+AZ*RC(I,3)
      NPOINT=NPOINT+1
C  GIVES SAMPLE POINT X INSIDE THE UNIT CELL - TEST WHETHER
C  INTERSTITIAL
      BX=-1.0
      DO 4 JX=1,2
      BX=BX+1.0
      BY=-1.0
      DO 4 JY=1,2
      BY=BY+1.0
      BZ=-1.0
      DO 4 JZ=1,2
      BZ=BZ+1.0
      DO 3 I=1,3
3     RB(I)=X(I)-BX*RC(I,1)-BY*RC(I,2)-BZ*RC(I,3)
      I=0
      DO 4 IR=1,NR
      INR=NRR(IR)
      DO 4 IIR=1,INR
      I=I+1
      XR=RAD(RB(1)-RK(1,I),RB(2)-RK(2,I),RB(3)-RK(3,I))
      IF(XR.LT.RMT(IR))GOTO 7
4     CONTINUE
C  WE HAVE AN INTERSTITIAL POINT
      NINT=NINT+1
C  SUM COULOMB AND EXCHANGE ENERGIES FROM ATOMS WITHIN 2 UNIT
C  CELLS AROUND THIS POINT
      SUMC=0.0
      SUME=0.0
      BX=-3.0
      DO 6 JX=1,5
      BX=BX+1.0
      BY=-3.0
      DO 6 JY=1,5
      BY=BY+1.0
      BZ=-3.0
      DO 6 JZ=1,5
      BZ=BZ+1.0
      DO 5 I=1,3
5     RB(I)=BX*RC(I,1)+BY*RC(I,2)+BZ*RC(I,3)-X(I)
      J=0
      DO 6 JR=1,NR
      JNR=NRR(JR)
      DO 6 JJR=1,JNR
      J=J+1
      XR=RAD(RB(1)+RK(1,J),RB(2)+RK(2,J),RB(3)+RK(3,J))
      J2=INDEX(XR)
      IF(J2.GE.NX(JR))GOTO 6
      J1=J2-1
      J3=J2+1
      X1=RX(J1)
      X2=RX(J2)
      X3=RX(J3)
      TERMC=(XR-X2)*(XR-X3)/(X1-X2)/(X1-X3)*SIG(J1,JR)
     1     +(XR-X1)*(XR-X3)/(X2-X1)/(X2-X3)*SIG(J2,JR)
     1     +(XR-X2)*(XR-X1)/(X3-X2)/(X3-X1)*SIG(J3,JR)
      TERME=(XR-X2)*(XR-X3)/(X1-X2)/(X1-X3)*RHO(J1,JR)
     1     +(XR-X1)*(XR-X3)/(X2-X1)/(X2-X3)*RHO(J2,JR)
     1     +(XR-X2)*(XR-X1)/(X3-X2)/(X3-X1)*RHO(J3,JR)
      SUMC=SUMC+TERMC
      SUME=SUME+TERME
6     CONTINUE
C
      IF(SUME.LE.1.E-8) THEN
	SUME=.0
      ELSE
	SUME=-1.5*ALPHA*(PD*SUME)**(1./3.)
      ENDIF
      VHAR=VHAR+SUMC
      VEX=VEX+SUME
      JG=MOD(IG,20)+1
      VG(JG)=VG(JG)+SUMC+SUME
      IG=IG+1
7     CONTINUE
      DH=DH/2.0
      NH=NH+NH
      IF(NINT.EQ.0)GOTO 1
C
      ANT=FLOAT(NINT)
      VHAR=VHAR/ANT
      VEX=VEX/ANT
      VINT=VHAR+VEX
C  ESTIMATE STANDARD DEVIATION
      IF(NINT.LT.NG)NG=NINT
      NAG=NINT/NG
      AG=FLOAT(NAG)
      DO 10 IG=1,NG
10    VG(IG)=VG(IG)/AG
      VAR=0.0
      DO 11 IG=1,NG
11    VAR=VAR+(VINT-VG(IG))**2
      VAR=SQRT(VAR/FLOAT(NG*(NG-1)))
C  THE CURRENT MONTE-CARLO VOLUME FOR THE INTERSTITIAL REGION
C  IS VOLC
      VOLC=ANT/FLOAT(NPOINT)*AV
C  VOLT IS THE TRUE VOLUME OF THE REGION BETWEEN MUFFIN-TIN
C  SPHERES IN THE UNIT CELL
      VM=0.0
      DO 8 IR=1,NR
8     VM=VM+FLOAT(NRR(IR))*RMT(IR)**3
      VOLT=AV-4.0*PI*VM/3.0
C
      WRITE(11,200)NINT,NPOINT,NG,NAG,VOLT,VOLC
      WRITE(11,201)VHAR,VEX,VINT,VAR
C
      RETURN
200   FORMAT(///43H0MUFFIN-TIN ZERO CALCULATION, SAMPLING WITH,I6,
     + 20H POINTS FROM GRID OF,I6/24H VARIANCE ESTIMATED FROM,
     + I4,10H GROUPS OF,I5//36H TRUE VOLUME OF INTERSTITIAL REGION?,
     + F11.4,5X,19HMONTE-CARLO VOLUME?,11X,F9.4)
201   FORMAT(27H AVERAGE HARTREE POTENTIAL?,6X,F14.5,5X,
     + 27HAVERAGE EXCHANGE POTENTIAL?,F12.5/
     + 17H0MUFFIN-TIN ZERO?,F12.5,10X,19HSTANDARD DEVIATION?,F12.5)
      END
C---------------------------------------------------------------------
      SUBROUTINE MTZM(VH,VS,RX,NGRID,RMT,RWS,JRMT,JRWS,VHAR,VEX)
      DIMENSION VH(NGRID),VS(NGRID),RX(NGRID)
      DOUBLE PRECISION SUMH,SUME
C  SUBROUTINE FOR CALCULATION OF THE MUFFIN-TIN ZERO LEVEL FOR
C  MONOATOMIC CRYSTALS, USING A SPHERICAL AVERAGE OF THE POTENTIAL
C  BETWEEN MUFFIN-TIN RADIUS AND WIGNER-SEITZ RADIUS, AS IN EQ 3.31
C  OF LOUCKS, TRANSFORMED TO THE EXPONENTIAL GRID RX?
C                       RX(I)=EXP(-8.8+0.05(I-1))
C  INTEGRATION BY TRAPEZIUM RULE.  JRMT,JRWS ARE GRID POINTS OUTSIDE
C  MUFFIN-TIN RADIUS AND WIGNER-SEITZ RADIUS RESPECTIVELY
      DX=0.05
      DDX=0.5*DX
      DXX=EXP(3.*DX)
      X=ALOG(RX(JRMT)/RMT)
      RDX=X/DX
      XX=RX(JRMT-1)**3
      XXMT=XX*DXX
      SUMH=0.5*X*(RDX*XX*VH(JRMT-1)+(2.-RDX)*XXMT*VH(JRMT))
      SUME=0.5*X*(RDX*XX*VS(JRMT-1)+(2.-RDX)*XXMT*VS(JRMT))
      XX=XXMT
      JRW=JRWS-1
      IF(JRMT.EQ.JRW)GOTO 2
      VH1=DDX*XX*VH(JRMT)
      VX1=DDX*XX*VS(JRMT)
      JRM=JRMT+1
      DO 1 J=JRM,JRW
      XX=XX*DXX
      VH2=DDX*XX*VH(J)
      VX2=DDX*XX*VS(J)
      SUMH=SUMH+VH1+VH2
      SUME=SUME+VX1+VX2
      VH1=VH2
1     VX1=VX2
2     X=ALOG(RWS/RX(JRW))
      RDX=X/DX
      XXWS=XX*DXX
      SUMH=SUMH+0.5*X*((2.-RDX)*XX*VH(JRW)+RDX*XXWS*VH(JRWS))
      SUME=SUME+0.5*X*((2.-RDX)*XX*VS(JRW)+RDX*XXWS*VS(JRWS))
      C=3./(RWS*RWS*RWS-RMT*RMT*RMT)
      VHAR=C*SUMH
      VEX=C*SUME
      VINT=VHAR+VEX
      WRITE(11,200)VHAR,VEX,VINT
      RETURN
C
200   FORMAT(///37H0MUFFIN-TIN ZERO BY SPHERICAL AVERAGE,/
     + 27H AVERAGE HARTREE POTENTIAL?,6X,F14.5,5X,
     + 27HAVERAGE EXCHANGE POTENTIAL?,F12.5,/
     + 17H0MUFFIN-TIN ZERO?,F12.5)
      END
C---------------------------------------------------------------------
      SUBROUTINE NBR(IA,NA,AD,NCON,NRR,NR,RC,RK,N,RMAX,MC)
      DIMENSION IA(MC,NR),NA(MC,NR),AD(MC,NR),NCON(NR),NRR(NR),
     + RC(3,3),RK(3,N)
      COMMON /WK/ RJ(3)
      RAD(A1,A2,A3)=SQRT(A1*A1+A2*A2+A3*A3)
C  ROUTINE TO SUPPLY NEAREST NEIGHBOUR DATA FOR ATOMS IN
C  A CRYSTAL STRUCTURE, GIVEN?
C  RC(I,J)? THE I'TH COORDINATE OF THE J'TH AXIS OF THE UNIT CELL
C  RK(I,J)? THE I'TH COORDINATE OF THE J'TH ATOM IN THE UNIT CELL
C  NRR(IR)? THE NUMBER OF TYPE-IR ATOMS IN THE UNIT CELL
C  THE INFORMATION RETURNED, FOR A TYPE-IR ATOM, IS
C  NCON(IR)? THE NUMBER OF NEAREST NEIGHBOUR SHELLS OF A TYPE-IR
C  ATOM INCLUDED, OUT TO A DISTANCE OF RMAX, BUT .LE. MC
C  IA(J,IR)? THE TYPE OF ATOMS IN THE J'TH NEIGHBOURING SHELL
C  NA(J,IR)? THE NUMBER OF ATOMS IN THE J'TH SHELL
C  AD(J,IR)? THE RADIUS OF THE J'TH SHELL
C  INITIALISATION
      RCMIN=1.0E6
      DO 1 I=1,3
1     RCMIN=AMIN1(RCMIN,RAD(RC(1,I),RC(2,I),RC(3,I)))
      DO 2 IR=1,NR
      DO 2 IC=1,MC
      IA(IC,IR)=0
      NA(IC,IR)=0
2     AD(IC,IR)=1.0E6
C  SEARCH OVER ADJACENT UNIT CELLS TO INCLUDE MC NEAREST NEIGHBOURS
      ITC=IFIX(RMAX/RCMIN)+1
      LIMC=ITC+ITC+1
      AS=-FLOAT(ITC+1)
      AX=AS
      DO 10 JX=1,LIMC
      AX=AX+1.0
      AY=AS
      DO 10 JY=1,LIMC
      AY=AY+1.0
      AZ=AS
      DO 10 JZ=1,LIMC
      AZ=AZ+1.0
      DO 3 J=1,3
3     RJ(J)=AX*RC(J,1)+AY*RC(J,2)+AZ*RC(J,3)
C  RJ IS CURRENT UNIT CELL ORIGIN.  FOR EACH ATOM IN THIS UNIT CELL
C  FIND DISPLACEMENT R FROM KR-TYPE ATOM IN BASIC UNIT CELL
      J=0
      DO 10 JR=1,NR
      JNR=NRR(JR)
      DO 10 JJR=1,JNR
      J=J+1
      K=1
      DO 9 KR=1,NR
      R=RAD(RJ(1)+RK(1,J)-RK(1,K),RJ(2)+RK(2,J)-RK(2,K),
     + RJ(3)+RK(3,J)-RK(3,K))
      IF(R.GT.RMAX)GOTO 9
C  COMPARE R WITH NEAREST NEIGHBOUR DISTANCES ALREADY FOUND
      IC=0
4     IC=IC+1
      IF(IC.GT.MC)GOTO 9
      DR=R-AD(IC,KR)
      IF(ABS(DR).LT.1.0E-4)DR=0.0
      IF(DR)6,5,4
5     IF(IA(IC,KR).NE.JR)GOTO 4
      NA(IC,KR)=NA(IC,KR)+1
      GOTO 9
6     IF(IC.EQ.MC)GOTO 8
      IIC=IC+1
      DO 7 JJC=IIC,MC
      JC=MC+IIC-JJC
      IA(JC,KR)=IA(JC-1,KR)
      NA(JC,KR)=NA(JC-1,KR)
7     AD(JC,KR)=AD(JC-1,KR)
8     IA(IC,KR)=JR
      NA(IC,KR)=1
      AD(IC,KR)=R
9     K=K+NRR(KR)
10     CONTINUE
      DO 12 IR=1,NR
      NCON(IR)=0
      DO 11 IC=1,MC
      IF(NA(IC,IR).EQ.0)GOTO 12
11    NCON(IR)=NCON(IR)+1
12    CONTINUE
      RETURN
      END
C---------------------------------------------------------------------
      SUBROUTINE POISON(PSQ,Z,J,W)
      DIMENSION PSQ(J),W(J)
      DOUBLE PRECISION E(250),F(250),ACC,A,B,C,D,C2
C TAKEN FROM LOUCKS' BOOK, APPENDIX 1
      A=1.0D0-0.0025D0/48.0D0
C EQ. A1.11
      B=-2.0D0-0.025D0/48.0D0
C EQ. A1.12
      C=0.0025D0/6.0D0
      D=DEXP(0.025D0)
      C2=-B/A
      E(1)=0.0D0
C EQ. A1.29
      F(1)=D
C EQ.A1.30
      X=-8.75
      J1=J-1
      DO 1 I=2,J1
      ACC=C*EXP(0.5*X)*(D*PSQ(I+1)+10.0*PSQ(I)+PSQ(I-1)/D)
C EQS. A1.13, A1.6
      F(I)=C2-1.0/F(I-1)
C EQ. A1.20
      E(I)=(ACC/A+E(I-1))/F(I)
C EQ. A1.21
1     X=X+0.05
      W(J)=2.0*Z*EXP(-0.5*X)
      ACC=W(J)
      DO 2 I=1,J1
      JC=J-I
      ACC=E(JC)+ACC/F(JC)
2     W(JC)=ACC
C EQ.A1.15
      RETURN
      END
C---------------------------------------------------------------------
      SUBROUTINE RELA(RHO,RX,NX,NGRID)
      DIMENSION RHO(NGRID),RX(NGRID)
      REAL NAME(4),SUM
      COMMON /WK/ RR(2000),RS(2000)
C  ROUTINE FOR INPUT OF CHARGE DENSITY FROM RELATIVISTIC ORBITALS
C  (ERIC SHIRLEY PROGRAM), AND CALCULATION OF CHARGE DENSITY ON
C  THE RADIAL MESH RX
C    RHO = 4*PI*SUM OVER STATES OF (MODULUS(WAVE FN)**2) *
C          RADIUS**2
C    RMIN= minimum radial coordinate defining the logarithmic mesh used
C          in relativistic calculation
C    RMAX= maximum radial coordinate defining the logarithmic mesh used
C          in relativistic calculation
C    NR  = number of points in the mesh
C the mesh is defined as r(i)=rmin*(rmax/rmin)**(dfloat(i)/dfloat(nr))
C FOR EACH ATOMIC STATE I?
      READ(4,100)NAME,IPRINT
      read(4,54) rmin,rmax,nr,z
54    format (d15.8,d15.8,i5,f5.2)
c
c initialization of logarithmic grid
c
	do 5 i=1,nr
	   rr(i)=rmin*(rmax/rmin)**(dfloat(i)/dfloat(nr))
5       continue
      NS=nr
C  read in charge density
	read(4,56) (rs(j),j=1,nr)
56      format (f15.10)
c
c  INTERPOLATION TO GRID RX
c
      NX=NGRID
      CALL CHGRID(RS,RR,NS,RHO,RX,NX)
      IF(IPRINT.EQ.0)RETURN
      WRITE(11,200)NAME,(RR(IX),IX=1,NS)
C      write(11,200)(RR(IX),IX=1,NS)
      DO 7 IX=1,NX
      IF(RHO(IX).LT.1.0E-9)GOTO 8
7     CONTINUE
8     NX=IX
      WRITE(11,202)RX(NX),NX,(RHO(IX),IX=1,NX)
      RETURN
100   FORMAT(4A4/I4)
102   FORMAT(5F9.4)
200   FORMAT(1H1,4A4,36H RELAT. WAVEFUNCTIONS (ERIC SHIRLEY),
     + 9H R RADIUS,17H LOGARITHMIC MESH,/(10F12.5/))
201   FORMAT(3H0L?,I3//5(10F11.5/))
202   FORMAT(29H0CHARGE DENSITY OUT TO RADIUS,F12.5,10X,
     + 3HNX?,I4//5(10E12.4/))
      END
C---------------------------------------------------------------------
      SUBROUTINE SUMAX(ACC,CHI,RX,NX,NCON,IA,NA,AD,IMAX,NGRID,NR)
      DIMENSION ACC(NGRID),CHI(NGRID,NR),RX(NGRID),NX(NR),
     + IA(NCON),NA(NCON),AD(NCON)
      DOUBLE PRECISION SUM
C  ROUTINE TO PERFORM THE SUMMATION OF CONTRIBUTIONS FROM
C  NEIGHBOURING ATOMS (EQ. 3.22,3.26,3.28).  INTEGRATION BY
C  TRAPEZIUM RULE ON RADIAL GRID  RX(I)=EXP(-8.8+0.05(I-1))
      INDEX(X)=20.*(ALOG(X)+8.8)+2.
      DX=0.05
      DDX=0.5*DX
      DXX=EXP(2.*DX)
      IC=IA(1)
      DO 1 I=1,IMAX
1     ACC(I)=CHI(I,IC)
      DO 4 JA=2,NCON
      IC=IA(JA)
      NIX=NX(IC)
      DO 4 I=1,IMAX
      SUM=0.0D0
      X1=ABS(RX(I)-AD(JA))
      IX1=INDEX(X1)
      IF(IX1.GT.NIX)GOTO 4
      DX1=ALOG(RX(IX1)/X1)
      RDX1=DX1/DX
      X2=AMIN1((RX(I)+AD(JA)),RX(NIX))
      IX2=MIN0(INDEX(X2),NIX)
      DX2=ALOG(RX(IX2)/X2)
      RDX2=DX2/DX
      XX=RX(IX2-1)**2
      XX1=XX*DXX
      IF(IX1.EQ.IX2)GOTO 3
      SUM=SUM+0.5*DX2*((2.-RDX2)*XX*CHI(IX2-1,IC)+
     + RDX2*XX1*CHI(IX2,IC))
      XX=RX(IX1-1)**2
      XX1=XX*DXX
      SUM=SUM+0.5*DX1*(RDX1*XX*CHI(IX1-1,IC)+
     + (2.-RDX1)*XX1*CHI(IX1,IC))
      IX1=IX1+1
      IF(IX1.EQ.IX2)GOTO 4
      XX=XX1
      T1=DDX*XX*CHI(IX1,IC)
      IX2=IX2-1
      DO 2 IX=IX1,IX2
      XX=XX*DXX
      T2=DDX*XX*CHI(IX,IC)
      SUM=SUM+T1+T2
2     T1=T2
      GOTO 4
3     SUM=0.5*(DX2-DX1)*((RDX1+RDX2)*XX*CHI(IX1-1,IC)+
     + (2.-RDX1-RDX2)*XX1*CHI(IX1,IC))
4     ACC(I)=ACC(I)+0.5*SUM*FLOAT(NA(JA))/(AD(JA)*RX(I))
      RETURN
      END
