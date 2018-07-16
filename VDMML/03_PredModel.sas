


cas mySession sessopts=(caslib=casuser timeout=1800 locale="en_US");


OPTIONS msglevel=i;
%LET deployPath=/home/viyauser/manualrg;


caslib csvfiles task=add type=dnfs                       
  path="/opt/open/data"
  desc="Spreadsheets and CSV source data." ;
/*NOTE: 'CSVFILES' is now the active caslib.*/ 



caslib _all_ list;
PROC CASUTIL;
	list files incaslib="csvfiles";
	list tables incaslib="csvfiles";
QUIT;

PROC CASUTIL;
	load casdata="hmeq.csv"	
		importoptions=(filetype="csv" getnames="true")
		casout="hmeq"
        replace;
	list tables incaslib="csvfiles";
    contents casdata = "hmeq";
QUIT;

libname viyalab CAS SESSREF=mySession  caslib=csvfiles;




%MACRO ScoreAndAsses(data=,path=,model=, response=);
	%LOCAL probability0 probability1;
	%LET probability0=P_%SYSFUNC(catx(,&response,0));
	%LET probability1=P_%SYSFUNC(catx(,&response,1));
	
	DATA viyalab.scored_&model;
	  set &data;
	  length model dataset $16.;
	  %include "&path";
	  model="&model";
	  select (_PartInd_);
	  	when(0) dataset="validation";
	  	when(1) dataset="train";
	  	when(2) dataset="test";
	  end;
	RUN;
	
	ods exclude all;
	PROC ASSESS DATA=viyalab.scored_&model;
	  input &probability1;
	  target &response / level=nominal event='1';
	  fitstat pvar= &probability0 / pevent='0';
	  by _partind_;
	  ods output fitstat  = fitstat_&model 
	  			 rocinfo  = roc_&model 
	             liftinfo = lift_&model;
	RUN;
	ods exclude none;
%MEND ScoreAndAsses;



/*1. METADATA EXPLORATORY ANALYSIS*/
PROC CONTENTS DATA=viyalab.hmeq OUT=viyalab.md;
RUN;

PROC SQL NOPRINT;
	select name into: label  from viyalab.md where name eq "BAD";
	select name into: featList separated by " " from viyalab.md where name ne "BAD";
	select catx("_", name, "MI") into: featList_MI separated by " " from viyalab.md where name ne "BAD";
	select name into: numFeatList separated by " " from viyalab.md where name ne "BAD" and type eq 1;
	select catx("_", name, "MI") into: numFeatList_MI separated by " " from viyalab.md where name ne "BAD" and type eq 1;
	select name into: catFeatList separated by " " from viyalab.md where name ne "BAD" and type ne 1;
	select catx("_", name, "MI") into: catFeatList_MI separated by " " from viyalab.md where name ne "BAD" and type ne 1;
QUIT;


/*2. EDA: Exploratory Data Analysis*/
/*2.1. Response analyisis*/

/*PROC FREQ NOT AVAILABLE IN DEVELOPER TRIAL*/

/*Use CAS to process a query with FEDSQL*/
PROC FEDSQL SESSREF=mySession;
	create table response_analysis as
		select &label, count(1) as n
		from csvfiles.hmeq
		group by &label;
	quit;
RUN;
/*Single threading in CAS DATA Step example*/
DATA _NULL_ / SINGLE=YES;
	set viyalab.response_analysis END=eof;
	if &label eq 0 then call SYMPUTX('Nzeros',N);
	else call SYMPUTX('Nones',N);
	Ntot+N;
	if eof then call SYMPUTX('NTot',Ntot);
RUN;
title "Response Analysis";
PROC SQL;
	select &label, N , n/&Ntot as proprotion from viyalab.response_analysis;
QUIT;
title;

/*2.2. Feature Analyisis*/
proc cardinality data=viyalab.hmeq outcard=viyalab.card;
run;

PROC PRINT DATA=viyalab.card;
	title "Categorical variable analyisis";
	where _type_="C";
	by _RLEVEL_;
	id _varname_;
	var _RLEVEL_ _CARDINALITY_ _NMISS_ _MFREQCHR_;
RUN;

PROC PRINT DATA=viyalab.card;
	title "Numerical variable analyisis";
	where _type_="N";
	by _RLEVEL_;
	id _varname_;
	var _RLEVEL_ _CARDINALITY_ _NMISS_ _min_ _mean_ _max_ _stddev_ _kurtosis_ _skewness_;
