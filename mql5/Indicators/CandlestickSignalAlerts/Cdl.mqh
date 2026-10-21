//+------------------------------------------------------------------+
//|                                                          Cdl.mqh |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| Candlestick engine of Candlestick Signal Alerts, one CLOSED bar  |
//| per step (no repaint). 13 patterns; the exact rules are          |
//| tests/reference.py (this file is checked against it bar by bar). |
//| Trend before a pattern: close vs EMA(20). Averages: body and     |
//| range of the 10 bars before.                                     |
//+------------------------------------------------------------------+
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
#ifndef CDL_MQH
#define CDL_MQH

#define CD_NP   13
#define CD_N    16                       // ring of recent bars (the 10-bar average needs 11)
#define CD_EMA  20
#define CD_AVG  10

string CDName(const int p)
  {
   string n[CD_NP]={"Bullish Engulfing","Bearish Engulfing","Hammer","Hanging Man","Inverted Hammer","Shooting Star",
                    "Doji","Morning Star","Evening Star","Bullish Harami","Bearish Harami","Piercing Line",
                    "Dark Cloud Cover"};
   return(p>=0 && p<CD_NP ? n[p] : "?");
  }
string CDShort(const int p)
  {
   string n[CD_NP]={"ENG","ENG","HAM","HANG","IHAM","STAR","DOJI","MSTAR","ESTAR","HAR","HAR","PIER","DCC"};
   return(p>=0 && p<CD_NP ? n[p] : "?");
  }

struct CDState
  {
   int    cnt;
   double o[CD_N],h[CD_N],l[CD_N],c[CD_N],ema[CD_N];
   bool   has_ema[CD_N];
   double ema_sum;
   int    ema_cnt;
   //--- the last bar
   int    ev_mask;
   int    ev_dir[CD_NP];
  };

void CDInit(CDState &s)
  {
   s.cnt=0; s.ema_sum=0; s.ema_cnt=0;
   s.ev_mask=0;
   for(int i=0; i<CD_NP; i++)
      s.ev_dir[i]=0;
  }

int    CDi(const int k) { return(k%CD_N); }
double CDBody(const CDState &s,const int k) { return(MathAbs(s.c[CDi(k)]-s.o[CDi(k)])); }
double CDRange(const CDState &s,const int k) { return(s.h[CDi(k)]-s.l[CDi(k)]); }
double CDUp(const CDState &s,const int k) { return(s.h[CDi(k)]-MathMax(s.o[CDi(k)],s.c[CDi(k)])); }
double CDLo(const CDState &s,const int k) { return(MathMin(s.o[CDi(k)],s.c[CDi(k)])-s.l[CDi(k)]); }
bool   CDBull(const CDState &s,const int k) { return(s.c[CDi(k)]>s.o[CDi(k)]); }
bool   CDBear(const CDState &s,const int k) { return(s.c[CDi(k)]<s.o[CDi(k)]); }
double CDO(const CDState &s,const int k) { return(s.o[CDi(k)]); }
double CDC(const CDState &s,const int k) { return(s.c[CDi(k)]); }

//--- comparisons with the tie tolerance of the bar being decided
double g_cd_tol=0;
bool GE(const double x,const double y) { return(x>=y-g_cd_tol); }
bool LE(const double x,const double y) { return(x<=y+g_cd_tol); }
bool GT(const double x,const double y) { return(x>y+g_cd_tol); }
bool LT(const double x,const double y) { return(x<y-g_cd_tol); }
int CDTrendT(const CDState &s,const int j)
  {
   if(j<0 || !s.has_ema[CDi(j)])
      return(0);
   double c=s.c[CDi(j)],e=s.ema[CDi(j)];
   return(GT(c,e) ? 1 : (LT(c,e) ? -1 : 0));
  }

void CDAdd(CDState &s,const int pat,const int d,const bool &use[])
  {
   if(!use[pat])
      return;
   s.ev_mask|=(1<<pat);
   s.ev_dir[pat]=d;
  }

