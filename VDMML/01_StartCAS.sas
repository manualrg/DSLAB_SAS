
/*0. STARTING A CAS SESSION WITH DEFAULT PERSONAL CASLIB AND ASSIGN A LIBREF*/

/*****************************************************************************/
/*  Start a session named mySession using the existing CAS server connection */
/*  while allowing override of caslib, timeout (in seconds), and locale     */
/*  defaults.                                                                */
/*****************************************************************************/


cas mySession sessopts=(caslib=casuser /*casuser personal caslib is set as the active caslib*/
	timeout=1800 locale="en_US");
/* NOTE: 'CASUSER(viyauser)' is now the active caslib.*/

/*
 * Caslibs are the mechanism for accessing data with SAS Cloud Analytic Services (CAS).
 * They provide a volatile, in-memory space to hold tables, access controls, and data source information. 
 * Caslibs provide a way to organize in-memory tables and an associated data source. They also provide a way to apply access controls to data. 
 * A table within a caslib is a temporary, in-memory copy of the original data
 */

/*****************************************************************************/
/*  List all the CAS sessions (and their session properties) created or      */
/*  reconnected to by the SAS Client.                                        */
/*****************************************************************************/

caslib _all_ list;

/*
 *  NOTE: Session = MYSESSION Name = CASUSER(viyauser)  
          Type = PATH  
          Description = Personal File System Caslib  
          Path = /home/viyauser/casuser/  
          Definition =   
 */


/*
 * The CAS LIBNAME engine connects a SAS 9.4 session to an existing CAS session.
 * The libref then becomes your link between SAS and the CAS server. 
 * When you assign a CAS engine libref, you are associating the libref with a CAS session and a caslib in order to work with CAS in-memory tables.
 * 
 * By default, the libref uses the active caslib, which can change as caslibs are added and dropped. 
 * However, you can specify the CASLIB= LIBNAME option to bind the libref to a specific caslib. 
 * In this case, adding and dropping caslibs has no effect on the libref unless the bound caslib is dropped.
 * 
 */

libname mylib CAS SESSREF=mySession  
	caslib=CASUSER;  /*Instead of bounding mylib libref to the default caslib it is bounded to any other: caslib=testTables*/

/*Explore caslib (Active one)*/
PROC CASUTIL;
	title "files in DataSource";
	list files incaslib="casuser";
	title "Tables in SASHDAT in DataSoure";
	list tables incaslib="casuser";
	title;
RUN;


/*1. Load data from SAS workspace Server to CAS with a Data Step*/
OPTIONS msglevel=i;

DATA mylib.CARS;
	set sashelp.cars;
	MPG=mean(MPG_City, MPG_Highway);
	DROP MPG_City MPG_Highway;
RUN;

/*2. Load data from SAS workspace Server to CAS with PROC CASUTIL*/
/*****************************************************************************/
/*  Load SAS data set from a Base engine library (library.tableName) into    */
/*  the specified caslib ("myCaslib") and save as "targetTableName". The     */
/*  PROMOTE option makes loaded data available to all active sessions.       */
/*****************************************************************************/

proc casutil;
	load data=sashelp.iris outcaslib="casuser" /*casuser points to our personal lib*/
	casout="iris" 
	replace /*promote|replace*/;
run;

PROC CASUTIL;
	list tables incaslib="casuser";
RUN;


/*3. Save an in-memory dataset to DataSource as SASHDAT*/
/* Creates a permanent copy of an in-memory table ("sourceTableName") from "sourceCaslib". */
/* The in-memory table is saved to the data source that is associated with the target      */
/* caslib ("targetCaslib") using the specified name ("targetTableName").                   */
/* In format SASHDAT (distributed)*/
/*                                                                                         */
/* To find out the caslib associated with an CAS engine libref, right click on the libref  */
/* from "Libraries" and select "Properties". Then look for the entry named "Server Session */
/* CASLIB".
                                                                                */
proc casutil;
    save casdata="cars" 
    incaslib="casuser" 
    outcaslib="casuser"
	casout="cars_source"
	replace;
run;


/*List every file in CAS Folder*/
PROC CASUTIL;
	list files incaslib="casuser";
RUN;

/*Delete a source file and in-memory datasets*/
PROC CASUTIL;
	droptable casdata="cars";
	droptable casdata="iris";
	list tables incaslib="casuser";
	DELETESOURCE  casdata="cars_source.sashdat";
	list files incaslib="casuser";
RUN;

/*4. Load a csv file from DataSource to memory*/
/*Defining a new caslib will change the active one to csvfiles*/

caslib csvfiles task=add type=dnfs                       
  path="/opt/open/data"
  desc="Spreadsheets and CSV source data." ;
/*NOTE: 'CSVFILES' is now the active caslib.*/ 

caslib _all_ list;
/*
 *  NOTE: Session = MYSESSION Name = CSVFILES  
          Type = DNFS  
          Description = Spreadsheets and CSV source data.  
          Path = /opt/open/data/  
          Definition =   
          Subdirs = No
          Local = Yes
          Active = Yes
          Personal = No <- Not personal
 */

/*Check files in DataSource in this new caslib*/
PROC CASUTIL;
	list files incaslib="csvfiles";
RUN;

%let indata_dir = ../data;
%let indata = hmeq;

proc casutil;
  load casdata="&indata..csv"                     
        importoptions=(filetype="csv" getnames="true")
        casout="&indata."
        replace;
    contents casdata = "&indata.";
quit;

/*My caslib dataset is created, but not accesible from mylib (which is associated to casuser)*/
PROC CASUTIL;
	list tables incaslib="csvfiles";
RUN;

PROC PRINT DATA=mylib.hmeq (OBS=10);
RUN;

libname mycsv CAS SESSREF=mySession  caslib=csvfiles;
PROC PRINT DATA=mycsv.hmeq (OBS=10);
RUN;



		
	


