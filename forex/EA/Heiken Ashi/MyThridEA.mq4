#property copyright "Copyright 2015, MetaQuotes Software Corp."
#property version   "1.00"
#property description "Grid trading, 2015.08.19"

input int inGridInterval = 40;
input double idLots = 0.001;
input int inGridHight = 400;
input int inMAPeriod = 1000;
input int inSlippage = 2;
input double idMinPoint = 0.0001;

#define MYSYMBOL "EURUSD"
#define MYPERIOD PERIOD_M5
#define BUY_COMMENT "buy"
#define SELL_COMMENT "sell"
#define ERRLOG(str) Alert("Function: ",__FUNCTION__,"; Line:",__LINE__,"; ", str);
const int NOTICKETFLAG = -1;

struct stCurTick
{
   int nHour;
   int nMinute;
   double dCurPri;
   double dCurMAPri;
};

bool ArrBuy[];
int ArrBuyTicket[];
bool ArrSell[];
int ArrSellTicket[];
bool ArrBuyUpdateTemp[];
bool ArrSellUpdateTemp[];

bool gIsTrade; 
double gdGridCenterPri = 0.0;
double gdGridCenterMAPri = 0.0;
double gdCorrCenter = 1.0;
int gnGridOneOffset;

int OnInit()
{
   gIsTrade = PreCondition();
   ParaInit();
   return(INIT_SUCCEEDED);
}

void ParaInit()
{
   int nGridWid = (inGridHight / 2 / inGridInterval) * 2 + 1;
   
   ArrayResize(ArrBuy,nGridWid);
   ArrayResize(ArrBuyTicket,nGridWid);
   ArrayResize(ArrSell,nGridWid);
   ArrayResize(ArrSellTicket,nGridWid);
   ArrayResize(ArrBuyUpdateTemp, nGridWid);
   ArrayResize(ArrSellUpdateTemp, nGridWid);
   
   for(int i=0; i<nGridWid; i++)
   {
      ArrBuy[i] = false;
      ArrBuyTicket[i] = NOTICKETFLAG;
      ArrSell[i] = false;
      ArrSellTicket[i] = NOTICKETFLAG;
   }
}

void OnTick()
{
   if(gIsTrade == false) return;
   
   stCurTick curTick = GetBarInfo();
   
   if(UpdateGrid(curTick) == false) return;
   
   OrderOperation(curTick);
}

void OrderOperation(stCurTick& curTick)
{
   int nRatio = 10000;
   
   if(int(gdGridCenterPri * nRatio) == 0) return;
   
   if(false == UpDataFlag()) return;
   
   int nHalfIndex = inGridHight / 2 / inGridInterval; // 5..200,160,120,80,40,0,-40,-80,-120,-160,-200
   int nGridWid = nHalfIndex * 2 + 1;
   
   int nTicket;
   double dTempPri;
   for(int n= -nHalfIndex; n <= nHalfIndex; n++)
   {
      dTempPri = gdGridCenterPri + double(n * inGridInterval) * idMinPoint;
      if((dTempPri - idMinPoint < curTick.dCurPri) && (curTick.dCurPri < dTempPri + idMinPoint))
      {
         if((n == -nHalfIndex))
         {
            if( ArrBuy[0] == false)
            {
               nTicket = OrderSend(MYSYMBOL, OP_BUY, idLots, Ask, inSlippage, 0, Ask + inGridInterval * idMinPoint,BUY_COMMENT,n,0,Blue);
               if(nTicket == -1)
               {
                  ERRLOG("OrderSend Error!");
               }
               
               ArrBuy[0] = true;
               ArrBuyTicket[0] = nTicket;
            }
         }
         else if((n == nHalfIndex))
         {
            if(ArrSell[nGridWid - 1] == false)
            {
               nTicket = OrderSend(MYSYMBOL, OP_SELL, idLots, Bid, inSlippage, 0, Bid - inGridInterval * idMinPoint,SELL_COMMENT,n,0,Red);
               if(nTicket == -1)
               {
                  ERRLOG("OrderSend Error!");
               }
               ArrSell[nGridWid - 1] = true;
               ArrSellTicket[nGridWid - 1] = nTicket;
            }
         }
         else
         {
            if(ArrSell[n + nHalfIndex] == false)
            {
               nTicket = OrderSend(MYSYMBOL, OP_SELL, idLots, Bid, inSlippage, 0, Bid - inGridInterval * idMinPoint,SELL_COMMENT,n,0,Red);
               if(nTicket == -1)
               {
                  ERRLOG("OrderSend Error!");
               }
               ArrSell[n+nHalfIndex] = true;
               ArrSellTicket[n+nHalfIndex] = nTicket;
            }

            if(ArrBuy[n + nHalfIndex] == false)
            {
               nTicket = OrderSend(MYSYMBOL, OP_BUY, idLots, Ask, inSlippage, 0, Ask + inGridInterval * idMinPoint,BUY_COMMENT,n,0,Blue);
               if(nTicket == -1)
               {
                  ERRLOG("OrderSend Error!");
               }
               ArrBuy[n+nHalfIndex] = true;
               ArrBuyTicket[n+nHalfIndex] = nTicket;
            }
         }
         
         n = nHalfIndex + 1;
      }
   }
}