//--- feed one CLOSED bar; true when it completed at least one pattern (s.ev_mask)
bool CDFeed(CDState &s,const bool &use[],const double o,const double h,const double l,const double c)
  {
   int k=s.cnt,ki=CDi(k);
   s.o[ki]=o; s.h[ki]=h; s.l[ki]=l; s.c[ki]=c;
   s.cnt++;
//--- EMA(20), SMA-seeded
   s.ema_cnt++;
   s.has_ema[ki]=false;
   if(s.ema_cnt<CD_EMA)
      s.ema_sum+=c;
   else
      if(s.ema_cnt==CD_EMA)
        { s.ema_sum+=c; s.ema[ki]=s.ema_sum/CD_EMA; s.has_ema[ki]=true; }
      else
        { s.ema[ki]=s.ema[CDi(k-1)]+2.0/(CD_EMA+1)*(c-s.ema[CDi(k-1)]); s.has_ema[ki]=true; }
//--- patterns
   s.ev_mask=0;
   for(int i=0; i<CD_NP; i++)
      s.ev_dir[i]=0;
   if(k>=CD_AVG && k>=3)
     {
      double ab=0,ar=0;
      for(int j=k-CD_AVG; j<k; j++)
        { ab+=CDBody(s,j); ar+=CDRange(s,j); }
      ab/=CD_AVG; ar/=CD_AVG;
      double b=CDBody(s,k),r=CDRange(s,k),u=CDUp(s,k),w=CDLo(s,k);
      g_cd_tol=1e-9*MathAbs(c);                    // ties within 1e-9 x price count as equal (as tests/reference.py)
      int t1=CDTrendT(s,k-1),t2=CDTrendT(s,k-2),t3=CDTrendT(s,k-3);
      int p=k-1,q=k-2;
      if(CDBear(s,p) && CDBull(s,k) && LE(o,CDC(s,p)) && GE(c,CDO(s,p)) && GT(b,CDBody(s,p)) && t2<0) CDAdd(s,0,1,use);
      if(CDBull(s,p) && CDBear(s,k) && GE(o,CDC(s,p)) && LE(c,CDO(s,p)) && GT(b,CDBody(s,p)) && t2>0) CDAdd(s,1,-1,use);
      if(GT(r,0))
        {
         bool hammer=(GE(w,2*b) && LE(u,0.1*r) && GE(w,0.6*r));
         bool inv=(GE(u,2*b) && LE(w,0.1*r) && GE(u,0.6*r));
         if(hammer && t1<0) CDAdd(s,2,1,use);
         if(hammer && t1>0) CDAdd(s,3,-1,use);
         if(inv && t1<0)    CDAdd(s,4,1,use);
         if(inv && t1>0)    CDAdd(s,5,-1,use);
         if(LE(b,0.05*r) && GE(r,0.5*ar) && t1!=0) CDAdd(s,6,-t1,use);
        }
      double midq=(CDO(s,q)+CDC(s,q))/2,midp=(CDO(s,p)+CDC(s,p))/2;
      if(CDBear(s,q) && GE(CDBody(s,q),ab) && LE(CDBody(s,p),0.3*CDBody(s,q)) && LE(MathMin(CDO(s,p),CDC(s,p)),CDC(s,q)) &&
         CDBull(s,k) && GT(c,midq) && t3<0) CDAdd(s,7,1,use);
      if(CDBull(s,q) && GE(CDBody(s,q),ab) && LE(CDBody(s,p),0.3*CDBody(s,q)) && GE(MathMax(CDO(s,p),CDC(s,p)),CDC(s,q)) &&
         CDBear(s,k) && LT(c,midq) && t3>0) CDAdd(s,8,-1,use);
      if(CDBear(s,p) && GE(CDBody(s,p),ab) && CDBull(s,k) && GE(o,CDC(s,p)) && LE(c,CDO(s,p)) && LT(b,CDBody(s,p)) && t2<0) CDAdd(s,9,1,use);
      if(CDBull(s,p) && GE(CDBody(s,p),ab) && CDBear(s,k) && LE(o,CDC(s,p)) && GE(c,CDO(s,p)) && LT(b,CDBody(s,p)) && t2>0) CDAdd(s,10,-1,use);
      if(CDBear(s,p) && GE(CDBody(s,p),ab) && CDBull(s,k) && LE(o,CDC(s,p)) && GT(c,midp) && LT(c,CDO(s,p)) && t2<0) CDAdd(s,11,1,use);
      if(CDBull(s,p) && GE(CDBody(s,p),ab) && CDBear(s,k) && GE(o,CDC(s,p)) && LT(c,midp) && GT(c,CDO(s,p)) && t2>0) CDAdd(s,12,-1,use);
     }
   return(s.ev_mask!=0);
  }

//--- "Bullish Engulfing, Doji" from a mask (only the given direction when dir != 0)
string CDNames(const CDState &s,const int mask,const int dir)
  {
   string r="";
   for(int i=0; i<CD_NP; i++)
      if((mask&(1<<i))!=0 && (dir==0 || s.ev_dir[i]==dir))
         r+=(r=="" ? "" : ", ")+CDName(i);
   return(r);
  }

#endif
//+------------------------------------------------------------------+
