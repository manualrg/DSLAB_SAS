# **SAS VIYA: PREDICTIVE MODELLING LAB**

## Visualization:
Due to visualization issues of the SAS notebook in GitHub, it is recommended to display it in nbviewer:

http://nbviewer.jupyter.org/

Just copy the link of the notebook and enjoy it!

https://github.com/manualrg/SASViya_LAB/blob/master/03_PredictiveModeling.ipynb

On the other hand, a html version can be donwloaded from the repository.

## Objective:

The main objective of this lab is to explore new features available in the new SAS Big Data platform called SAS Viya. In addition, we will try to understand the underlying processing of the CAS (Cloud Analytics Server) Engine (Distributed and in-memory) and its main differences and similarities with SAS 9.4.

https://www.sas.com/en_us/software/viya.html

## Contents:
* 01_StartCAS.sas
* 02_DataManagement.sas	
* 03_PredictiveModeling.ipynb	
* 04_TextAnalytics.ipynb
* 05_EDemand_Forecasting.ipynb

### 01_StartCAS.sas
Run a CAS session and get used to CASLIBs

### 02_DataManagement.sas
Basic Features in SAS Viya Programming

### 03_PredictiveModeling.ipynb

We will cover new features and/or analyze how old features (like DATA Step) work in Viya enviroment in order to:
1. Start a CAS session and load a table from CAS DataSource and 
2. Explore and analize data
3. Perform simple feature engineering tasks, like missing value imputation and feature binning.
4. Build several predictive models and explore the new feature to **tune hyperparameters**:
* Logistic regression
* Decision Tree
* Random Forest
* Gradient Boosted Tree
5. Assess model performance

The data is a example dataset provided in the trial platform called hmeq, available as a .csv file. Its response variable is called BAD and it is a binary classification problem.

Therefore, some old features will be used in addition to new procedures only found in SAS Viya. Those procecures are the programming interface that support the core tool in Viya: Visual Data Mining and Machine Learning (VDMML) . We will go over some Utility, Statistics and Machine Learning PROCs that process data leveraing the CAS Engine, and its hability to perform in-memory distributed computations.

### 04_TextAnalytics.ipynb. 
We will explore some text analytics features licensed under Visual Analytics an VDMML Licenses (Remember that there is an specific Visual Interface called Visual Text Analytics with extended features). The main goal is to research the following capabilities:
* Perform topic modelling: An unsupervised learning technique that given a set of documents (also called corpus) classifies them in several topics.
* Sentiment Analysis: A preloaded Sentiment Analysis Model (SAM) is available, so we can leverage it and distinguish whether a document is positive, neutral or negative.
* Boolean Rules extration: Given a labelled corpus (Classified documents) we can use this action in order to extract a set of terms that depending on whether they are present or not, the document belong to an specific class. 

** For example: Rate+Interest-Politician -> Banking document
** Interest+Politician+ Inflation -> Politics document

The dataset is a corpus of labelled as 0 or 1 movie reviews extracted from IMBD. The code is in SAS CAS Actions, and some basic output analysis is carried out in order to get used to CAS Actions.

### 05_EDemand_Forecasting.ipynb
Finally, in the last notebook is the most advanced one. Neural Networks and GBTs are used to forecast Electicity Demand in Spanish electricity market. In this noteook, the main SAS Viya feature tested is hyperparameter tuning wigh genetic algorithm (GA).
1. Feature Engineering: Computed lagged and window statistics to serve as features to a Neural Network
2. EDA: Brief Time series analysis to investigate data
3. Feature Selection: Use a GBT to select a subset of features
4. Model Building and Hyperparameter Tuning: Fit several NN and use a GA algo in order build the best model
5. Test Model: Compute predictions on test data
6. Forecasting: Forecast 90 days ahead.

## Documentation:
Refer to SAS documentation in SAS Viya 3.3 and Visual Data Mining and Machine Learning Version 8.2.

## Software:

SAS provides a free trial available for 8 hours to get used to its new platform: 

https://www.sas.com/en_us/trials/software/viya-developer/form.html

It gives access to the programming interface (in SAS Studio or IPython Notebooks) as well as to the visual tools.