RUN;
title;

/*2.3. RREDICTIVE STRENGTH ANALYISIS*/

/*MDSUMMARY uses CAS to compute descriptive statistics*/
PROC MDSUMMARY DATA=viyalab.hmeq;
	var &numFeatList;
	groupby &label / OUT=viyalab.summary1;
RUN;

PROC PRINT DATA=viyalab.summary1;
RUN;

/*PROC TRANSPOSE can run in CAS and it requires no previous sorting, but a shuffling 
operation may occur*/
PROC TRANSPOSE DATA=viyalab.summary1 OUT=viyalab.summary1_t PREFIX=LABEL_;
	id &label;
	by _column_;
	var _Min_ _Mean_ _Max_ _NObs_;
RUN;


/*Summarizing data statistics in a table instead of ploting the entire dataset is a good
practice in big data to avoid collecting a large amount on data*/
title "Summary numeric feature stats by label value";
PROC PRINT DATA=viyalab.summary1_t NOOBS;
	id _name_;
	by _column_;
	var :LABEL_;
RUN;
title;
/*Plot in detail some predictors*/
PROC SGPLOT DATA=viyalab.hmeq;
	histogram LOAN / GROUP=&label;
RUN;


PROC FEDSQL SESSREF=mySession;
	create table summary2 as
		select %SYSFUNC(TRANwrd (&catFeatList, %STR( ), %STR(, ))), &label, count(1) as freq
		from csvfiles.hmeq
		group by %SYSFUNC(TRANwrd (&catFeatList, %STR( ), %STR(, ))), &label;
	quit;
RUN;

title "Frequency categorical variable analysis analysis by label";
PROC SQL;
		select job, sum(freq) as n_lev, sum(case when &label=0 then freq else . end)/calculated n_lev as label0 ,
			sum(case when &label=1 then freq else . end)/calculated n_lev as label1 
		from viyalab.summary2
		group by job;
		select REASON, sum(freq) as n_lev, sum(case when &label=0 then freq else . end)/calculated n_lev as label0 ,
			sum(case when &label=1 then freq else . end)/calculated n_lev as label1 
		from viyalab.summary2
		group by REASON;
QUIT;
title;


/*2.4. Missing value analysis*/
/*Array and do loops does not run in CAS?*/

DATA viyalab.input_MI;
	set viyalab.hmeq END=eof;
	array numFeat {*}  &numFeatList;
	array numFeat_MI {*} &numFeatList_MI;
	
	array catFeat {*}  &catFeatList;
	array catFeat_MI {*} &catFeatList_MI;
	
	do i=1 to dim(numFeat);
		numFeat_MI[i] = cmiss(numFeat[i]);
	end;
	
	do i=1 to dim(catFeat);
		catFeat_MI[i] = cmiss(catFeat[i]);
		if catFeat_MI[i] then catFeat[i]="missing";
	end;
	tot_mis=sum(of catFeat_MI[*], of numFeat_MI[*]);
	DROP i;
	if eof then put _threadid_= _N_=;
RUN;

PROC MDSUMMARY DATA=viyalab.input_MI;
	var &featList_MI;
	GROUPBY &label / OUT=viyalab.summary_MI;
RUN;

PROC PRINT DATA=viyalab.summary_MI;
RUN;

DATA viyalab.summary_MI2;
	set viyalab.summary_MI;
	prop_MI=_Sum_/&NTot;
RUN;

title "Missing value observations per feature and label value";
PROC PRINT DATA=viyalab.summary_MI2;
	id _Column_ &label;
	var _Sum_;
RUN;
PROC SGPLOT DATA=viyalab.summary_MI2;
	vbar _Column_ / response= prop_MI group= &label datalabel=_Sum_ CATEGORYORDER= RESPDESC;
RUN;
title;
/*Debinc is the only above 20% of missing value observations, and proprotions of missing value are roughly equals at both values of the response.
Means of Debtinc are significantly different at both values of the response
_Mean_	(label=0)33.253128634	(label=1)39.387644892
Value missing proportion is significantly higher at positive response, but value means are roughly equals.
_Mean_	(label=0)102595.92102	(label=1)98172.846227
Debtinc and value will be binned and rest of numerical features will be imputed by mean
Categorical features missing is mapped to blank
*/

