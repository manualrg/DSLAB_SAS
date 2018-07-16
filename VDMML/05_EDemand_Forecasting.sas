
DATA param_dates;
	format first_date last_date train_date date9.;
	last_date='30MAR2017'd;
	first_date='1JAN2015'd;
	lead=90;
	train_date=intnx('day', last_Date,-lead-1);
	call SYMPUTX('fore_date', last_date);
	call SYMPUTX('test_period', lead);
	call SYMPUTX('train_date', train_Date);
RUN;


DATA viyalab.edemand;
	set local.edemand;
	
RUN;

PROC SGPLOT DATA=viyalab.edemand;
	series x=date y=demand;
	refline &train_date / axis=x;
RUN;

/*
 * 	1. FEATURE ENGINEERING
 */

DATA viyalab.edemand_feat1;
	set viyalab.edemand;
	format idmonth monyy.;
	idmonth=intnx('month', date, 0, 'beginning');
	year=year(date);
	qtr=qtr(date);
	month=month(date);
	week=week(date);
	weekday=weekday(date);
	
	cos_month=cos(2*constant("pi")*(month-1)/12);
	sin_month=sin(2*constant("pi")*(month-1)/12);
	cos_weekday=cos(2*constant("pi")*(weekday-1)/7);
	sin_weekday=sin(2*constant("pi")*(weekday-1)/7);
	
	target=demand;
	
	/*Target variable lagged once to compute features*/
	feat_lag1=lag1(target);
	feat_lag2=lag2(target);
	feat_lag3=lag3(target);
	feat_lag4=lag4(target);
	feat_lag5=lag5(target);
	feat_lag6=lag6(target);
	feat_lag7=lag7(target);
	
	feat_moveAVE3=mean(of feat_lag1--feat_lag3);
	feat_moveAVE7=mean(of feat_lag1--feat_lag7);
	
	feat_moveSTD3=std(of feat_lag1--feat_lag3);
	feat_moveSTD7=std(of feat_lag1--feat_lag7);
	
	feat_moveMAX3=max(of feat_lag1--feat_lag3);
	feat_moveMAX7=max(of feat_lag1--feat_lag7);
	
	feat_moveMIN3=min(of feat_lag1--feat_lag3);
	feat_moveMIN7=min(of feat_lag1--feat_lag7);
RUN;




DATA viyalab.edemand_feat2;
	set viyalab.edemand_feat1;
	

	feat_moveAVE3_lag7=lag7(feat_moveAVE3);
	feat_moveAVE3_lag14=lag14(feat_moveAVE3);
	feat_moveAVE3_lag30=lag30(feat_moveAVE3);
	feat_moveAVE3_lag60=lag60(feat_moveAVE3);
	feat_moveAVE3_lag120=lag120(feat_moveAVE3);
	feat_moveAVE3_lag240=lag240(feat_moveAVE3);
	feat_moveAVE3_lag365=lag365(feat_moveAVE3);
	
	feat_moveAVE7_lag7=lag7(feat_moveAVE7);
	feat_moveAVE7_lag14=lag14(feat_moveAVE7);
	feat_moveAVE7_lag30=lag30(feat_moveAVE7);
	feat_moveAVE7_lag60=lag60(feat_moveAVE7);
	feat_moveAVE7_lag120=lag120(feat_moveAVE7);
	feat_moveAVE7_lag240=lag240(feat_moveAVE7);
	feat_moveAVE7_lag365=lag365(feat_moveAVE7);
RUN;


PROC CONTENTS DATA=viyalab.edemand_feat2 OUT=MD NOPRINT;
RUN;

PROC SQL;
	select NAME into: eda_features separated by  " " from md where NAME contains "feat";
QUIT;

/*
 * 2. EDA
 */
PROC SQL;
	create table agg_monthly_edemand AS
		select idmonth, sum(demand) as demand, avg(demand) as demand_avg, std(demand) as demand_std
		from viyalab.edemand_feat1
		where idmonth<=&fore_date
		group by idmonth
		order by idmonth;
QUIT;

Title "Moving Average Analyisis";
PROC SGPLOT DATA=viyalab.edemand_feat2;
	series x=date y=feat_moveAVE3;
	series x=date y=feat_moveAVE7;
RUN;
title;

Title "Moving Standard Deviation Analyisis";
PROC SGPLOT DATA=viyalab.edemand_feat2;
	series x=date y=feat_moveSTD7;
RUN;
Title "Monthly Volatility Analyisis";
PROC SGPLOT DATA=viyalab.edemand_feat1;
	vbox demand / group=idmonth;
RUN;
PROC SGPLOT DATA=agg_monthly_edemand;
	series x=idmonth y=demand_std / MARKERS;