double CalCenterPrice(double dCurMAPri)
{
	double dRatio = 10000.0;
	int n4Pri = dCurMAPri * dRatio;
	int nMod = n4Pri % inGridInterval;

	double dResult = 0.0;
	if(nMod > inGridInterval / 2)
	{
		dResult = (n4Pri + inGridInterval - nMod);
	}
	else
	{
		dResult = (n4Pri - nMod);
	}
	return dResult / dRatio;
}

stCurTick GetBarInfo()
{
   stCurTick curTick;
   curTick.nHour = Hour();
   curTick.nMinute = Minute();
   curTick.dCurPri = Close[0];
   curTick.dCurMAPri = iMA(MYSYMBOL, MYPERIOD, inMAPeriod, 0, MODE_SMA,PRICE_CLOSE,0);
   return curTick;
}

bool gbIsUpdate = false;
bool UpdateGrid(stCurTick& curTick)
{
   if(curTick.nHour > 0) gbIsUpdate = false;
   
   if(curTick.nHour == 0 && curTick.nMinute == 0)
   {
      if(gbIsUpdate == true) return true;
      
      double dCurCenterPri = CalCenterPrice(curTick.dCurMAPri);
      
      if(int(gdGridCenterMAPri * 10000) == 0) 
      {
         gdGridCenterPri = dCurCenterPri;
         gdGridCenterMAPri = curTick.dCurMAPri;
         return true;
      }
      
      int nGridWid = (inGridHight / 2 / inGridInterval) * 2 + 1;
      int nOffset = int((curTick.dCurMAPri - gdGridCenterMAPri) * 10000 / inGridInterval);
      if( nOffset > 0 )
      {
         ERRLOG(nOffset);
         for(int i=1; i<=nOffset; i++)
         {
            if(ArrSellTicket[i] != NOTICKETFLAG)
            {
               if(! OrderClose(ArrSellTicket[i],idLots,Ask,inSlippage,Yellow))
               {
                  ERRLOG("OrderClose Error!");
                  return false;
               }               
            }
            ArrSell[i] = false;
            ArrSellTicket[i] = NOTICKETFLAG;
            GridUpOne();
         }
         //gdGridCenterPri = dCurCenterPri;
         gdGridCenterPri = gdGridCenterPri + (nOffset * inGridInterval) * idMinPoint;
         gdGridCenterMAPri = curTick.dCurMAPri;
      }
      else if(nOffset < 0)
      {
         for(i=1; i<=-nOffset; i++)
         {
            if(ArrBuyTicket[nGridWid - i-1] != NOTICKETFLAG)
            {
               if(! OrderClose(ArrBuyTicket[nGridWid - i-1],idLots,Bid,inSlippage,Yellow))
               {
                  ERRLOG("OrderClose Error!");
                  return false;
               }               
            }
            ArrBuy[nGridWid - i-1] = false;
            ArrBuyTicket[nGridWid - i-1] = NOTICKETFLAG;
            GridDownOne();
         }
         //gdGridCenterPri = dCurCenterPri;
         gdGridCenterPri = gdGridCenterPri + (nOffset * inGridInterval) * idMinPoint;
         gdGridCenterMAPri = curTick.dCurMAPri;  
      }
      else
      {}
      gbIsUpdate = true;
   }
   return true;
}