/*3. FEATURE ENGINEERING*/
/*3.1. Missing value imputation*/
DATA viyalab.featEng0;
	set viyalab.input_MI;
	DROP &numFeatList_MI &catFeatList_MI;
RUN;

proc varimpute data=viyalab.featEng0;
   input &numFeatList /ctech=mean;
   output out=viyalab.featEng1 copyvars=(_ALL_);
run;
/*3.2. Feature Binning*/
PROC BINNING DATA=viyalab.featEng1 METHOD=QUANTILE NUMBIN=10;
	input debtinc value;
	output OUT=viyalab.featEng2 COPYVARS=(_ALL_);
RUN;

/*4. MODEL BUILDING*/
/*4.1. Dataset spliting*/
%LET numFeatList = IM_CLAGE IM_CLNO IM_DELINQ IM_DEROG IM_LOAN IM_MORTDUE IM_NINQ IM_YOJ BIN_DEBTINC BIN_VALUE tot_mis;
%PUT &numFeatList;

PROC PARTITION DATA=viyalab.featEng2 partition 
		samppct=70 /*_PartInd_=1*/
		samppct2=15 /*_PartInd_=2*/
		partind /*1{train}, 2{test}, 0{validation}*/
		;
  by &label;
  output OUT=viyalab.splits copyvars=(_ALL_);
RUN;


/* Logistic Regresion */
PROC LOGSELECT DATA=viyalab.splits NORMALIZE=YES LASSORHO=0.8 ITHIST;
  class  &catFeatList / PARAM=GLM REF=FIRST;/*ONE-HOT-ENCODING, alphanumeric order of levels*/
  model &label(event='1')= &numFeatList &catFeatList;
  partition rolevar=_partind_(train='1' validate='0');
  code file="&deployPath./logreg.sas" pcatall;
RUN;

/* Decision Tree */
PROC TREESPLIT DATA=viyalab.splits
		MAXBRANCH=2 SPLITONCE
		MAXDEPTH=5
		MINLEAFSIZE=25
		PRUNINGTABLE
		SEED=123;
  input &numFeatList / level=interval;
  input &catFeatList / level=nominal;
  target &label / level=nominal;
  partition rolevar=_partind_(train='1' validate='0');
  grow entropy;
  prune c45;
  code file="&deployPath./tree.sas";
RUN;

/* Random Forest */
ods output FitStatistics=forestFit; 
PROC FOREST DATA=viyalab.splits ntrees=200 intervalbins=20 minleafsize=25 VOTE=PROBABILITY SEED=123;
  input &numFeatList / level=interval;
  input &catFeatList / level=nominal;
  target &label / level=nominal;
  partition rolevar=_partind_(train='1' validate='0');
  autotune useparameters=custom
           tuneparms=(INBAGFRACTION (VALUES=0.25 0.5 0.75)
           			  MAXDEPTH (VALUES=3 5 8)
           			 );
  code file="&deployPath./forest.sas";
RUN;

title "Missclassification rate: train vs OOB";
PROC SGPLOT DATA=forestFit;
	series x=trees y=miscTRAIN;
	series x=trees y=miscoob;
RUN;

title "Missclassification rate: train vs validation";
PROC SGPLOT DATA=forestFit;
	series x=trees y=miscTRAIN;
	series x=trees y=miscVALID;
RUN;
title;

/*Gradient Boosted Trees*/
/*By default, SAMPLINGRATE=0.5.
By default, m is the number of input variables.
*/
ods output FitStatistics=gbmFit; 
PROC GRADBOOST DATA=viyalab.splits intervalbins=20 maxdepth=5 MAXBRANCH=2 MINLEAFSIZE= 25 SEED=123; 
  input &numFeatList / level=interval;
  input &catFeatList / level=nominal;
  target &label / level=nominal;
  partition rolevar=_partind_(train='1' validate='0');
  autotune useparameters=custom
           tuneparms=(LASSO (VALUES=0.001 0.01 0.1 1 10)
           				RIDGE (VALUES=0.001 0.01 0.1 1 10)
           				NTREES(LB=50 UB=200 INIT=50)
       				);
  code file="&deployPath./GBM.sas";
RUN;


title "Missclassification rate: train vs validation";
PROC SGPLOT DATA=gbmFit;
	series x=trees y=miscTRAIN;
	series x=trees y=miscVALID;
