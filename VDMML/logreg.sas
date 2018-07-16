   /*---------------------------------------------------------
     Generated SAS Scoring Code
     Date: 27Dec2017:15:42:42
     -------------------------------------------------------*/

   drop _badval_ _linp_ _temp_ _i_ _j_;
   _badval_ = 0;
   _linp_   = 0;
   _temp_   = 0;
   _i_      = 0;
   _j_      = 0;

   array _xrow_0_0_{22} _temporary_;
   array _beta_0_0_{22} _temporary_ (   -0.47601496779388
          -0.00637737633907
           0.00527948098344
           0.69418006283888
           0.48233988872866
        -7.3889013057881E-6
         4.7923875979572E-6
           0.16345812561716
          -0.01418559254997
           -0.2077631592637
          -0.06619202859262
           0.14368411959678
          -0.28339092551725
           0.17340393680296
          -0.14796643524828
           0.96384178378148
           0.62382435768629
          -2.08275797610924
                          0
           0.34726682369438
           0.06702258936451
                          0);

   length _JOB_ $7; drop _JOB_;
   _JOB_ = left(trim(put(JOB,$7.)));
   length _REASON_ $7; drop _REASON_;
   _REASON_ = left(trim(put(REASON,$7.)));
   if missing(IM_CLAGE)
      or missing(IM_LOAN)
      or missing(tot_mis)
      or missing(BIN_DEBTINC)
      or missing(IM_DELINQ)
      or missing(BIN_VALUE)
      or missing(IM_DEROG)
      or missing(IM_CLNO)
      or missing(IM_YOJ)
      or missing(IM_MORTDUE)
      or missing(IM_NINQ)
      then do;
         _badval_ = 1;
         goto skip_0_0;
   end;

   do _i_=1 to 22; _xrow_0_0_{_i_} = 0; end;

   _xrow_0_0_[1] = 1;

   _xrow_0_0_[2] = IM_CLAGE;

   _xrow_0_0_[3] = IM_CLNO;

   _xrow_0_0_[4] = IM_DELINQ;

   _xrow_0_0_[5] = IM_DEROG;

   _xrow_0_0_[6] = IM_LOAN;

   _xrow_0_0_[7] = IM_MORTDUE;

   _xrow_0_0_[8] = IM_NINQ;

   _xrow_0_0_[9] = IM_YOJ;

   _xrow_0_0_[10] = BIN_DEBTINC;

   _xrow_0_0_[11] = BIN_VALUE;

   _xrow_0_0_[12] = tot_mis;

   _temp_ = 1;
   select (_JOB_);
      when ('Office') _xrow_0_0_[13] = _temp_;
      when ('Other') _xrow_0_0_[14] = _temp_;
      when ('ProfExe') _xrow_0_0_[15] = _temp_;
      when ('Sales') _xrow_0_0_[16] = _temp_;
      when ('Self') _xrow_0_0_[17] = _temp_;
      when ('missing') _xrow_0_0_[18] = _temp_;
      when ('Mgr') _xrow_0_0_[19] = _temp_;
      otherwise do; _badval_ = 1; goto skip_0_0; end;
   end;

   _temp_ = 1;
   select (_REASON_);
      when ('HomeImp') _xrow_0_0_[20] = _temp_;
      when ('missing') _xrow_0_0_[21] = _temp_;
      when ('DebtCon') _xrow_0_0_[22] = _temp_;
      otherwise do; _badval_ = 1; goto skip_0_0; end;
   end;

   do _i_=1 to 22;
      _linp_ + _xrow_0_0_{_i_} * _beta_0_0_{_i_};
   end;

   skip_0_0:
   label P_BAD1 = 'Predicted: BAD=1';
   if (_badval_ eq 0) and not missing(_linp_) then do;
      if (_linp_ > 0) then do;
         P_BAD1 = 1 / (1+exp(-_linp_));
      end; else do;
         P_BAD1 = exp(_linp_) / (1+exp(_linp_));
      end;
      P_BAD0 = 1 - P_BAD1;
   end; else do;
      _linp_ = .;
      P_BAD1 = .;
      P_BAD0 = .;
   end;