RUN;
title;

/*
 * 3. FEATURE SELECTION
 */


DATA viyalab.train viyalab.test;
	set viyalab.edemand_feat2;
	flg_train=(date<=&train_Date);
	if flg_Train then output viyalab.train;
	else output viyalab.test;
RUN;


PROC PARTITION DATA=viyalab.train samppct=20 partind;
	by month weekday;
	output out=viyalab.train_split;
RUN;

PROC GRADBOOST DATA=viyalab.train_split intervalbins=8 maxdepth=3 MAXBRANCH=2 MINLEAFSIZE= 25 ntrees=100
		ASSIGNMISSING=NONE
        SEED=123; 
	input &eda_features / level=interval;
	target target / level=interval;
	partition rolevar=_PartInd_(train='0' validate='1');
	  /*autotune ...*/
	ods output FitStatistics=gbmFit; 
	ods output VariableImportance=varimp;
RUN;

title "Iteration History";
PROC SGPLOT DATA=gbmFit;
	series x=Trees y=ASETrain;
	series x=Trees y=ASEValid;
RUN;
title;

title "Feature importance";
PROC SGPLOT DATA=varimp;
	hbar Variable / response=Importance CATEGORYORDER=RESPDESC;
RUN;
PROC SQL OUTOBS=20;
	select variable into: imp_features separated by " " from varimp;
QUIT;
title;

/*Final Feature Selection*/
DATA _NULL_;
	LENGTH  features $1000.;
	imp_Features="&imp_features";
	features=catx(" ", imp_Features, "cos_month", "sin_month", "cos_weekday", "sin_weekday");
	call SYMPUTX("features", features);
RUN;
%PUT &features;


/*
 * 4. MODEL BUILDING
 */

/*1 LAYER MLP*/
PROC NNET DATA=viyalab.train_split STANDARDIZE=MIDRANGE;
	architecture  MLP DIRECT;
	optimization algorithm=LBFGS maxiter=100 REGL1=0.1 REGL2=0.1;
	hidden 3; 
	input &features / level=interval;
	target target / level=interval;
	partition rolevar=_partind_(train='0' validate='1');
	train OUTMODEL=viyalab.NN_model_1 NUMTRIES=1;
	score OUT=viyalab.train_scored_1 COPYVARS=(date year qtr month weekday target _PartInd_);
	ods output OptIterHistory=iterhist_1;
RUN;

title1 "1 Hidden Layer 3 units";
title2 "Iteration History";
PROC SGPLOT DATA=iterhist_1;
	series x=Progress y=ValidError;
RUN;
title2 "Forecasting Time Series";
PROC SGPLOT DATA=viyalab.train_scored_1;
	series x=date y=target;
	series x=date y=P_target;
RUN;
title2 "Actual vs Predicted";
PROC SGPLOT DATA=viyalab.train_scored_1;
	by _PartInd_;
	reg x=target y=P_target / LINEATTRS=(COLOR=RED);
RUN;
title2;

title1 "1 Hidden Layer 12 units";
PROC NNET DATA=viyalab.train_split STANDARDIZE=MIDRANGE;
	architecture  MLP DIRECT;
	optimization algorithm=LBFGS maxiter=100 REGL1=0.1 REGL2=0.1;
	hidden 12; 
	input &features / level=interval;
	target target / level=interval;
	partition rolevar=_partind_(train='0' validate='1');
	train OUTMODEL=viyalab.NN_model_2 NUMTRIES=1;
	score OUT=viyalab.train_scored_2 COPYVARS=(date year qtr month weekday target _PartInd_);
	ods output OptIterHistory=iterhist_2;
RUN;

title2 "Iteration History";
PROC SGPLOT DATA=iterhist_2;
	series x=Progress y=ValidError;
RUN;
title2 "Forecasting Time Series";
PROC SGPLOT DATA=viyalab.train_scored_2;
	series x=date y=target;
	series x=date y=P_target;
RUN;
title2 "Actual vs Predicted";
PROC SGPLOT DATA=viyalab.train_scored_2;
	by _PartInd_;
	reg x=target y=P_target / LINEATTRS=(COLOR=RED);
RUN;
title2;

title1 "1 Hidden Layer 24 units";
PROC NNET DATA=viyalab.train_split STANDARDIZE=MIDRANGE;
	architecture  MLP DIRECT;
	optimization algorithm=LBFGS maxiter=100 REGL1=0.1 REGL2=0.1;
	hidden 24; 
	input &features / level=interval;
	target target / level=interval;
	partition rolevar=_partind_(train='0' validate='1');
	train OUTMODEL=viyalab.NN_model_3 NUMTRIES=1;
	score OUT=viyalab.train_scored_3 COPYVARS=(date year qtr month weekday target _PartInd_);
	ods output OptIterHistory=iterhist_3;