bool UpDataFlag()
{
   int nGridWid = (inGridHight / 2 / inGridInterval) * 2 + 1;
   int nGridPos = 0;
   for(nGridPos = 0; nGridPos < nGridWid; nGridPos++)
   {
      ArrBuyUpdateTemp[nGridPos] = false;
      ArrSellUpdateTemp[nGridPos] = false;
   }
   
   int nOrderNum = OrdersTotal();
   int nOrderType = 0;
   int nOrderTicket = 0;
   
   for(int nPos=0; nPos < nOrderNum; nPos++)
   {
      if(OrderSelect(nPos,SELECT_BY_POS) == false) 
      {
         ERRLOG("OrderSelect Error!");
         return false;
      }
      
      nOrderType = OrderType();
      nOrderTicket = OrderTicket();
      if(nOrderType == OP_BUY)
      {
         for(nGridPos=0; nGridPos < nGridWid; nGridPos++)
         {
            if(ArrBuyTicket[nGridPos] == nOrderTicket)
            {
               ArrBuyUpdateTemp[nGridPos] = true;
               break;
            }
         }
      }
      
      if(nOrderType == OP_SELL)
      {
         for(nGridPos=0; nGridPos < nGridWid; nGridPos++)
         {
            if(ArrSellTicket[nGridPos] == nOrderTicket)
            {
               ArrSellUpdateTemp[nGridPos] = true;
               break;
            }
         }
      }
   }
   
   for(nGridPos=0; nGridPos < nGridWid; nGridPos++)
   {
      if(ArrBuyUpdateTemp[nGridPos] == true)
      {
         ArrBuy[nGridPos] = true;
      }
      else
      {
         ArrBuy[nGridPos] = false;
         ArrBuyTicket[nGridPos] = NOTICKETFLAG;
      }
      
      if(ArrSellUpdateTemp[nGridPos] == true)
      {
         ArrSell[nGridPos] = true;
      }
      else
      {
         ArrSell[nGridPos] = false;
         ArrSellTicket[nGridPos] = NOTICKETFLAG;
      }
   }
   
   return true;
}

void GridDownOne()
{
   int nGridWid = (inGridHight / 2 / inGridInterval) * 2 + 1;
   for(int i = nGridWid-1; i > 1; i--)
   {
      ArrBuy[i] = ArrBuy[i-1];
      ArrBuyTicket[i] = ArrBuyTicket[i-1];
      ArrSell[i] = ArrSell[i-1];
      ArrSellTicket[i] = ArrSellTicket[i-1];
   }
   ArrBuy[0] = false;
   ArrBuyTicket[0] = NOTICKETFLAG;
   ArrSell[0] = false;
   ArrSellTicket[0] = NOTICKETFLAG;
}

void GridUpOne()
{
   int nGridWid = (inGridHight / 2 / inGridInterval) * 2 + 1;
   for(int i = 1; i < nGridWid; i++)
   {
      ArrBuy[i-1] = ArrBuy[i];
      ArrBuyTicket[i-1] = ArrBuyTicket[i];
      ArrSell[i-1] = ArrSell[i];
      ArrSellTicket[i-1] = ArrSellTicket[i];
   }
   ArrBuy[nGridWid-1] = false;
   ArrBuyTicket[nGridWid-1] = NOTICKETFLAG;
   ArrSell[nGridWid-1] = false;
   ArrSellTicket[nGridWid-1] = NOTICKETFLAG;
}

bool PreCondition()
{
  //if(Period() != PERIOD_M30)
  //{
  //    Alert("The chart is not the m15!"); 
  //    return false;
  //}
  
  if(!IsTradeAllowed())
  {
      ERRLOG(" Expert Advisor is not allowed to trade!");
      return false;
  }
  
  if(!IsConnected())
  {
      ERRLOG("No connection between client terminal and server!");
      return false;
  }
  
  if(Symbol() != MYSYMBOL)
  {
      ERRLOG("The current chart is not the EURUSD!");
      return false;
  }
  return true;
}

void OnDeinit(const int reason)
{}