RUN;
title;
/*Neural Network*/
proc nnet data=&partitioned_data;
  target b_tgt / level=nom;
  input &interval_inputs. / level=int;
  input &class_inputs. / level=nom;
  hidden 5;
  train outmodel=mycaslib.nnet_model;
  partition rolevar=_partind_(train='1' validate='0');
  ods exclude OptIterHistory;
run;


proc nnet data=&partitioned_data inmodel=mycaslib.nnet_model noprint;
  output out=mycaslib._scored_NN copyvars=(_ALL_);
run;


/*SVM*/
proc svmachine data=&partitioned_data(where=(_partind_=1));
  kernel polynom / deg=2;
  target b_tgt;
  input &interval_inputs. / level=interval;
  input &class_inputs. / level=nominal;
  savestate rstore=mycaslib.svm_astore_model;
  ods exclude IterHistory;
run;


proc astore;
  score data=&partitioned_data out=mycaslib._scored_SVM 
        rstore=mycaslib.svm_astore_model copyvars=(b_tgt _partind_);
run;





/*5. MODEL ASSESSMENT*/
%ScoreAndAsses(data=viyalab.splits,path=&deployPath./logreg.sas,model=logreg, response=&label);
%ScoreAndAsses(data=viyalab.splits,path=&deployPath./tree.sas,model=tree, response=&label);
%ScoreAndAsses(data=viyalab.splits,path=&deployPath./forest.sas,model=forest, response=&label);
%ScoreAndAsses(data=viyalab.splits,path=&deployPath./GBM.sas,model=gbm, response=&label);


DATA roc;
	set roc_logreg(keep=sensitivity fpr c _partind_ in=l )
	roc_tree(keep=sensitivity fpr c _partind_ in=t )
	roc_forest(keep=sensitivity fpr c _partind_ in=f )
	roc_GBM(keep=sensitivity fpr c _partind_ in=g );
	length model dataset $ 16;
	select;
		when (l) model='Logistic';
		when (t) model='Tree';
		when (f) model='Forest';
		when (g) model='GBM';
		end;
	select (_PartInd_);
		when(0) dataset="validation";
		when(1) dataset="train";
		when(2) dataset="test";
	end;
RUN;

data lift;
  set lift_logreg(keep=depth lift cumlift _partind_ in=l)
      lift_tree(keep=depth lift cumlift _partind_ in=t)
      lift_forest(keep=depth lift cumlift _partind_ in=f)
      lift_gbm(keep=depth lift cumlift _partind_ in=g);
      
  length model dataset $ 16;
  select;
      when (l) model='Logistic';
      when (t) model='Tree';
      when (f) model='Forest';
	  when (g) model='GBM';
  end;
  select (_PartInd_);
	  	when(0) dataset="validation";
	  	when(1) dataset="train";
	  	when(2) dataset="test";
	  end;
run;

/* Print AUC (Area Under the ROC Curve) */
title "AUROC";

PROC SQL;
	create table AUROC as
		select distinct model, dataset, c from ROC order by model, dataset;
QUIT;

PROC TRANSPOSE DATA=AUROC OUT=AUROC_report;
	by model;
	id dataset;
	var c;
RUN;

PROC SQL;
	title "AUROC Report";
	select model, test, validation, train from AUROC_report order by test desc;
QUIT;
title;


/* Draw ROC charts */ 
PROC SORT DATA=ROC;
	by dataset;
RUN;
proc sgplot data=roc aspect=1;
  title "ROC";
  by dataset;
  xaxis values=(0 to 1 by 0.25) grid offsetmin=.05 offsetmax=.05; 
  yaxis values=(0 to 1 by 0.25) grid offsetmin=.05 offsetmax=.05;
  lineparm x=0 y=0 slope=1 / transparency=.7;
  series x=fpr y=sensitivity / group=model;
run;

PROC SORT DATA=LIFT;
	by dataset;
RUN;
/* Draw lift charts */   
proc sgplot data=lift; 
  title "Lift Chart";
  by dataset;
  yaxis label=' ' grid;
  series x=depth y=lift / group=model markers markerattrs=(symbol=circlefilled);
run;
title;

/*6. SCORING*/

proc casutil;
    save casdata="scored_gbm" 
    incaslib="csvfiles" 
    outcaslib="casuser"
	casout="hmeq_scored"
	replace;
run;

proc casutil;
    list tables incaslib="casuser";
run;