RUN;

title2 "Iteration History";
PROC SGPLOT DATA=iterhist_3;
	series x=Progress y=ValidError;
RUN;
title2 "Forecasting Time Series";
PROC SGPLOT DATA=viyalab.train_scored_3;
	series x=date y=target;
	series x=date y=P_target;
RUN;
title2 "Actual vs Predicted";
PROC SGPLOT DATA=viyalab.train_scored_3;
	by _PartInd_;
	reg x=target y=P_target / LINEATTRS=(COLOR=RED);
RUN;
title2;


/*HYPERPARAMETER TUNNING*/
title1 "Hyper parameter tunning with genetic algorithm";
PROC NNET DATA=viyalab.train_split STANDARDIZE=MIDRANGE;
	architecture  MLP DIRECT;
	optimization algorithm=LBFGS maxiter=100;
	input &features / level=interval;
	target target / level=interval;
	train OUTMODEL=viyalab.NN_model_4 NUMTRIES=3;
	score OUT=viyalab.train_scored_4 COPYVARS=(date year qtr month weekday target _PartInd_);
	autotune KFOLD=10 
	useparameters=custom objective=MSE searchmethod=GA
		/*CV on each configuration*/
		popsize=5 /*Number of configurations per iteration*/
		maxiter=5 /*Number of iterations in optimizatio algo*/
		maxevals=50 /*>= posize-1 x maxiter*/
        tuningparameters=(
        	nhidden(LB=1 UB=1 INIT=1) 
        	nunits1(LB=3 UB=12 INIT=3)
	        regl1(LB=1e-04 UB=1e-01 INIT=1e-03)
	        regl2(LB=1e-04 UB=1e-01 INIT=1e-03)
        )
		EVALHISTORY=TABLE;
RUN;

title2 "Forecasting Time Series";
PROC SGPLOT DATA=viyalab.train_scored_4;
	series x=date y=target;
	series x=date y=P_target;
RUN;
title2 "Actual vs Predicted";
PROC SGPLOT DATA=viyalab.train_scored_4;
	by _PartInd_;
	reg x=target y=P_target / LINEATTRS=(COLOR=RED);
RUN;
title2;

/*
 * 5. TEST MODEL
 */

%MLP_Forecast(DATA=viyalab.train_scored_4,
	 OUT=viyalab.test_predict, 
	 MODEL=viyalab.NN_model_4, 
	 CASLIB=viyalab, 
	 id=date, 
	 var=target, 
	 interval=day, 
	 lead=&test_period, 
	 train_date=&Train_Date);
	 

DATA viyalab.valid;
	merge viyalab.test_predict viyalab.test (KEEP=date target);
	by  date;
	flg_Train=(date<=&Train_date);
	resid=target-forecast;
	ape=abs(resid)/target;
	sqresid=resid**2;
RUN;

PROC FEDSQL SESSREF=CASAUTO;
	create table ASSESSMENT as
		select flg_Train, avg(ape) as MAPE, avg(sqresid) as RMSE
		from valid
		group by flg_Train;
	quit;
RUN;


title "Testing Model";
PROC PRINT DATA=viyalab.Assessment;
	id flg_Train;
	var MAPE RMSE;
RUN;
PROC SGPLOT DATA=viyalab.valid;
	where date between intnx('week', &train_date, -2, 'same') and &fore_date;
	series x=date y=target / LINEATTRS=(PATTERN=DASH);
	series x=date y=forecast / LINEATTRS=(COLOR=RED);
	refline &train_date / axis=x;
RUN;
title;


/*
 * 6. FORECASTING 
 */
PROC NNET DATA=viyalab.edemand_feat2 INMODEL=viyalab.NN_model_4;
	score OUT=viyalab.edemand_scored COPYVARS=(_ALL_);
RUN;

%MLP_Forecast(DATA=viyalab.edemand_scored,
	 OUT=viyalab.edemand_forecast, 
	 MODEL=viyalab.NN_model_4, 
	 CASLIB=viyalab, 
	 id=date, 
	 var=target, 
	 interval=day, 
	 lead=&test_period, 
	 train_date=&fore_date);
	 

title "Forecasting Electricity Demand";
PROC SGPLOT DATA=viyalab.edemand_forecast;
	where date >= intnx('week', &train_date, -12, 'same');
	series x=date y=target / LINEATTRS=(PATTERN=DASH);
	series x=date y=forecast / LINEATTRS=(COLOR=RED);
	refline &train_date / axis=x;
	refline &fore_date / axis=x;
RUN;
title;

