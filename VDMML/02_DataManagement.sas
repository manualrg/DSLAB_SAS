cas mySession sessopts=(caslib=casuser timeout=1800 locale="en_US");

libname mylib CAS SESSREF=mySession  caslib=CASUSER;

OPTIONS msglevel=i;

PROC CASUTIL;
	list tables incaslib="casuser";
RUN;

DATA mylib.CARS;
	set sashelp.cars;
	MPG=mean(MPG_City, MPG_Highway);
	if MPG>20 then label=0; else label=1;
	DROP MPG_City MPG_Highway;
RUN;

/*1. RUN DATA step in CAS Engine*/
DATA mylib.cars2;
	set mylib.cars END=eof;
	logHP=log(Horsepower);
	logMPG=log(MPG);
	threads=_threadid_;
	nobs=_N_;
	if eof then put _threadid_= _N_=; /*In single machine, only one thread*/
RUN;

/* Some procedures require collecting distributed data, so they are performed locally*/
PROC SGPLOT DATA=mylib.cars;
	scatter x=horsepower y=MPG; 
	reg x=horsepower y=MPG  / LINEATTRS=(COLOR=RED);
RUN;
PROC SGPLOT DATA=mylib.cars2;
	scatter x=logHP y=logMPG ;
	reg x=logHP y=logMPG  / LINEATTRS=(COLOR=RED);
RUN;



/*2. RETAIN IN CAS*/

DATA cars_ret1;
	set SASHELP.CARS END=eof;
	count+1;
	if eof then do;
		thread=_threadid_;
		obsthread=_N_;
		output;
	end;
	KEEP count thread obsthread;
RUN;

DATA mylib.cars_ret1;
	set mylib.CARS END=eof;
	count+1;
	if eof then do;
		thread=_threadid_;
		obsthread=_N_;
		output;
	end;
	KEEP count thread obsthread;
RUN;
/*In multi machine mode, each thread maps the retain operation to its partition, and the final result
has as many observations as threads*/

PROC PRINT DATA=mylib.cars_ret1;
RUN;

/*Solution 1: Force to use single-threaded processing*/

DATA mylib.cars_ret2 / SINGLE=YES;
	set mylib.CARS END=eof;
	count+1;
	if eof then do;
		thread=_threadid_;
		obsthread=_N_;
		output;
	end;
	KEEP count thread obsthread;
RUN;

PROC PRINT DATA=mylib.cars_ret2;
RUN;

/*Solution 2: Use MAP-REDUCE APPROACH*/
/*MAP the count operation to every thread*/
DATA mylib.cars_retMap;
	set mylib.CARS END=eof;
	count+1;
	if eof then do;
		thread=_threadid_;
		obsthread=_N_;
		output;
	end;
	KEEP count thread obsthread;
RUN;
/*REDUCE: reduce adding up every count variable in every thread and obtain the final result*/
DATA mylib.cars_retRed / SINGLE=YES;
	set mylib.cars_retMap END=eof;
	count+1;
	if eof;
RUN;
PROC PRINT DATA=mylib.cars_retRed;
RUN;


/*3. BY-GROUP PROCESSING*/

PROC SORT DATA=sashelp.cars OUT=cars_sorted;
	by origin;
RUN;

DATA cars_origin;
	set cars_sorted;
	by origin;
	retain sum_invoice n_models;
	if first.origin then do;
		sum_invoice=0;
		n_models=0;
	end;
	sum_invoice=sum_invoice+invoice;
	n_models= n_models+1;
	if last.origin then output;
	KEEP origin sum_invoice n_models;
RUN;

/*Data is not sorted, because data is partitioned by shuffling observations in order to get by-groups that are given
to a thread and then processed, so every time that this action takes places, a shuffling is carried out.
Every level is processed by a single thread?
Skewed data?
Prepartioning data by levels of a variable?
*/

DATA mylib.cars_origin;
	set mylib.cars;
	by origin;
	retain sum_invoice n_models;
	if first.origin then do;
		sum_invoice=0;
		n_models=0;
	end;
	sum_invoice=sum_invoice+invoice;
	n_models= n_models+1;
	if last.origin then output;
	KEEP origin sum_invoice n_models;
RUN;
PROC PRINT DATA=mylib.cars_origin;
RUN;


/*4. BY-GROUP AND SORTING*/
DATA mylib.cars_type_srt1;
	set mylib.cars;
	by Type;/*Data is partitined by Type but not sorted, a shuflle operation may occur*/
RUN;

PROC PRINT DATA=mylib.cars_type_srt1;
RUN;

DATA mylib.cars_type_srt2;
	set mylib.cars;
	by Type MSRP; /*partitions and shuffle data by the first variable and sort within partition by the rest of variables*/
	if first.Type then lowMSRP=1;
		else LowMSRP=0;
	if last.Type then HighMSRP=1;
		else HighMSRP=0;
RUN;
PROC PRINT DATA=mylib.cars_type_srt2;
RUN;


DATA mylib.cars_type_srt3 (partition=(make type) orderby=(MSRP));
	set mylib.cars;
	by Type; /*even if the variable is in partition option, it must appear in by statement in order to use fist/last variables*/
	if first.Type then lowMSRP=1;
		else LowMSRP=0;
	if last.Type then HighMSRP=1;
		else HighMSRP=0;
RUN;
PROC PRINT DATA=mylib.cars_type_srt3;
RUN;

/*5. SQL: FEDSQL*/
/*
PROC FEDSQL SESSREF=mySession;
	drop table casuser.cars_type_contingency;
	quit;
RUN;
*/
PROC FEDSQL SESSREF=mySession;
	create table cars_type_contingency as
		select type ,label,
			count(1) as n
		from casuser.cars
		group by type ,label;
	quit;
RUN;
PROC SGPLOT DATA=MYLIB.cars_type_contingency;
	hbar type / response=n GROUP=label;
RUN;




