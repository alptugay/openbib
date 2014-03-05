--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = public, pg_catalog;

TRUNCATE table topicclassification;


--
-- Data for Name: topicclassification; Type: TABLE DATA; Schema: public; Owner: root
--

COPY topicclassification (topicid, classification, type) FROM stdin;
18	01	BK
18	02	BK
18	10	BK
2	15	BK
20	73	BK
12	79	BK
12	80	BK
12	81	BK
15	05	BK
15	06	BK
15	54	BK
13	20	BK
13	21	BK
4	SA-SP	EZB
6	44	BK
6	46	BK
14	24	BK
10	08	BK
1	33	BK
1	35	BK
1	42	BK
11	77	BK
3	86	BK
19	74	BK
19	43	BK
19	38	BK
19	30	BK
8	70	BK
8	71	BK
8	89	BK
17	76	BK
7	17	BK
7	18	BK
9	50	BK
9	51	BK
9	52	BK
9	53	BK
9	55	BK
9	56	BK
9	57	BK
9	58	BK
16	11	BK
5	48	BK
5	49	BK
5	83	BK
5	85	BK
5	88	BK
4	2	DBIS
4	31	BK
15	AN	EZB
15	SQ-SU	EZB
15	53	DBIS
15	54	DBIS
15	30	DBIS
2	DD	EZB
2	LD-LG	EZB
2	27	DBIS
2	26	DBIS
20	LA-LC	EZB
20	29	DBIS
12	DD	EZB
12	D	EZB
12	23	DBIS
18	AZ	EZB
18	13	DBIS
13	LH-LO	EZB
13	24	DBIS
6	WW-YZ	EZB
14	LP-LZ	EZB
14	53	DBIS
14	25	DBIS
10	CA-CI	EZB
10	21	DBIS
1	W	EZB
1	V	EZB
1	U	EZB
1	5	DBIS
1	3	DBIS
1	1	DBIS
11	CL-CZ	EZB
11	22	DBIS
3	P	EZB
3	15	DBIS
19	R	EZB
19	TE-TZ	EZB
19	TA-TD	EZB
19	6	DBIS
19	7	DBIS
19	50	DBIS
18	E	EZB
18	28	DBIS
8	MA-MM	EZB
8	MN-MS	EZB
8	17	DBIS
8	18	DBIS
17	ZX-ZY	EZB
7	E	EZB
7	H	EZB
7	G	EZB
7	F	EZB
7	I	EZB
7	K	EZB
7	13	DBIS
7	12	DBIS
7	9	DBIS
7	10	DBIS
7	51	DBIS
9	ZH-ZI	EZB
9	ZN	EZB
9	ZP	EZB
9	ZA-ZE	EZB
9	ZL	EZB
9	ZG	EZB
9	ZM	EZB
9	52	DBIS
9	44	DBIS
9	47	DBIS
16	B	EZB
16	19	DBIS
5	MN-MS	EZB
5	ZA-ZE	EZB
5	18	DBIS
5	16	DBIS
5	Q	EZB
18	TA-TD	EZB
18	ZG	EZB
18	50	DBIS
18	44	DBIS
15	AP	EZB
15	AK-AL	EZB
15	55	DBIS
2	N	EZB
18	01	bk
18	02	bk
18	10	bk
2	15	bk
20	73	bk
12	79	bk
12	80	bk
12	81	bk
15	05	bk
15	06	bk
15	54	bk
13	20	bk
13	21	bk
4	SA-SP	ezb
6	44	bk
6	46	bk
14	24	bk
10	08	bk
1	33	bk
1	35	bk
1	42	bk
11	77	bk
3	86	bk
19	74	bk
19	43	bk
19	38	bk
19	30	bk
8	70	bk
8	71	bk
8	89	bk
17	76	bk
7	17	bk
7	18	bk
9	50	bk
9	51	bk
9	52	bk
9	53	bk
9	55	bk
9	56	bk
9	57	bk
9	58	bk
16	11	bk
5	48	bk
5	49	bk
5	83	bk
5	85	bk
5	88	bk
4	2	dbis
4	31	bk
15	AN	ezb
15	SQ-SU	ezb
15	53	dbis
15	54	dbis
15	30	dbis
2	DD	ezb
2	LD-LG	ezb
2	27	dbis
2	26	dbis
20	LA-LC	ezb
20	29	dbis
12	DD	ezb
12	D	ezb
12	23	dbis
18	AZ	ezb
18	13	dbis
13	LH-LO	ezb
13	24	dbis
6	WW-YZ	ezb
14	LP-LZ	ezb
14	53	dbis
14	25	dbis
10	CA-CI	ezb
10	21	dbis
1	W	ezb
1	V	ezb
1	U	ezb
1	5	dbis
1	3	dbis
1	1	dbis
11	CL-CZ	ezb
11	22	dbis
3	P	ezb
3	15	dbis
19	R	ezb
19	TE-TZ	ezb
19	TA-TD	ezb
19	6	dbis
19	7	dbis
19	50	dbis
18	E	ezb
18	28	dbis
8	MA-MM	ezb
8	MN-MS	ezb
8	17	dbis
8	18	dbis
17	ZX-ZY	ezb
7	E	ezb
7	H	ezb
7	G	ezb
7	F	ezb
7	I	ezb
7	K	ezb
7	13	dbis
7	12	dbis
7	9	dbis
7	10	dbis
7	51	dbis
9	ZH-ZI	ezb
9	ZN	ezb
9	ZP	ezb
9	ZA-ZE	ezb
9	ZL	ezb
9	ZG	ezb
9	ZM	ezb
9	52	dbis
9	44	dbis
9	47	dbis
16	B	ezb
16	19	dbis
18	010	ddc
18	011	ddc
18	012	ddc
18	013	ddc
18	014	ddc
18	TA-TD	ezb
18	ZG	ezb
18	50	dbis
18	44	dbis
15	AP	ezb
15	AK-AL	ezb
15	55	dbis
2	N	ezb
18	015	ddc
18	016	ddc
18	017	ddc
18	018	ddc
18	019	ddc
2	LD	rvk
2	LE	rvk
2	LF	rvk
2	LG	rvk
2	NA	rvk
2	NB	rvk
2	NC	rvk
2	ND	rvk
2	NF	rvk
2	NG	rvk
2	NH	rvk
2	NK	rvk
2	NM	rvk
2	NN	rvk
2	NO	rvk
2	NP	rvk
2	NQ	rvk
2	NR	rvk
2	NS	rvk
2	NT	rvk
2	NU	rvk
2	NV	rvk
2	NW	rvk
2	NY	rvk
2	NZ	rvk
20	LA	rvk
20	LB	rvk
20	LC	rvk
12	DA	rvk
12	DB	rvk
12	DD	rvk
12	DF	rvk
12	DG	rvk
12	DH	rvk
12	DI	rvk
12	DK	rvk
12	DL	rvk
12	DM	rvk
12	DN	rvk
12	DO	rvk
12	DP	rvk
12	DQ	rvk
12	DR	rvk
12	DS	rvk
12	DT	rvk
12	DU	rvk
12	DV	rvk
12	DW	rvk
12	DX	rvk
12	DY	rvk
12	DZ	rvk
15	AM	rvk
15	AN	rvk
15	AP	rvk
15	SQ	rvk
15	SR	rvk
15	SS	rvk
15	ST	rvk
15	SU	rvk
18	AA	rvk
18	AB	rvk
18	AC	rvk
18	AD	rvk
18	AE	rvk
18	AF	rvk
18	AH	rvk
18	AK	rvk
18	AL	rvk
18	AR	rvk
18	AV	rvk
18	AW	rvk
18	AX	rvk
18	AZ	rvk
13	LH	rvk
13	LI	rvk
13	LK	rvk
13	LL	rvk
13	LM	rvk
13	LN	rvk
13	LO	rvk
4	SA	rvk
4	SB	rvk
4	SC	rvk
4	SD	rvk
4	SE	rvk
4	SF	rvk
4	SG	rvk
4	SH	rvk
4	SI	rvk
4	SK	rvk
4	SM	rvk
4	SN	rvk
4	SP	rvk
18	030	ddc
18	031	ddc
18	032	ddc
18	033	ddc
18	034	ddc
18	035	ddc
18	036	ddc
18	037	ddc
18	038	ddc
18	039	ddc
18	050	ddc
18	051	ddc
18	052	ddc
18	053	ddc
18	054	ddc
18	055	ddc
18	056	ddc
18	057	ddc
18	058	ddc
18	059	ddc
18	060	ddc
18	061	ddc
18	062	ddc
18	063	ddc
18	064	ddc
18	065	ddc
18	066	ddc
18	067	ddc
18	068	ddc
18	069	ddc
18	070	ddc
18	071	ddc
18	072	ddc
18	073	ddc
18	074	ddc
18	075	ddc
18	076	ddc
18	077	ddc
18	078	ddc
18	079	ddc
18	080	ddc
18	081	ddc
18	082	ddc
18	083	ddc
18	084	ddc
18	085	ddc
18	086	ddc
18	087	ddc
18	088	ddc
18	089	ddc
18	090	ddc
18	091	ddc
18	092	ddc
18	093	ddc
18	094	ddc
18	095	ddc
18	096	ddc
18	097	ddc
18	098	ddc
18	099	ddc
20	390	ddc
20	391	ddc
20	392	ddc
20	393	ddc
20	394	ddc
20	395	ddc
20	396	ddc
20	397	ddc
20	398	ddc
20	399	ddc
2	C	lcc
2	CB	lcc
2	CC	lcc
2	CD	lcc
2	CE	lcc
2	CJ	lcc
2	CN	lcc
2	CR	lcc
2	CS	lcc
2	CT	lcc
2	D	lcc
2	DA	lcc
2	DAW	lcc
2	DB	lcc
2	DC	lcc
2	DD	lcc
2	DE	lcc
2	DF	lcc
2	DG	lcc
2	DH	lcc
2	DJ	lcc
2	DJK	lcc
2	DK	lcc
2	DL	lcc
2	DP	lcc
2	DQ	lcc
2	DR	lcc
2	DS	lcc
2	DT	lcc
2	DU	lcc
2	DX	lcc
2	E	lcc
2	F	lcc
15	Z	lcc
15	ZA	lcc
13	763	ddc
13	764	ddc
13	765	ddc
13	766	ddc
13	767	ddc
13	768	ddc
13	769	ddc
13	770	ddc
13	771	ddc
13	772	ddc
13	773	ddc
13	774	ddc
13	775	ddc
13	776	ddc
13	777	ddc
13	778	ddc
13	779	ddc
13	790	ddc
13	792	ddc
13	N	lcc
13	NB	lcc
13	NC	lcc
13	ND	lcc
13	NE	lcc
13	NK	lcc
13	NX	lcc
4	QA	lcc
6	610	ddc
6	611	ddc
6	612	ddc
6	613	ddc
6	614	ddc
6	615	ddc
6	616	ddc
6	617	ddc
6	618	ddc
6	619	ddc
12	370	ddc
12	371	ddc
12	372	ddc
12	373	ddc
12	374	ddc
12	375	ddc
12	376	ddc
12	377	ddc
12	378	ddc
12	379	ddc
12	649	ddc
14	780	ddc
14	781	ddc
14	782	ddc
14	783	ddc
14	784	ddc
14	785	ddc
14	786	ddc
14	787	ddc
14	788	ddc
14	789	ddc
14	790	ddc
14	791	ddc
14	M	lcc
14	ML	lcc
6	QM	lcc
6	R	lcc
6	RA	lcc
6	RB	lcc
6	RC	lcc
6	RD	lcc
6	RE	lcc
6	RF	lcc
6	RG	lcc
6	RJ	lcc
6	RK	lcc
6	RL	lcc
6	RM	lcc
6	RS	lcc
6	RT	lcc
14	LP	rvk
14	LQ	rvk
14	LR	rvk
14	LS	rvk
14	LT	rvk
14	LU	rvk
14	LV	rvk
14	LW	rvk
14	LX	rvk
14	LY	rvk
10	CA	rvk
10	CB	rvk
10	CC	rvk
10	CD	rvk
10	CI	rvk
10	CK	rvk
1	UA	rvk
1	UB	rvk
1	UC	rvk
1	UD	rvk
1	UF	rvk
1	UG	rvk
1	UH	rvk
1	UK	rvk
1	UL	rvk
1	UM	rvk
1	UN	rvk
1	UO	rvk
1	UP	rvk
1	UQ	rvk
1	UR	rvk
1	US	rvk
1	UT	rvk
1	UV	rvk
1	UX	rvk
1	VA	rvk
1	VB	rvk
1	VC	rvk
1	VE	rvk
1	VG	rvk
1	VH	rvk
1	VK	rvk
1	VN	rvk
1	VR	rvk
1	VS	rvk
1	VT	rvk
1	VW	rvk
1	VX	rvk
1	WA	rvk
1	WB	rvk
1	WC	rvk
1	WD	rvk
1	WE	rvk
1	WF	rvk
1	WG	rvk
1	WH	rvk
1	WI	rvk
1	WK	rvk
1	WL	rvk
1	WM	rvk
1	WN	rvk
1	WP	rvk
1	WQ	rvk
1	WR	rvk
1	WS	rvk
1	WT	rvk
1	WU	rvk
1	WW	rvk
1	WX	rvk
6	XA	rvk
6	XB	rvk
6	XC	rvk
6	XD	rvk
6	XE	rvk
6	XF	rvk
6	XG	rvk
6	XH	rvk
6	XI	rvk
6	XL	rvk
6	XX	rvk
6	YB	rvk
6	YC	rvk
6	YD	rvk
6	YE	rvk
6	YF	rvk
6	YG	rvk
6	YH	rvk
6	YI	rvk
6	YK	rvk
6	YM	rvk
6	YN	rvk
6	YO	rvk
6	YP	rvk
6	YQ	rvk
6	YR	rvk
6	YT	rvk
6	YU	rvk
6	YV	rvk
11	CL	rvk
11	CM	rvk
11	CN	rvk
11	CP	rvk
11	CQ	rvk
11	CR	rvk
11	CS	rvk
11	CT	rvk
11	CU	rvk
11	CV	rvk
11	CW	rvk
11	CX	rvk
11	CZ	rvk
3	PA	rvk
3	PB	rvk
3	PC	rvk
3	PD	rvk
3	PE	rvk
3	PF	rvk
3	PG	rvk
3	PH	rvk
3	PI	rvk
3	PJ	rvk
3	PK	rvk
3	PL	rvk
3	PM	rvk
3	PN	rvk
3	PO	rvk
3	PP	rvk
3	PQ	rvk
3	PR	rvk
3	PS	rvk
3	PT	rvk
3	PU	rvk
3	PV	rvk
3	PW	rvk
3	PX	rvk
3	PY	rvk
3	PZ	rvk
19	RA	rvk
19	RB	rvk
19	RC	rvk
19	RD	rvk
19	RE	rvk
19	RF	rvk
19	RG	rvk
19	RH	rvk
19	RI	rvk
19	RK	rvk
19	RL	rvk
19	RM	rvk
19	RN	rvk
19	RO	rvk
19	RP	rvk
19	RQ	rvk
19	RR	rvk
19	RS	rvk
19	RT	rvk
19	RU	rvk
19	RV	rvk
19	RW	rvk
19	RX	rvk
19	RY	rvk
19	RZ	rvk
19	TA	rvk
19	TB	rvk
19	TC	rvk
19	TD	rvk
19	TE	rvk
19	TF	rvk
19	TG	rvk
19	TH	rvk
19	TI	rvk
19	TK	rvk
19	TL	rvk
19	TM	rvk
19	TN	rvk
19	TP	rvk
19	TQ	rvk
19	TR	rvk
19	TS	rvk
19	TT	rvk
19	TU	rvk
19	TV	rvk
19	TW	rvk
19	TX	rvk
19	TY	rvk
19	TZ	rvk
8	MA	rvk
8	MB	rvk
8	MC	rvk
8	MD	rvk
8	ME	rvk
8	MF	rvk
8	MG	rvk
8	MH	rvk
8	MI	rvk
8	MK	rvk
8	ML	rvk
8	MN	rvk
8	MP	rvk
8	MQ	rvk
8	MR	rvk
8	MS	rvk
17	ZX	rvk
17	ZY	rvk
7	EA	rvk
7	EC	rvk
7	ED	rvk
7	EE	rvk
7	EF	rvk
7	EG	rvk
7	EH	rvk
7	EI	rvk
7	EK	rvk
7	EL	rvk
7	EM	rvk
7	EN	rvk
7	EO	rvk
7	EP	rvk
7	EQ	rvk
7	ER	rvk
7	ES	rvk
7	ET	rvk
7	EU	rvk
7	EV	rvk
7	EW	rvk
7	EX	rvk
7	EY	rvk
7	EZ	rvk
7	F	rvk
7	FA	rvk
7	FB	rvk
7	FC	rvk
7	FD	rvk
7	FE	rvk
7	FF	rvk
7	FG	rvk
7	FH	rvk
7	FK	rvk
7	FL	rvk
7	FN	rvk
7	FP	rvk
7	FQ	rvk
7	FR	rvk
7	FS	rvk
7	FT	rvk
7	FU	rvk
7	FV	rvk
7	FX	rvk
7	FY	rvk
7	FZ	rvk
7	GA	rvk
7	GB	rvk
7	GC	rvk
7	GD	rvk
7	GE	rvk
7	GF	rvk
7	GG	rvk
7	GH	rvk
7	GI	rvk
7	GK	rvk
7	GL	rvk
7	GM	rvk
7	GN	rvk
7	GO	rvk
7	GT	rvk
7	GU	rvk
7	GV	rvk
7	GW	rvk
7	GX	rvk
7	GY	rvk
7	GZ	rvk
7	HC	rvk
7	HD	rvk
7	HE	rvk
7	HF	rvk
7	HG	rvk
7	HH	rvk
7	HI	rvk
7	HK	rvk
7	HL	rvk
7	HM	rvk
7	HN	rvk
7	HP	rvk
7	HQ	rvk
7	HR	rvk
7	HS	rvk
7	HT	rvk
7	HU	rvk
7	IA	rvk
7	IB	rvk
7	ID	rvk
7	IE	rvk
7	IF	rvk
7	IG	rvk
7	IH	rvk
7	IJ	rvk
7	IK	rvk
7	IL	rvk
7	IM	rvk
7	IN	rvk
7	IO	rvk
7	IP	rvk
7	IQ	rvk
7	IR	rvk
7	IS	rvk
7	IT	rvk
7	IU	rvk
7	IV	rvk
7	IW	rvk
7	IX	rvk
7	IZ	rvk
7	KA	rvk
7	KC	rvk
7	KD	rvk
7	KE	rvk
7	KF	rvk
7	KG	rvk
7	KH	rvk
7	KI	rvk
7	KK	rvk
7	KL	rvk
7	KM	rvk
7	KN	rvk
7	KO	rvk
7	KP	rvk
7	KQ	rvk
7	KR	rvk
7	KS	rvk
7	KU	rvk
7	KV	rvk
7	KW	rvk
7	KX	rvk
7	KY	rvk
7	KZ	rvk
9	ZG	rvk
9	ZH	rvk
9	ZI	rvk
9	ZK	rvk
9	ZL	rvk
9	ZM	rvk
9	ZN	rvk
9	ZO	rvk
9	ZP	rvk
9	ZQ	rvk
9	ZS	rvk
16	BA	rvk
16	BB	rvk
16	BC	rvk
16	BD	rvk
16	BE	rvk
16	BF	rvk
16	BG	rvk
16	BH	rvk
16	BK	rvk
16	BL	rvk
16	BM	rvk
16	BN	rvk
16	BO	rvk
16	BP	rvk
16	BQ	rvk
16	BR	rvk
16	BS	rvk
16	BT	rvk
16	BU	rvk
16	BV	rvk
16	BW	rvk
5	QA	rvk
5	QB	rvk
5	QC	rvk
5	QD	rvk
5	QE	rvk
5	QF	rvk
5	QG	rvk
5	QH	rvk
5	QI	rvk
5	QK	rvk
5	QL	rvk
5	QM	rvk
5	QN	rvk
5	QO	rvk
5	QP	rvk
5	QQ	rvk
5	QR	rvk
5	QS	rvk
5	QT	rvk
5	QU	rvk
5	QV	rvk
5	QW	rvk
5	QX	rvk
5	QY	rvk
5	ZA	rvk
5	ZB	rvk
5	ZC	rvk
5	ZD	rvk
5	ZE	rvk
5	ZA-ZE	ezb
5	Q	ezb
5	16	dbis
18	A	lcc
18	AC	lcc
18	AE	lcc
18	AG	lcc
18	AI	lcc
18	AM	lcc
18	AN	lcc
18	AP	lcc
18	AS	lcc
18	AY	lcc
18	AZ	lcc
2	909	ddc
2	930	ddc
2	931	ddc
2	932	ddc
2	933	ddc
2	934	ddc
2	935	ddc
2	936	ddc
2	937	ddc
2	938	ddc
2	939	ddc
2	940	ddc
2	941	ddc
2	942	ddc
2	943	ddc
2	944	ddc
2	945	ddc
2	946	ddc
2	947	ddc
2	948	ddc
2	949	ddc
2	950	ddc
2	951	ddc
2	952	ddc
2	953	ddc
2	954	ddc
2	955	ddc
2	956	ddc
2	957	ddc
2	958	ddc
2	959	ddc
2	960	ddc
2	961	ddc
2	962	ddc
2	963	ddc
2	964	ddc
2	965	ddc
2	966	ddc
2	967	ddc
2	968	ddc
2	969	ddc
2	970	ddc
2	971	ddc
2	972	ddc
2	973	ddc
2	974	ddc
2	975	ddc
2	976	ddc
2	977	ddc
2	978	ddc
2	979	ddc
2	980	ddc
2	981	ddc
2	982	ddc
2	983	ddc
2	984	ddc
2	985	ddc
2	986	ddc
2	987	ddc
2	988	ddc
2	989	ddc
2	990	ddc
2	991	ddc
2	992	ddc
2	993	ddc
2	994	ddc
2	995	ddc
2	996	ddc
2	997	ddc
2	998	ddc
2	999	ddc
20	GN	lcc
20	GR	lcc
20	GT	lcc
12	LA	lcc
12	LB	lcc
12	LC	lcc
12	LD	lcc
12	LE	lcc
12	LF	lcc
12	LG	lcc
12	LH	lcc
12	LJ	lcc
12	LT	lcc
15	001	ddc
15	002	ddc
15	003	ddc
15	004	ddc
15	005	ddc
15	006	ddc
15	007	ddc
15	008	ddc
15	009	ddc
15	020	ddc
15	021	ddc
15	022	ddc
15	023	ddc
15	024	ddc
15	025	ddc
15	026	ddc
15	027	ddc
15	028	ddc
15	029	ddc
13	700	ddc
13	701	ddc
13	702	ddc
13	703	ddc
13	704	ddc
13	705	ddc
13	706	ddc
13	707	ddc
13	708	ddc
13	709	ddc
13	730	ddc
13	731	ddc
13	732	ddc
13	733	ddc
13	734	ddc
13	735	ddc
13	736	ddc
13	737	ddc
13	738	ddc
13	739	ddc
13	740	ddc
13	741	ddc
13	742	ddc
13	743	ddc
13	744	ddc
13	745	ddc
13	746	ddc
13	747	ddc
13	748	ddc
13	749	ddc
13	750	ddc
13	751	ddc
13	752	ddc
13	753	ddc
13	754	ddc
13	755	ddc
13	756	ddc
13	757	ddc
13	758	ddc
13	759	ddc
13	760	ddc
13	761	ddc
13	762	ddc
6	RV	lcc
6	RX	lcc
6	RZ	lcc
10	101	ddc
10	110	ddc
10	111	ddc
10	112	ddc
10	113	ddc
10	114	ddc
10	115	ddc
10	116	ddc
10	117	ddc
10	118	ddc
10	119	ddc
10	120	ddc
10	121	ddc
10	122	ddc
10	123	ddc
10	124	ddc
10	125	ddc
10	126	ddc
10	127	ddc
10	128	ddc
10	129	ddc
10	140	ddc
10	141	ddc
10	142	ddc
10	143	ddc
10	144	ddc
10	145	ddc
10	146	ddc
10	147	ddc
10	148	ddc
10	149	ddc
10	160	ddc
10	161	ddc
10	162	ddc
10	163	ddc
10	164	ddc
10	165	ddc
10	166	ddc
10	167	ddc
10	168	ddc
10	169	ddc
10	170	ddc
10	171	ddc
10	172	ddc
10	173	ddc
10	174	ddc
10	175	ddc
10	176	ddc
10	177	ddc
10	178	ddc
10	179	ddc
10	180	ddc
10	181	ddc
10	182	ddc
10	183	ddc
10	184	ddc
10	185	ddc
10	186	ddc
10	187	ddc
10	188	ddc
10	189	ddc
10	190	ddc
10	191	ddc
10	192	ddc
10	193	ddc
10	194	ddc
10	195	ddc
10	196	ddc
10	197	ddc
10	198	ddc
10	199	ddc
10	BC	lcc
10	BD	lcc
10	BJ	lcc
1	530	ddc
1	531	ddc
1	532	ddc
1	533	ddc
1	534	ddc
1	535	ddc
1	536	ddc
1	537	ddc
1	538	ddc
1	539	ddc
1	540	ddc
1	541	ddc
1	542	ddc
1	543	ddc
1	544	ddc
1	545	ddc
1	546	ddc
1	547	ddc
1	548	ddc
1	549	ddc
1	570	ddc
1	571	ddc
1	572	ddc
1	573	ddc
1	574	ddc
1	575	ddc
1	576	ddc
1	577	ddc
1	578	ddc
1	579	ddc
1	580	ddc
1	581	ddc
1	582	ddc
1	583	ddc
1	584	ddc
1	585	ddc
1	586	ddc
1	587	ddc
1	588	ddc
1	589	ddc
1	590	ddc
1	591	ddc
1	592	ddc
1	593	ddc
1	594	ddc
1	595	ddc
1	596	ddc
1	597	ddc
1	598	ddc
1	599	ddc
1	QC	lcc
1	QD	lcc
1	QH	lcc
1	QK	lcc
1	QL	lcc
1	QM	lcc
1	QR	lcc
11	130	ddc
11	131	ddc
11	132	ddc
11	133	ddc
11	134	ddc
11	135	ddc
11	136	ddc
11	137	ddc
11	138	ddc
11	139	ddc
11	150	ddc
11	151	ddc
11	152	ddc
11	153	ddc
11	154	ddc
11	155	ddc
11	156	ddc
11	157	ddc
11	158	ddc
11	159	ddc
11	BF	lcc
3	340	ddc
3	341	ddc
3	342	ddc
3	343	ddc
3	344	ddc
3	345	ddc
3	346	ddc
3	347	ddc
3	348	ddc
3	349	ddc
3	K	lcc
3	KB	lcc
3	KBM	lcc
3	KBP	lcc
3	KBR	lcc
3	KBS	lcc
3	KBT	lcc
3	KBU	lcc
3	KD	lcc
3	KDC	lcc
3	KDE	lcc
3	KDG	lcc
3	KDK	lcc
3	KDZ	lcc
3	KE	lcc
3	KF	lcc
3	KG	lcc
3	KH	lcc
3	KJ	lcc
3	KJA	lcc
3	KJC	lcc
3	KJE	lcc
3	KJG	lcc
3	KJH	lcc
3	KJJ	lcc
3	KJK	lcc
3	KJM	lcc
3	KJN	lcc
3	KJP	lcc
3	KJQ	lcc
3	KJR	lcc
3	KJS	lcc
3	KJT	lcc
3	KJV	lcc
3	KJW	lcc
3	KK	lcc
3	KKA	lcc
3	KKB	lcc
3	KKC	lcc
3	KKE	lcc
3	KKF	lcc
3	KKG	lcc
3	KKH	lcc
3	KKI	lcc
3	KKJ	lcc
3	KKK	lcc
3	KKL	lcc
3	KKM	lcc
3	KKN	lcc
3	KKP	lcc
3	KKQ	lcc
3	KKR	lcc
3	KKS	lcc
3	KKT	lcc
3	KKV	lcc
3	KKW	lcc
3	KKX	lcc
3	KKY	lcc
3	KKZ	lcc
3	KL	lcc
3	KLA	lcc
3	KLB	lcc
3	KLD	lcc
3	KLE	lcc
3	KLF	lcc
3	KLH	lcc
3	KLM	lcc
3	KLN	lcc
3	KLP	lcc
3	KLQ	lcc
3	KLR	lcc
3	KLS	lcc
3	KLT	lcc
3	KLV	lcc
3	KLW	lcc
3	KM	lcc
3	KMC	lcc
3	KME	lcc
3	KMF	lcc
3	KMG	lcc
3	KMH	lcc
3	KMJ	lcc
3	KMK	lcc
3	KML	lcc
3	KMM	lcc
3	KMN	lcc
3	KMP	lcc
3	KMQ	lcc
3	KMS	lcc
3	KMT	lcc
3	KMU	lcc
3	KMV	lcc
3	KMX	lcc
3	KMY	lcc
3	KN	lcc
3	KNC	lcc
3	KNE	lcc
3	KNF	lcc
3	KNG	lcc
3	KNH	lcc
3	KNK	lcc
3	KNL	lcc
3	KNM	lcc
3	KNN	lcc
3	KNP	lcc
3	KNQ	lcc
3	KNR	lcc
3	KNS	lcc
3	KNT	lcc
3	KNU	lcc
3	KNV	lcc
3	KNW	lcc
3	KNX	lcc
3	KNY	lcc
3	KP	lcc
3	KPA	lcc
3	KPC	lcc
3	KPE	lcc
3	KPF	lcc
3	KPG	lcc
3	KPH	lcc
3	KPJ	lcc
3	KPK	lcc
3	KPL	lcc
3	KPM	lcc
3	KPP	lcc
3	KPS	lcc
3	KPT	lcc
3	KPV	lcc
3	KPW	lcc
3	KQ	lcc
3	KQ-KTZ	lcc
3	KQC	lcc
3	KQE	lcc
3	KQG	lcc
3	KQH	lcc
3	KQJ	lcc
3	KQK	lcc
3	KQM	lcc
3	KQP	lcc
3	KQT	lcc
3	KQV	lcc
3	KQW	lcc
3	KQX	lcc
3	KR	lcc
3	KRB	lcc
3	KRC	lcc
3	KRE	lcc
3	KRG	lcc
3	KRK	lcc
3	KRL	lcc
3	KRM	lcc
3	KRN	lcc
3	KRP	lcc
3	KRR	lcc
3	KRS	lcc
3	KRU	lcc
3	KRV	lcc
3	KRW	lcc
3	KRX	lcc
3	KRY	lcc
3	KS	lcc
3	KSA	lcc
3	KSC	lcc
3	KSE	lcc
3	KSG	lcc
3	KSH	lcc
3	KSK	lcc
3	KSL	lcc
3	KSN	lcc
3	KSP	lcc
3	KSR	lcc
3	KSS	lcc
3	KST	lcc
3	KSU	lcc
3	KSV	lcc
3	KSW	lcc
3	KSX	lcc
3	KSY	lcc
3	KSZ	lcc
3	KT	lcc
3	KTA	lcc
3	KTC	lcc
3	KTD	lcc
3	KTE	lcc
3	KTF	lcc
3	KTG	lcc
3	KTH	lcc
3	KTJ	lcc
3	KTK	lcc
3	KTL	lcc
3	KTN	lcc
3	KTQ	lcc
3	KTR	lcc
3	KTT	lcc
3	KTU	lcc
3	KTV	lcc
3	KTW	lcc
3	KTX	lcc
3	KTY	lcc
3	KTZ	lcc
3	KU	lcc
3	KU-KWW	lcc
3	KUA	lcc
3	KUB	lcc
3	KUC	lcc
3	KUD	lcc
3	KUE	lcc
3	KUF	lcc
3	KUG	lcc
3	KUH	lcc
3	KUN	lcc
3	KUQ	lcc
3	KV	lcc
3	KVB	lcc
3	KVC	lcc
3	KVE	lcc
3	KVH	lcc
3	KVL	lcc
3	KVM	lcc
3	KVN	lcc
3	KVP	lcc
3	KVQ	lcc
3	KVR	lcc
3	KVS	lcc
3	KVU	lcc
3	KVW	lcc
3	KW	lcc
3	KWA	lcc
3	KWC	lcc
3	KWE	lcc
3	KWG	lcc
3	KWH	lcc
3	KWL	lcc
3	KWP	lcc
3	KWQ	lcc
3	KWR	lcc
3	KWT	lcc
3	KWW	lcc
3	KWX	lcc
3	KZ	lcc
3	KZA	lcc
3	KZD	lcc
19	520	ddc
19	521	ddc
19	522	ddc
19	523	ddc
19	524	ddc
19	525	ddc
19	526	ddc
19	527	ddc
19	528	ddc
19	529	ddc
19	550	ddc
19	551	ddc
19	552	ddc
19	553	ddc
19	554	ddc
19	555	ddc
19	556	ddc
19	557	ddc
19	558	ddc
19	559	ddc
19	560	ddc
19	561	ddc
19	562	ddc
19	563	ddc
19	564	ddc
19	565	ddc
19	566	ddc
19	567	ddc
19	568	ddc
19	569	ddc
19	621	ddc
8	300	ddc
8	301	ddc
8	302	ddc
8	303	ddc
8	304	ddc
8	305	ddc
8	306	ddc
8	307	ddc
8	308	ddc
8	309	ddc
8	320	ddc
8	321	ddc
8	322	ddc
8	323	ddc
8	324	ddc
8	325	ddc
8	326	ddc
8	327	ddc
8	328	ddc
8	329	ddc
8	H	lcc
8	HA	lcc
8	HM	lcc
8	HN	lcc
8	HQ	lcc
8	HS	lcc
8	HT	lcc
8	HV	lcc
8	HX	lcc
8	J	lcc
8	JA	lcc
8	JC	lcc
8	JF	lcc
8	JJ	lcc
8	JK	lcc
8	JL	lcc
8	JN	lcc
8	JQ	lcc
8	JS	lcc
8	JV	lcc
8	JX	lcc
8	JZ	lcc
19	QB	lcc
19	QE	lcc
9	600	ddc
9	601	ddc
9	602	ddc
9	603	ddc
9	604	ddc
9	605	ddc
9	606	ddc
9	607	ddc
9	608	ddc
9	609	ddc
9	620	ddc
9	621	ddc
9	622	ddc
9	623	ddc
9	624	ddc
9	625	ddc
9	626	ddc
9	627	ddc
9	628	ddc
9	629	ddc
9	660	ddc
9	661	ddc
9	662	ddc
9	663	ddc
9	664	ddc
9	665	ddc
9	666	ddc
9	667	ddc
9	668	ddc
9	669	ddc
9	670	ddc
9	671	ddc
9	672	ddc
9	673	ddc
9	674	ddc
9	675	ddc
9	676	ddc
9	677	ddc
9	678	ddc
9	679	ddc
9	680	ddc
9	681	ddc
9	682	ddc
9	683	ddc
9	684	ddc
9	685	ddc
9	686	ddc
9	687	ddc
9	688	ddc
9	689	ddc
9	T	lcc
9	TA	lcc
9	TC	lcc
9	TD	lcc
9	TE	lcc
9	TF	lcc
9	TG	lcc
9	TH	lcc
9	TJ	lcc
9	TK	lcc
9	TL	lcc
9	TN	lcc
9	TP	lcc
9	TR	lcc
9	TS	lcc
9	TT	lcc
9	TX	lcc
16	200	ddc
16	201	ddc
16	202	ddc
16	203	ddc
16	204	ddc
16	205	ddc
16	206	ddc
16	207	ddc
16	208	ddc
16	209	ddc
16	210	ddc
16	211	ddc
16	212	ddc
16	213	ddc
16	214	ddc
16	215	ddc
16	216	ddc
16	217	ddc
16	218	ddc
16	219	ddc
16	220	ddc
16	221	ddc
16	222	ddc
16	223	ddc
16	224	ddc
16	225	ddc
16	226	ddc
16	227	ddc
16	228	ddc
16	229	ddc
16	230	ddc
16	231	ddc
16	232	ddc
16	233	ddc
16	234	ddc
16	235	ddc
16	236	ddc
16	237	ddc
16	238	ddc
16	239	ddc
16	240	ddc
16	241	ddc
16	242	ddc
16	243	ddc
16	244	ddc
16	245	ddc
16	246	ddc
16	247	ddc
16	248	ddc
16	249	ddc
16	250	ddc
16	251	ddc
16	252	ddc
16	253	ddc
16	254	ddc
16	255	ddc
16	256	ddc
16	257	ddc
16	258	ddc
16	259	ddc
16	260	ddc
16	261	ddc
16	262	ddc
16	263	ddc
16	264	ddc
16	265	ddc
16	266	ddc
16	267	ddc
16	268	ddc
16	269	ddc
16	270	ddc
16	271	ddc
16	272	ddc
16	273	ddc
16	274	ddc
16	275	ddc
16	276	ddc
16	277	ddc
16	278	ddc
16	279	ddc
16	280	ddc
16	281	ddc
16	282	ddc
16	283	ddc
16	284	ddc
16	285	ddc
16	286	ddc
16	287	ddc
16	288	ddc
16	289	ddc
16	290	ddc
16	291	ddc
16	292	ddc
16	293	ddc
16	294	ddc
16	295	ddc
16	296	ddc
16	297	ddc
16	298	ddc
16	299	ddc
16	BL	lcc
16	BM	lcc
16	BP	lcc
16	BQ	lcc
16	BR	lcc
16	BS	lcc
16	BT	lcc
16	BV	lcc
16	BX	lcc
5	330	ddc
5	331	ddc
5	332	ddc
5	333	ddc
5	334	ddc
5	335	ddc
5	336	ddc
5	337	ddc
5	338	ddc
5	339	ddc
5	381	ddc
5	382	ddc
5	630	ddc
5	631	ddc
5	632	ddc
5	633	ddc
5	634	ddc
5	635	ddc
5	636	ddc
5	637	ddc
5	638	ddc
5	639	ddc
5	640	ddc
5	647	ddc
5	648	ddc
5	650	ddc
5	651	ddc
5	652	ddc
5	653	ddc
5	654	ddc
5	655	ddc
5	656	ddc
5	657	ddc
5	658	ddc
5	659	ddc
5	HB	lcc
5	HC	lcc
5	HD	lcc
5	HE	lcc
5	HF	lcc
5	HG	lcc
5	HJ	lcc
5	SD	lcc
5	SH	lcc
7	400	ddc
7	401	ddc
7	402	ddc
7	403	ddc
7	404	ddc
7	405	ddc
7	406	ddc
7	407	ddc
7	408	ddc
7	409	ddc
7	410	ddc
7	411	ddc
7	412	ddc
7	413	ddc
7	414	ddc
7	415	ddc
7	416	ddc
7	417	ddc
7	418	ddc
7	419	ddc
7	420	ddc
7	421	ddc
7	422	ddc
7	423	ddc
7	424	ddc
7	425	ddc
7	426	ddc
7	427	ddc
7	428	ddc
7	429	ddc
7	430	ddc
7	431	ddc
7	432	ddc
7	433	ddc
7	434	ddc
7	435	ddc
7	436	ddc
7	437	ddc
7	438	ddc
7	439	ddc
7	440	ddc
7	441	ddc
7	442	ddc
7	443	ddc
7	444	ddc
7	445	ddc
7	446	ddc
7	447	ddc
7	448	ddc
7	449	ddc
7	450	ddc
7	451	ddc
7	452	ddc
7	453	ddc
7	454	ddc
7	455	ddc
7	456	ddc
7	457	ddc
7	458	ddc
7	459	ddc
7	460	ddc
7	461	ddc
7	462	ddc
7	463	ddc
7	464	ddc
7	465	ddc
7	466	ddc
7	467	ddc
7	468	ddc
7	469	ddc
7	470	ddc
7	471	ddc
7	472	ddc
7	473	ddc
7	474	ddc
7	475	ddc
7	476	ddc
7	477	ddc
7	478	ddc
7	479	ddc
7	480	ddc
7	481	ddc
7	482	ddc
7	483	ddc
7	484	ddc
7	485	ddc
7	486	ddc
7	487	ddc
7	488	ddc
7	489	ddc
7	490	ddc
7	491	ddc
7	492	ddc
7	493	ddc
7	494	ddc
7	495	ddc
7	496	ddc
7	497	ddc
7	498	ddc
7	499	ddc
7	800	ddc
7	801	ddc
7	802	ddc
7	803	ddc
7	804	ddc
7	805	ddc
7	806	ddc
7	807	ddc
7	808	ddc
7	809	ddc
7	810	ddc
7	811	ddc
7	812	ddc
7	813	ddc
7	814	ddc
7	815	ddc
7	816	ddc
7	817	ddc
7	818	ddc
7	819	ddc
7	820	ddc
7	821	ddc
7	822	ddc
7	823	ddc
7	824	ddc
7	825	ddc
7	826	ddc
7	827	ddc
7	828	ddc
7	829	ddc
7	830	ddc
7	831	ddc
7	832	ddc
7	833	ddc
7	834	ddc
7	835	ddc
7	836	ddc
7	837	ddc
7	838	ddc
7	839	ddc
7	840	ddc
7	841	ddc
7	842	ddc
7	843	ddc
7	844	ddc
7	845	ddc
7	846	ddc
7	847	ddc
7	848	ddc
7	849	ddc
7	850	ddc
7	851	ddc
7	852	ddc
7	853	ddc
7	854	ddc
7	855	ddc
7	856	ddc
7	857	ddc
7	858	ddc
7	859	ddc
7	860	ddc
7	861	ddc
7	862	ddc
7	863	ddc
7	864	ddc
7	865	ddc
7	866	ddc
7	867	ddc
7	868	ddc
7	869	ddc
7	870	ddc
7	871	ddc
7	872	ddc
7	873	ddc
7	874	ddc
7	875	ddc
7	876	ddc
7	877	ddc
7	878	ddc
7	879	ddc
7	880	ddc
7	881	ddc
7	882	ddc
7	883	ddc
7	884	ddc
7	885	ddc
7	886	ddc
7	887	ddc
7	888	ddc
7	889	ddc
7	890	ddc
7	891	ddc
7	892	ddc
7	893	ddc
7	894	ddc
7	895	ddc
7	896	ddc
7	897	ddc
7	898	ddc
7	899	ddc
7	P	lcc
7	PA	lcc
7	PB	lcc
7	PC	lcc
7	PD	lcc
7	PE	lcc
7	PF	lcc
7	PG	lcc
7	PH	lcc
7	PJ	lcc
7	PK	lcc
7	PL	lcc
7	PM	lcc
7	PN	lcc
7	PQ	lcc
7	PR	lcc
7	PS	lcc
7	PT	lcc
7	PZ	lcc
\.


