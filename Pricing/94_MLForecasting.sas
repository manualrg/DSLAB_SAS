

DATA stocks_IBM;
	set sashelp.stocks;
	where stock="IBM";
	ydiff1=dif(Close);
	t=_N_;
RUN; 



PROC ARIMA data=stocks_IBM plots=all out=forecast_arima;
	identify var=Close(1); /*First order difference in close*/
	estimate p=3 q=2 method=ML OUTEST=params_arima OUTSTAT=stats_Arima;
	forecast lead=3;
RUN;

proc forecast data=stocks_IBM interval=day
              method=winters lead=3
              out=forecast_hw outfull outresid outest=params_hw;
   id date;
   var Close;
run;


DATA stocks_IBM_FeatEng1;
	set stocks_IBM;
	weekday=weekday(date);
	monthday=day(date);
	month=month(date);
	qtr=qtr(date);
	year=year(date);

	plag1=lag1(Close);
	plag2=lag2(Close);
	plag3=lag3(Close);
	plag7=lag7(Close);
	plag14=lag14(Close);
	plag30=lag30(Close);
	
RUN;

PROC SORT DATA=stocks_IBM_FeatEng1 OUT=stocks_IBM_FeatEng1_srt;
	by date;
RUN;

PROC EXPAND DATA=stocks_IBM_FeatEng1_srt OUT=stocks_IBM_FeatEng2;
	id  date ;
	convert Close = p_mavg3d / transformout=(MOVAVE 3);
	convert Close = p_mavg7d / transformout=(MOVAVE 7);
	convert Close = p_mavg14d / transformout=(MOVAVE 14);
	convert Close = p_mavg30d / transformout=(MOVAVE 30);
	
	convert Close = p_MOVMAX3d / transformout=(MOVMAX 3);
	convert Close = p_MOVMAX7d / transformout=(MOVMAX 7);
	convert Close = p_MOVMAX14d / transformout=(MOVMAX 14);
	convert Close = p_MOVMAX30d / transformout=(MOVMAX 30);
	
	convert Close = p_MOVMIN3d / transformout=(MOVMIN 3);
	convert Close = p_MOVMIN7d / transformout=(MOVMIN 7);
	convert Close = p_MOVMIN14d / transformout=(MOVMIN 14);
	convert Close = p_MOVMIN30d / transformout=(MOVMIN 30);
	
	convert Close = p_MOVSTD3d / transformout=(MOVSTD 3);
	convert Close = p_MOVSTD7d / transformout=(MOVSTD 7);
	convert Close = p_MOVSTD14d / transformout=(MOVSTD 14);
	convert Close = p_MOVSTD30d / transformout=(MOVSTD 30);
	
RUN;
/*
 * weekday monthday month qtr year plag1 plag2 plag3 plag7 plag14 plag30
 */
/*p_mavg3d p_mavg7d p_mavg14d p_mavg30d
p_MOVMAX3d p_MOVMAX7d p_MOVMIN14d p_MOVMIN30d
p_MOVMIN3d p_MOVMIN7d p_MOVMIN14d p_MOVMIN30d
p_MOVSTD3d p_MOVSTD7d p_MOVSTD14d p_MOVSTD30d
*/
DATA stocks_IBM_FeatEng3;
	merge stocks_IBM_FeatEng2 (IN=a) 
		stocks_IBM_FeatEng1_srt(IN=b);
	by date;
	if a and b;
RUN;


proc hpforest data=stocks_IBM_FeatEng3
		maxtrees= 200 seed=123
		/*bagging*/
		INBAGFRACTION=0.5
		/*spliting*/
		/*vars_to_try=4*/
		PRESELECT=BINNEDSEARCH /*default*/
		/*overfiting control*/
		maxdepth=20
		CATBINS=32 /*default*/
		INTERVALBINS=32 /*default=100*/
		;
	target Close / level= interval;
	input weekday monthday month qtr year / LEVEL=nominal;
	input  year plag1 plag2 plag3 plag7 plag14 plag30 
			p_mavg3d p_mavg7d p_mavg14d p_mavg30d
		p_MOVMAX3d p_MOVMAX7d p_MOVMIN14d p_MOVMIN30d
		p_MOVMIN3d p_MOVMIN7d p_MOVMIN14d p_MOVMIN30d
		p_MOVSTD3d p_MOVSTD7d p_MOVSTD14d p_MOVSTD30d/ level=interval;
	score OUT=forecast_ML;
	ods output fitstatistics = fitstats;
run;


PROC SGPLOT DATA=fitstats;
	series x=ntrees y=predall  / LINEATTRS=(COLOR=BLUE);
	series x=ntrees y=predoob / LINEATTRS=(COLOR=RED);
RUN;


PROC SGPLOT DATA=forecast_ML;
	scatter x=Close y=p_Close;
	reg x=Close y=p_Close / LINEATTRS=(COLOR=RED);
RUN;
