//+------------------------------------------------------------------+
//|                                                     KAVER_01.mq4 |
//|                                                     Oviedo Pablo |
//|                                                         kaver.co |
//+------------------------------------------------------------------+
#property copyright "Oviedo Pablo"
#property link      "kaver.co"
#property version   "2.00"
#property strict
extern int MagicNumber        = 10001;
extern double Lots            = 0.01;
extern double StopLoss        = 500;
extern double TakeProfit      = 500;
extern int TrailingStop       = 100;
extern int Slippage           = 3;
extern int Candles            = 6;
extern int CandlesSup         = 108;   //Velas de la temporalidad supuerior
extern int HourFrom           = 0;
extern int HourTo             = 23;
extern int FastMA             = 0;
extern int SlowMA             = 0;
extern int MaxTrades          = 10;
extern int MaxGrid            = 10;
extern int PrimaryADX         = 12;
extern int SecondaryADX       = 192;
extern int MinMinutesClose    = 15;   //Minutos a esperar para cerrar una orden
extern int MinMinutesOpen     = 15;   //Minutos a esperar para abrir nueva orden
extern double MinDistanceGrid = 100;  //Distancia minima para GRID
extern bool CloseDay          = false;//Cerrar al finalizar el dia
extern double GridLots        = 0.01; //Lotaje a sumar en grid Lots + GirdLots

enum ENUM_TRADE_MODE{ 
                      BUY_SELL,      // Compras y ventas
                      ONLY_BUY,      // Solo compras
                      ONLY_SELL,     // Solo ventas
                      SYSTEM_DEFINED // Tendencia D1
                    };   
extern ENUM_TRADE_MODE TradeMode = SYSTEM_DEFINED; //Modo de operacion
extern int MA_SYSTEM_DEFINED     = 3; //MA para Tendencia D1

datetime candleITime     = NULL;
int Bulls                = 0;
int Bears                = 0;
double BullsCandles      = 0;
double BearsCandles      = 0;
double BullsCandlesSup   = 0;
double BearsCandlesSup   = 0;
double Higest            = 0;
double Lowest            = 0;
double dif               = 0;
double buyPoint          = 0;
double sellPoint         = 0;
double entryPoint        = 0;
double entrySellPoint    = 0;
double entryBuyPoint     = 0;
double tpPoint           = 0;
double slPoint           = 0;
double mechaSuperior     = 0;
double mechaInferior     = 0;
double mechaSuperiorSup  = 0;
double mechaInferiorSup  = 0;

//PARA EL MARCO DE TRABAJO
int fuerzaTotal           = 0;
int fuerzaCompras         = 0;
int fuerzaVentas          = 0;
double totalVelas         = 0;
double totalCuerposCompra = 0;
double totalCuerposVenta  = 0;

//PARA LAS FLAGS DE COMPRA
double greenFlag1         = false;
double greenFlag2         = false;
double greenFlag3         = false;

//PARA EL MARCO DE TRABAJO SUPERIOR
int fuerzaTotalSup           = 0;
int fuerzaComprasSup         = 0;
int fuerzaVentasSup          = 0;
double totalVelasSup         = 0;
double totalCuerposCompraSup = 0;
double totalCuerposVentaSup  = 0;

//VARIABLES FINALES PARA CALCULOS
double _mSuperior     = 0;
double _mInferior     = 0;
double _cSuperior     = 0;
double _cInferior     = 0;
double _fCompras      = 0;
double _fVentas       = 0;
int _vSuperior        = 0;
int _vInferior        = 0;
int _vCompra          = 0;
int _vVenta           = 0;

bool flagCompra       = false;
bool flagVenta        = false;
int flagM30           = 0; //1 por encima, 0 por debajo

double dayMax         = 0;
double dayMin         = 0;
bool canOpen          = true;

double prevDay        = 0; //1-verde, 2-roja
double prevDayMin     = 0;
double prevDayMax     = 0;
bool canBuy           = false;
bool canSell          = false;
int TodayOrders       = 0;

//Array para guardar la fuerza del mercado en H4
double fuerzaCompraMaxima[3]   = {0,0,0,0}; 
double fuerzaVentaMaxima[3]    = {0,0,0,0}; 
double fuerzaMaxima[3]         = {0,0,0,0}; 
double fuerzaCompraSuperior[3] = {0,0,0,0}; 
double fuerzaVentaSuperior[3]  = {0,0,0,0}; 
double fuerzaSuperior[3]       = {0,0,0,0}; 
double superiorPlusADX         = 0;
double superiorMinusADX        = 0;
double StopToOpen              = 0;
double FirstTakeProfit         = 0;
   
//+------------------------------------------------------------------+
//    expert start function
//+------------------------------------------------------------------+

int TotalOrdersCount()
{
  int result     = 0;
  int todayTotal = 0;
  for(int i=0;i<OrdersTotal();i++) {
     OrderSelect(i,SELECT_BY_POS ,MODE_TRADES);
     //Print(StringFind( OrderComment(), "HEDGE" ) == -1);
     if (OrderMagicNumber()==MagicNumber) result++;
  }
  
  return (result);
}

int TotalOrdersCountByType( int operation )
{
  int result     = 0;
  int todayTotal = 0;
  for(int i=0;i<OrdersTotal();i++) {
     OrderSelect(i,SELECT_BY_POS ,MODE_TRADES);
     if (OrderMagicNumber()==MagicNumber && OrderType() == operation ) result++;
  }
  
  return (result);
}

void TotalTodayOrdersCount()
{

  int todayTotal = 0;
  datetime Today = StrToTime(StringConcatenate(Year(), ".", Month(), ".", Day()));
  for(int i=0;i<OrdersHistoryTotal();i++) {
     OrderSelect(i,SELECT_BY_POS ,MODE_HISTORY);
     if (OrderMagicNumber()==MagicNumber){
         if(OrderType() == OP_BUY || OrderType() == OP_SELL ){
            if(OrderCloseTime() >= Today ) todayTotal++;
         }
     }
  }
  
  TodayOrders = todayTotal;
  
  //Comment(StringFormat("Ordenes: %G\n", todayTotal));
}


void dayReset() {
   dayMax          = 0;
   dayMin          = 0;
   canOpen         = true;
   StopToOpen      = 0;
   FirstTakeProfit = 0;
   
   for(int cnt=0;cnt<OrdersTotal();cnt++) {
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);

      if( OrderType()==OP_SELLLIMIT || OrderType()==OP_BUYLIMIT ){
         OrderDelete(OrderTicket(), Green);
      }
   }
   
   if( CloseDay == true ) {
      if( OrderType()==OP_BUY ){
         OrderClose(OrderTicket(), OrderLots(), Bid,3,Green);
      }
      if( OrderType()==OP_SELL ){
         OrderClose(OrderTicket(), OrderLots(), Ask,3,Green);
      }
   }
}

int OnInit() {
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){ }

void closeAllOrders(){

   for (int i = (OrdersTotal() - 1); i >= 0; i--)
   {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      
      if( OrderType()==OP_BUY && canClose() == true ){
         OrderClose(OrderTicket(), OrderLots(), Bid,3,Purple);
      }
      if( OrderType()==OP_SELL && canClose() == true ){
         OrderClose(OrderTicket(), OrderLots(), Ask,3,Purple);
      }
   }

}

int getLastClosed(){
   
   int closeTime  = 0;
   int i          = 1;
   string comment = "";
   
   do
   {
      OrderSelect(OrdersHistoryTotal()-i, SELECT_BY_POS, MODE_HISTORY);
      closeTime = OrderCloseTime();
      comment   = OrderComment();   
      i++;
   }
   
   while( i<=OrdersHistoryTotal() && StringFind(comment,"HEDGE") == -1 );
   return closeTime;
}

/* GENERA UNA COMPRA SI ES POSIBLE */ 
int buy( string comment, double tp, double lots ){

   int result = -1;
   
   if( (TimeCurrent() - getLastClosed()) > MinMinutesClose*60 ){
     
      result = OrderSend(Symbol(),OP_BUY,lots,Ask,Slippage,0,0,comment, MagicNumber, 0, Blue);

      //SI FUE CREADA CON EXITO LE SETEO EL TP Y SL
      if(result > 0){
         
         double TheStopLoss = 0;
         if(StopLoss>0){
            TheStopLoss = NormalizeDouble(Bid-StopLoss*Point,Digits);
         }

         /*--------calculo el takeProfit-------*/
         double takeP = tp;
         if(tp == -1){
            takeP = 0;
         } else {
            if( takeP == 0 && TakeProfit>0 ){
               takeP   = NormalizeDouble(Ask+TakeProfit*Point,Digits);
            } else {
               takeP = tp;
            }
         }
         /*--------/calculo el takeProfit-------*/   
   
         OrderSelect(result,SELECT_BY_TICKET);
         bool res = OrderModify( OrderTicket(), OrderOpenPrice(), TheStopLoss, takeP, 0, Green );
         if(!res)
            Print("Error al modificar (1). Error: ",GetLastError());
      }
   }
   return result;
}

int sell( string comment, double tp, double lots ){

   int result = -1;
   
   if( (TimeCurrent() - getLastClosed()) > MinMinutesClose*60 ){ //4 horas
      
      int result = OrderSend(Symbol(),OP_SELL,lots,Bid,Slippage,0,0, comment, MagicNumber,0,Red);
      if(result>0){
         
         double TheStopLoss = 0;
         if(StopLoss>0){
            TheStopLoss = NormalizeDouble(Ask+StopLoss*Point,Digits);
         }
         
         /*--------calculo el takeProfit-------*/
         double takeP = tp;
         if(tp == -1){
            takeP = 0;
         } else {
            if( takeP == 0 && TakeProfit > 0){
               takeP = NormalizeDouble(Bid-TakeProfit*Point,Digits);
            } else {
               takeP = tp;
            }
         }
         /*--------/calculo el takeProfit-------*/
   
         OrderSelect(result,SELECT_BY_TICKET);
         bool res = OrderModify( OrderTicket(), OrderOpenPrice(), TheStopLoss, takeP, 0, Green );
         if(!res)
            Print("Error al modificar (2). Error: ",GetLastError());
            
      }
   }
   return result;
}


void prevDayCandle() {
   double dayClose = iClose(NULL, PERIOD_D1, 1);
   double dayOpen  = iOpen(NULL, PERIOD_D1, 1);
   prevDayMin      = iLow(NULL, PERIOD_D1, 1);
   prevDayMax      = iHigh(NULL, PERIOD_D1, 1);
   
   if(dayClose > dayOpen){
      prevDay = 1;//VELA VERDE
      canBuy  = true;
      canSell = false;
   } else {
      prevDay = 2;//VELA ROJA
      canBuy  = false;
      canSell = true;
   }
}

double getMomentum( int candles, int shift, int period ){
   return NormalizeDouble( iMomentum(NULL, period, candles, PRICE_CLOSE, shift), 1);
}

double CheckProfit()
{

   double pipsmultiplier;

   if(MarketInfo(Symbol(),MODE_DIGITS)==3 && MarketInfo(Symbol(),MODE_DIGITS)==5) {
      pipsmultiplier=10;
   } else {
      pipsmultiplier=10; 
   }

   double profit = 0;
   for(int x = OrdersTotal() - 1; x >= 0; x--)
   {
      if(!OrderSelect(x, SELECT_BY_POS, MODE_TRADES))
         break;
      if(OrderSymbol() != Symbol() && OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         profit += OrderProfit() + OrderSwap() + OrderCommission();
   }
   
   double prof=NormalizeDouble((profit)/(pipsmultiplier)*MarketInfo(Symbol(),MODE_POINT),8);
   
   return(profit);
   
}
 

double getStoch( int candles, int period, int shift ){ 
   return NormalizeDouble( iStochastic(NULL, period, candles, 3, 3, MODE_LWMA, 1, MODE_MAIN, shift), 1);
}



/*
* FUNCIONES PARA EL CALCULO DE LA TENDENCIA SUPERIOR
* SI LA LINEA MAIN ESTA POR DEBAJO DE 25 EL PRECIO SE VUELVE TONTO SIN SEGUIR TENDENCIAS
*/
int tendenciaSuperior(){//EL COMENTARIO
   //0-RANGO
   //1-COMPRA
   //2-COMPRA-FUERTE
   //3-VENTA
   //4-VENTA-FUERTE
   
   for(int i=0;i<4;i++){
      fuerzaSuperior[i] = NormalizeDouble( iADX(NULL,PERIOD_H1,16,PRICE_WEIGHTED,MODE_MAIN,i), 2);
   }
   
   for(int i=0;i<4;i++){
      fuerzaCompraSuperior[i] = NormalizeDouble( iADX(NULL,PERIOD_H1,16,PRICE_WEIGHTED,MODE_PLUSDI,i), 2);
   }
   
   for(int i=0;i<4;i++){
      fuerzaVentaSuperior[i] = NormalizeDouble( iADX(NULL,PERIOD_H1,16,PRICE_WEIGHTED,MODE_MINUSDI,i), 2);
   }
   
   for(int i=0;i<4;i++){
      fuerzaMaxima[i]       = NormalizeDouble( iADX(NULL,PERIOD_H4,16,PRICE_CLOSE,MODE_MAIN,i), 2);
   }
   
   for(int i=0;i<4;i++){
      fuerzaCompraMaxima[i] = NormalizeDouble( iADX(NULL,PERIOD_H4,16,PRICE_CLOSE,MODE_PLUSDI,i), 2);
   }
   
   for(int i=0;i<4;i++){
      fuerzaVentaMaxima[i]  = NormalizeDouble( iADX(NULL,PERIOD_H4,16,PRICE_CLOSE,MODE_MINUSDI,i), 2);
   }
   
   int tendencia   = 0;
   double mainADX  = iADX(NULL,PERIOD_H1,16,PRICE_WEIGHTED,MODE_MAIN,0);
   double plusADX  = iADX(NULL,PERIOD_H1,16,PRICE_WEIGHTED,MODE_PLUSDI,0);
   double minusADX = iADX(NULL,PERIOD_H1,16,PRICE_WEIGHTED,MODE_MINUSDI,0);
   
   superiorPlusADX  = NormalizeDouble(plusADX,2);
   superiorMinusADX = NormalizeDouble(minusADX,2);
   
   //SI LA LINEA MAIN ESTA POR ENCIMA DE LAS DEMAS, HAY FUERZA EN LA TENDENCIA
   if( mainADX > plusADX && mainADX > minusADX){
      if(plusADX > minusADX){
         tendencia = 2;   
      } else {
         tendencia = 4;
      }     
   }
   
   //SI UNA LINEA ESTA SOBRE LA OTRA LA TENDENCIA ES A FAVOR DE LA SUPERIOR
   if( plusADX > minusADX ) {
      tendencia = 3;
   } else {
      tendencia = 5;
   }
   
   //SI LA LINEA MAIN ESTA POR DEBAJO DE LAS 2 LA TENDENCIA ES 0
   if( mainADX < plusADX && mainADX < minusADX){
      tendencia = 0;
   }
   
   return tendencia;
}

/*
* /FUNCIONES PARA EL CALCULO DE LA TENDENCIA SUPERIOR
*/

void OnTick(){   
    
    
   tendenciaSuperior();
   TotalTodayOrdersCount();
  
   if (ObjectFind("time") == -1 ){
      ObjectCreate("time", OBJ_LABEL, 0, 0, 0);
      ObjectSet("time", OBJPROP_BACK, 0);
   }
   
   ObjectSet("time", OBJPROP_CORNER, 0);
   ObjectSet("time", OBJPROP_XDISTANCE, 300);
   ObjectSet("time", OBJPROP_YDISTANCE, 10);
   ObjectSetText("time",""+TimeToStr(TimeCurrent(),TIME_MINUTES|TIME_SECONDS)+" la vela cierra en "+TimeToStr(Time[0]+Period()*60-TimeCurrent(),TIME_SECONDS)+"", 12,"Arial",Purple);

   double MyPoint = Point;
   if( Digits==3 || Digits==5 ) MyPoint = Point*10;
   
   //PARA EL RESET DIARIO
   if(TimeHour(TimeCurrent()) >= 0 && TimeHour(TimeCurrent()) < HourFrom  ){
      dayReset();
      prevDayCandle();
   }
   
   double currentMainADX  = NormalizeDouble(iADX(NULL,PERIOD_M5,12,PRICE_WEIGHTED,MODE_MAIN,0), 2);
   double currentPlusADX  = NormalizeDouble(iADX(NULL,PERIOD_M5,12,PRICE_WEIGHTED,MODE_PLUSDI,0), 2);
   double currentMinusADX = NormalizeDouble(iADX(NULL,PERIOD_M5,12,PRICE_WEIGHTED,MODE_MINUSDI,0), 2);
   
   
   if( TotalOrdersCount() == 0 && (TimeHour(TimeCurrent()) >= HourFrom ) && ( TimeHour(TimeCurrent()) < HourTo ) && TodayOrders < MaxTrades ) {
      
      //PRIMERO SETEO LOS MAXIMOS Y MINIMOS HASTA LA HORA DE INICIO
      if(dayMax == 0 || dayMin == 0){
         dayMax = Close[iHighest(NULL, PERIOD_M5, MODE_HIGH, CandlesSup, 0)];
         dayMin = Close[iLowest(NULL, PERIOD_M5, MODE_LOW, CandlesSup, 0)];
      }
      
      double dif         = 0;
      double momentumDay = iMomentum(NULL, PERIOD_D1, 180, PRICE_WEIGHTED, 0);
      double plusADX     = iADX(NULL,PERIOD_H4,16,PRICE_LOW,MODE_PLUSDI,0);
      double minusADX    = iADX(NULL,PERIOD_H4,16,PRICE_LOW,MODE_MINUSDI,0);
      
      double dailyPlusADX  = iADX(NULL,PERIOD_H1,36,PRICE_WEIGHTED,MODE_PLUSDI,0);
      double dailyMinusADX = iADX(NULL,PERIOD_H1,36,PRICE_WEIGHTED,MODE_MINUSDI,0);
      
      if( plusADX > minusADX ) {
         dif = plusADX - minusADX;
      } else {
         dif = minusADX - plusADX;
      }
      
      double superiorModeUpper = NormalizeDouble( iBands(NULL, PERIOD_H1, 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 0), 5 );
      double superiorModeLower = NormalizeDouble( iBands(NULL, PERIOD_H1, 20, 2, 0, PRICE_CLOSE, MODE_LOWER, 0), 5 );
      
      double modeUpper       = NormalizeDouble( iBands(NULL, PERIOD_M5, 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 0), 5 );
      double modeLower       = NormalizeDouble( iBands(NULL, PERIOD_M5, 20, 2, 0, PRICE_CLOSE, MODE_LOWER, 0), 5 );
      double prevCandleClose = NormalizeDouble( iClose(NULL, PERIOD_M5, 1), 5 );
      
      
      /** CALCULOS V2 **/
      int val         = 0;
      int momentums   = 0;
      int stochastics = 0;
      int adxs        = 0;
      
      //calculo los momentums
      for(int i=0;i<ArraySize(periods);i++)
      {
         double mom = getMomentum(12,0,periods[i]);
         
         if( mom > 100.5 ){
            momentums = momentums+3;
         } else if( mom < 100.5 && mom > 100.2 ) {
            momentums = momentums+2;
         } else if( mom < 100.2 && mom > 100.05 ) {
            momentums = momentums+1;
         } else if( mom < 100.05 && mom > 99.95 ) {
            momentums = momentums;
         } else if( mom < 99.95 && mom > 99.8 ) {
            momentums = momentums -1;
         } else if( mom < 99.8 && mom > 99.5 ) {
            momentums = momentums -2;
         } else {
            momentums = momentums -3;
         }
      }
      
      //calculo los stochs
      for(int i=0;i<ArraySize(periods);i++)
      {
         double sto = getStoch(12, periods[i],0);
         
         if( sto > 99.0 ){
            stochastics = stochastics+3;
         } else if( sto < 99.0 && sto > 90.0 ) {
            stochastics = stochastics+2;
         } else if( sto < 90.0 && sto > 80.0 ) {
            stochastics = stochastics+1;
         } else if( sto < 80.0 && sto > 20.0 ) {
            stochastics = stochastics;
         } else if( sto < 20.0 && sto > 10.0 ) {
            stochastics = stochastics -1;
         } else if( sto < 10.0 && sto > 1.0 ) {
            stochastics = stochastics -2;
         } else {
            stochastics = stochastics -3;
         }
      }
      
      //calculo los adxs
      for(int i=0;i<ArraySize(periods);i++)
      {
         double mainADX  = iADX(NULL,periods[i],12,PRICE_WEIGHTED,MODE_MAIN,0);
         double plusADX  = iADX(NULL,periods[i],12,PRICE_WEIGHTED,MODE_PLUSDI,0);
         double minusADX = iADX(NULL,periods[i],12,PRICE_WEIGHTED,MODE_MINUSDI,0);
         
         if( mainADX > plusADX && plusADX > minusADX ){
            adxs = adxs + 3;
         } else if( plusADX > mainADX && mainADX > minusADX ){
            adxs = adxs + 2;
         } else if( plusADX > mainADX && minusADX > mainADX && plusADX > minusADX ){
            adxs = adxs + 1;
         } else if( minusADX > mainADX && plusADX > mainADX && minusADX > plusADX ){
            adxs = adxs - 1;
         } else if( minusADX > mainADX && mainADX > plusADX ){
            adxs = adxs - 2;
         } else {
            adxs = adxs - 3;
         }
      
      }
      val = momentums + stochastics + adxs;
      
      //Comment(StringFormat("Momentums: %G\nStochastics: %G\nADXs: %G\nTOTAL: %G", momentums, stochastics, adxs, val));
      /** /CALCULOS V2 **/
      
      double plusADX12   = iADX(NULL,PERIOD_M5,12,PRICE_WEIGHTED,MODE_PLUSDI,1);
      double minusADX12  = iADX(NULL,PERIOD_M5,12,PRICE_WEIGHTED,MODE_MINUSDI,1);
      double plusADX12B  = iADX(NULL,PERIOD_M5,12,PRICE_WEIGHTED,MODE_PLUSDI,0);
      double minusADX12B = iADX(NULL,PERIOD_M5,12,PRICE_WEIGHTED,MODE_MINUSDI,0);

      double plusADX192  = iADX(NULL,PERIOD_M5,192,PRICE_WEIGHTED,MODE_PLUSDI,1);
      double minusADX192 = iADX(NULL,PERIOD_M5,192,PRICE_WEIGHTED,MODE_MINUSDI,1);
      double plusADX192B  = iADX(NULL,PERIOD_M5,192,PRICE_WEIGHTED,MODE_PLUSDI,0);
      double minusADX192B = iADX(NULL,PERIOD_M5,192,PRICE_WEIGHTED,MODE_MINUSDI,0);
      
      double bigStochMain   = NormalizeDouble( iStochastic(NULL, PERIOD_M5, 192, 192, 192, MODE_LWMA, 1, MODE_MAIN, 0), 1);
      double bigStochSignal = NormalizeDouble( iStochastic(NULL, PERIOD_M5, 192, 192, 192, MODE_LWMA, 1, MODE_SIGNAL, 0), 1);
      
      if(prevCandleClose <= modeLower)
         buy("compra", 0, Lots);
         
      if(prevCandleClose >= modeUpper)
         sell("venta", 0, Lots); 
         
   }
   
   openGrid();    //ABRO GRILLA DE OPERACIONES
   closeOrders(); //CHEQUEO SI TENGO QUE CERRAR LAS ORDENES
   
   OrderSelect(0, SELECT_BY_POS, MODE_TRADES);
   
   Comment(StringFormat("Digits: %G\nAsk: %G\nLast Closed: %G\nTotal abiertas: %G\nProfit (Pts): %G\n", Digits, Ask, getLastClosed(), TotOrdCount(2), getPipProfits( OrderType(), OrderOpenPrice() )));
}

double checkTP(){
   
   //si tengo 2 ordenes abierta
   //veo si la ultima orden esta en ganancia
   
   double pips = 0;
   double lots = 0;
   for(int cnt=0;cnt<OrdersTotal();cnt++) {
      OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES);
      if(OrderType() == OP_BUY )
      {
         if( OrderProfit() > 0 ) {
            pips = pips + ( (Bid - OrderOpenPrice() ) * 100000 ) * ( OrderLots()*100 ) ; 
         } else { 
            pips = pips - ( (OrderOpenPrice() - Bid ) * 100000 ) * ( OrderLots()*100 ) ; 
         }
      }   
      
      if(OrderType() == OP_SELL )
      {
         if( OrderProfit() > 0 )
            pips = pips + ( ( OrderOpenPrice() - Ask ) * 100000 ) * ( OrderLots()*100 ); 
         else
            pips = pips + ( ( OrderOpenPrice() - Ask ) * 100000 ) * ( OrderLots()*100 ); 
      } 
      lots = lots + OrderLots()*100;   
   }
   
   if(lots>0)
      pips = pips / lots;
      
   //if( CheckProfit() > 0 && OrdersTotal() >= 4 ){
   //   closeAllOrders();
   //}
   
   if( ( pips >= TakeProfit) && CheckProfit() > 0 && OrdersTotal() > 1 ){
      closeAllOrders();
   }
   
   return NormalizeDouble( pips, 5 );
}

int getLastTicket(){
   
   datetime lastOpenTime, needleTicket;
   
   for(int i= 0;i<OrdersTotal();i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if( StringFind(OrderComment(), "HEDGE") == -1 ){
         datetime curOpenTime = OrderOpenTime();
      
         if(curOpenTime > lastOpenTime)
         {
            lastOpenTime = curOpenTime;
            needleTicket = OrderTicket();
         }
      }
   }
  
   return needleTicket;
}

int getLastHedgeOpen(){
   
   int openTime  = 0;
   int i = 1;
   string comment = "";
   do
   {
      OrderSelect(OrdersHistoryTotal()-i, SELECT_BY_POS, MODE_HISTORY);
      openTime  = OrderOpenTime();
      comment   = OrderComment();   
      i++;
   }
   
   while( i<=OrdersHistoryTotal() && StringFind(comment,"HEDGE") != -1 );
   return openTime;
}

int getLastHedgeTicket(){
   
   datetime lastOpenTime, needleTicket;
   
   for(int i= 0;i<OrdersTotal();i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if( StringFind(OrderComment(), "HEDGE") != -1 ){
         datetime curOpenTime = OrderOpenTime();
      
         if(curOpenTime > lastOpenTime)
         {
            lastOpenTime = curOpenTime;
            needleTicket = OrderTicket();
         }
      }
   }
  
   return lastOpenTime;
}

bool canOpen( datetime OrderOpenT ){

   if( ( TimeCurrent() - OrderOpenT ) > MinMinutesOpen*60 ) {
      return true;
   } else {
      return false;
   }
}

bool canClose(){

   if( ( TimeCurrent() - OrderOpenTime() ) > MinMinutesClose*60 ) {
      return true;
   } else {
      return false;
   }
}

int getFirstTicket(){

   datetime lastOpenTime, needleTicket;
   
   for(int i= 0;i<OrdersTotal();i++) {

      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      if( StringFind(OrderComment(), "HEDGE") == -1 ){
         datetime curOpenTime = OrderOpenTime();
         
         if(curOpenTime < lastOpenTime)
         {
            lastOpenTime = curOpenTime;
            needleTicket = OrderTicket();
         }
      }
   }
  
   return needleTicket;
  
}




void openHedge( ){

   
   //tengo que ver si la cuenta esta en ganancia y cuantas ordenes abiertas hay
   if(CheckProfit()>0){
   
      //grid para ganancias
   
   } else {

      
      if( TotalOrdersCount() > 0 && TotalOrdersCount() <= MaxGrid ){                  //chequeo si alcance el maximo de operaciones en grid
         if( (TimeCurrent() - getLastClosed()) > MinMinutesClose*60 ){                //chequeo la hora de cierre de la ultima orden
            //selecciono la ultima orden
            OrderSelect(getLastTicket(), SELECT_BY_TICKET, MODE_TRADES);
            double openAt       = OrderOpenPrice();
            double tp           = OrderTakeProfit();
            
            double plusADX12    = iADX(NULL,PERIOD_M5,PrimaryADX,PRICE_WEIGHTED,MODE_PLUSDI,1);
            double minusADX12   = iADX(NULL,PERIOD_M5,PrimaryADX,PRICE_WEIGHTED,MODE_MINUSDI,1);
            double plusADX12B   = iADX(NULL,PERIOD_M5,PrimaryADX,PRICE_WEIGHTED,MODE_PLUSDI,0);
            double minusADX12B  = iADX(NULL,PERIOD_M5,PrimaryADX,PRICE_WEIGHTED,MODE_MINUSDI,0);
            
            double plusADX192   = iADX(NULL,PERIOD_M5,SecondaryADX,PRICE_WEIGHTED,MODE_PLUSDI,1);
            double minusADX192  = iADX(NULL,PERIOD_M5,SecondaryADX,PRICE_WEIGHTED,MODE_MINUSDI,1);
            double plusADX192B  = iADX(NULL,PERIOD_M5,SecondaryADX,PRICE_WEIGHTED,MODE_PLUSDI,0);
            double minusADX192B = iADX(NULL,PERIOD_M5,SecondaryADX,PRICE_WEIGHTED,MODE_MINUSDI,0);
         
            double upperBand    = NormalizeDouble( iBands(NULL, PERIOD_M5, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 1), 5 );
            double lowerBand    = NormalizeDouble( iBands(NULL, PERIOD_M5, 20, 2, 0, PRICE_CLOSE, MODE_MAIN, 1), 5 );
            
            double bigStochMain   = NormalizeDouble( iStochastic(NULL, PERIOD_M5, 192, 192, 192, MODE_LWMA, 1, MODE_MAIN, 0), 1);
            double bigStochSignal = NormalizeDouble( iStochastic(NULL, PERIOD_M5, 192, 192, 192, MODE_LWMA, 1, MODE_SIGNAL, 0), 1);
            
            //Hedge para el grid
            if( canOpen( OrderOpenTime() ) == true ){
               if( OrderProfit() < 0 ){
               
                  if( canOpen( getLastHedgeTicket() ) == true ){
                     
                     double modeUpper       = NormalizeDouble( iBands(NULL, PERIOD_M5, 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 0), 5 );
                     double modeLower       = NormalizeDouble( iBands(NULL, PERIOD_M5, 20, 2, 0, PRICE_CLOSE, MODE_LOWER, 0), 5 );
                     double prevCandleClose = NormalizeDouble( iClose(NULL, PERIOD_M5, 1), 5 );
                     
                     if( OrderType() == OP_BUY ){
                        if(prevCandleClose <= modeLower){                                      //chequeo que no sea un falso rompimiento
                           if( plusADX12 < minusADX12 && plusADX12B < minusADX12B ){           //chequeo los ADX rapidos
                              if( plusADX192 < minusADX192 && plusADX192B < minusADX192B ){    //chequeo los ADX lentos
                                 string comment = StringFormat("HEDGE%G",TotalOrdersCountByType(OP_SELL));
                                 sell( comment, -1, OrderLots() );
                              }
                           }
                        }
                     }
                     
                     if( OrderType() == OP_SELL ){
                        if(prevCandleClose >= modeUpper){                                      //chequeo que no sea un falso rompimiento
                           if( plusADX12 > minusADX12 && plusADX12B > minusADX12B ){           //chequeo los ADX rapidos
                              if( plusADX192 > minusADX192 && plusADX192B > minusADX192B ){    //chequeo los ADX lentos
                                 string comment = StringFormat("HEDGE%G",TotalOrdersCountByType(OP_BUY));
                                 buy( comment, -1, OrderLots() );
                              }
                           }
                        }
                     }
                     
                  }
               }
            }
            
 
         }
      }   
      
   }  
   
}

void checkForClose(){

   if( TotalOrdersCount() > 0 ){
      
      OrderSelect(getLastTicket(), SELECT_BY_TICKET, MODE_TRADES);
      double openAt       = OrderOpenPrice();
      
      double plusADX12    = iADX(NULL,PERIOD_M5,PrimaryADX,PRICE_WEIGHTED,MODE_PLUSDI,1);
      double minusADX12   = iADX(NULL,PERIOD_M5,PrimaryADX,PRICE_WEIGHTED,MODE_MINUSDI,1);
      double plusADX12B   = iADX(NULL,PERIOD_M5,PrimaryADX,PRICE_WEIGHTED,MODE_PLUSDI,0);
      double minusADX12B  = iADX(NULL,PERIOD_M5,PrimaryADX,PRICE_WEIGHTED,MODE_MINUSDI,0);
      
      double plusADX192   = iADX(NULL,PERIOD_M5,SecondaryADX,PRICE_WEIGHTED,MODE_PLUSDI,1);
      double minusADX192  = iADX(NULL,PERIOD_M5,SecondaryADX,PRICE_WEIGHTED,MODE_MINUSDI,1);
      double plusADX192B  = iADX(NULL,PERIOD_M5,SecondaryADX,PRICE_WEIGHTED,MODE_PLUSDI,0);
      double minusADX192B = iADX(NULL,PERIOD_M5,SecondaryADX,PRICE_WEIGHTED,MODE_MINUSDI,0);
      
      double bigStochMain   = NormalizeDouble( iStochastic(NULL, PERIOD_M5, 144, 144, 144, MODE_LWMA, 1, MODE_MAIN, 0), 1);
      double bigStochSignal = NormalizeDouble( iStochastic(NULL, PERIOD_M5, 144, 144, 144, MODE_LWMA, 1, MODE_SIGNAL, 0), 1);
      
      double plusADXD1  = iADX(NULL,PERIOD_D1,MA_SYSTEM_DEFINED,PRICE_WEIGHTED,MODE_PLUSDI,0);
      double minuADXD1  = iADX(NULL,PERIOD_D1,MA_SYSTEM_DEFINED,PRICE_WEIGHTED,MODE_MINUSDI,0);   
      
      if( OrderProfit() > -1 && TotalOrdersCount() > 2 ){
         if( OrderType()==OP_BUY && canClose() == true ){                       //primero chequeo si estoy en compra o ventas
            //if( OrderComment() != "compra_reversal" ){
               if( plusADX12 < minusADX12 && plusADX12B < minusADX12B ){           //chequeo los ADX rapidos
                  if( plusADX192 < minusADX192 && plusADX192B < minusADX192B ){    //chequeo los ADX lentos
                     if( bigStochSignal > bigStochMain ){
                        if( plusADXD1 < minuADXD1 ){
                           OrderClose(OrderTicket(), OrderLots(), Bid,3,Green);
                        }
                     }
                  }
               }
            //} else {
            //   if( OrderProfit() > 0 && ( ( Bid - OrderOpenPrice() ) > ((TakeProfit*Point)/2)) ){
                  //int res = OrderModify( OrderTicket(), OrderOpenPrice(), OrderOpenPrice(), 0, 0, Purple );
                  //if(!res){
                  //}
                     //Print("Error al modificar (2). Error: ",ErrorDescription(GetLastError()));
            //   }
            //}
         }
         
         if( OrderType()==OP_SELL && canClose() == true ){
            if( OrderComment() != "venta_reversal") {
               if( plusADX12 > minusADX12 && plusADX12B > minusADX12B ){              //chequeo los ADX rapidos
                  if( plusADX192 > minusADX192 && plusADX192B > minusADX192B ){    //chequeo los ADX lentos
                     if( bigStochSignal < bigStochMain ){
                        if( plusADXD1 > minuADXD1 ){
                           OrderClose(OrderTicket(), OrderLots(), Ask,3,White);
                        }
                     }
                  }
               }
            } else {
               if( OrderProfit() > 0 && ( (OrderOpenPrice() - Ask) > ((TakeProfit*Point)/2)) ){
                  //int res = OrderModify( OrderTicket(), OrderOpenPrice(), OrderOpenPrice(), 0, 0, Purple );
                  //if(!res)
                     //Print("Error al modificar (2). Error: ",ErrorDescription(GetLastError()));
               }
            }
         }
      }
      
      
      
      
   }
   
}

void closeOrders(){

   //cierro todas las ordenes si alcanza el 1% de la cuenta
   OrderSelect( getLastOrder(1) , SELECT_BY_TICKET, MODE_TRADES);
   
   
   //CIERRO LA ORDENES SI TENGO UNA SOLA ABIERTA Y EN MENOS DE 2 HORAS ALCANZA LOS 150 PUNTOS
   if( TotOrdCount(1)==1){
      if( ( TimeCurrent() - OrderOpenTime() ) < 120*60 ) { //2 horas
         if( getPipProfits(OrderType(), OrderOpenPrice()) > 140 ){
            closeAllOrders();
         }
      }
   }
   
   //CIERRO TODAS LAS ORDENES CUANDO EL PRECIO LLEGUE AL PRECIO PROMEDIO DE APERTURA
   if( TotOrdCount(1) > 1 && CheckProfit() > 0 ){
      if( OrderType()==OP_BUY && Bid < getMiddlePoint(1) ){
         closeAllOrders();
      }
      
      if( OrderType()==OP_SELL && Ask > getMiddlePoint(1) ){
         closeAllOrders();
      }
   }
         

   //CIERRA TODAS LAS ORDENES CUANDO EL PRECIO ALCANCE EL PRECIO DE APERTURA DE LA PRIMERA ORDEN
   if( TotOrdCount(1) > 1 ){
      if( CheckProfit() > 0 ){
      
         OrderSelect(0, SELECT_BY_POS, MODE_TRADES);
         if( OrderType()==OP_BUY && Ask > OrderOpenPrice() )
            closeAllOrders();
         
         if( OrderType()==OP_SELL && Bid < OrderOpenPrice() )   
            closeAllOrders();
      }
   }
    
   //cierro ordenes en ganancia
   if( OrderType()==OP_BUY && canClose() == true ){   
   
      //Pongo el SL en 0 si ya alcanzo el punto de TrailingStop
      if( OrderStopLoss() == 0 ){
         if( OrderProfit() > 0 && ( ( Bid - OrderOpenPrice() ) > TrailingStop*Point )){
            int res = OrderModify( OrderTicket(), OrderOpenPrice(), OrderOpenPrice(), 0, 0, Purple );
            if(!res)
               Print("Error al modificar el TrailingStop 1");
         }
      }
      
      
      if( OrderProfit() > 0 && ( ( Bid - OrderOpenPrice() ) > ((TakeProfit*Point)/2)) ){
         OrderClose(OrderTicket(), OrderLots(), Bid,3,Green);
      }
   }
   
   if( OrderType()==OP_SELL && canClose() == true ){ 
   
      //Pongo el SL en 0 si ya alcanzo el punto de TrailingStop
      if( OrderStopLoss() == 0 ){
         if( OrderProfit() > 0 && ( ( OrderOpenPrice() - Ask ) > TrailingStop*Point )){
            int res = OrderModify( OrderTicket(), OrderOpenPrice(), OrderOpenPrice(), 0, 0, Purple );
            if(!res)
               Print("Error al modificar el TrailingStop 2");
         }
      }
      
      if( OrderProfit() > 0 && ( (OrderOpenPrice() - Ask) > ((TakeProfit*Point)/2)) ){
         OrderClose(OrderTicket(), OrderLots(), Ask,3,White);
      }
   }
}

//para abrir ordenes en grilla
void openGrid(){

   int noHedge = TotOrdCount(2);
   
   
   //necesito saber cuando se abrio la ultima orden no HEDGE 
   if( noHedge >= 1 && noHedge <= MaxGrid){
   
   
      if( canOpen( getLastOpen(2) ) == true ){
      
      
            //busco los valores del hedge para saber su posicion
            OrderSelect(getLastOrder(1), SELECT_BY_TICKET, MODE_TRADES); //BUSCO LA ULTIMA ORDEN ABIERTA PARA SABER EL PRECIO DE APERTURA
            double openAt       = OrderOpenPrice();
            double tp           = OrderTakeProfit();
            
            //tomo los valores de la orden original
            OrderSelect(getLastOrder(2), SELECT_BY_TICKET, MODE_TRADES);
            double modeUpper       = NormalizeDouble( iBands(NULL, PERIOD_M5, 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 0), 5 );
            double modeLower       = NormalizeDouble( iBands(NULL, PERIOD_M5, 20, 2, 0, PRICE_CLOSE, MODE_LOWER, 0), 5 );
            double prevCandleClose = NormalizeDouble( iClose(NULL, PERIOD_M5, 1), 5 );
            
            if( OrderType()==OP_BUY ){                                                //primero chequeo si estoy en compra o ventas
               if( Ask < NormalizeDouble(openAt - MinDistanceGrid*Point,Digits) ){    //chequeo que la distancia minima sea la seteada
                  //if( plusADX12 > minusADX12 && plusADX12B > minusADX12B ){         //chequeo los ADX rapidos
                  //   if( plusADX192 > minusADX192 && plusADX192B > minusADX192B ){  //chequeo los ADX lentos
                        if(prevCandleClose <= modeLower){                             //abro la entrada cuando toque bandas
                           //if( bigStochMain > bigStochSignal ){
                              string comment = StringFormat("GRID%G",noHedge);
                              buy(comment, tp, GridLots*(noHedge+1) );
                           //}
                        }
                     //}
                  //}
               }
            }
            
            if( OrderType()==OP_SELL ){
               if( Bid > NormalizeDouble(openAt + MinDistanceGrid*Point,Digits) ){      //chequeo que la distancia minima sea la seteada
                  //if( plusADX12 < minusADX12 && plusADX12B < minusADX12B ){           //chequeo los ADX rapidos
                     //if( plusADX192 < minusADX192 && plusADX192B < minusADX192B ){    //chequeo los ADX lentos
                        if( prevCandleClose >= modeUpper ){                             //abro la entrada cuando toque bandas
                           //if( bigStochSignal > bigStochMain ){
                              string comment = StringFormat("GRID%G",noHedge);
                              sell(comment, tp, GridLots*(noHedge+1) );
                           //}
                        }
                     //}
                  //}
               }
            }
      }
   }
}


/* HELPER FUNCTIONS */

int getLastOrder( int all ){ //1- all, 2-no hedge, 3-hedge, OBTENGO LA ULTIMA ORDEN ABIERTA
   
   datetime lastOpenTime, needleTicket;
   
   for(int i= 0;i<OrdersTotal();i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      datetime curOpenTime = OrderOpenTime();
      
      if( all==1 ){
         if(curOpenTime > lastOpenTime){
            lastOpenTime = curOpenTime;
            needleTicket = OrderTicket();
         }
      } else if( all == 2 ){
         if( StringFind(OrderComment(), "HEDGE") == -1 ){ 
            if(curOpenTime > lastOpenTime){
               lastOpenTime = curOpenTime;
               needleTicket = OrderTicket();
            } 
         }
      } else {
         if( StringFind(OrderComment(), "HEDGE") != -1 ){ 
            if(curOpenTime > lastOpenTime){
               lastOpenTime = curOpenTime; 
               needleTicket = OrderTicket();
            }
         }
      }
      
   }
  
   return needleTicket;
}

int getFirstOrder( int all ){ //1- all, 2-no hedge, 3-hedge, OBTENGO LA ULTIMA ORDEN ABIERTA
   
   datetime firstOpenTime, needleTicket;
   
   for(int i= 0;i<OrdersTotal();i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      datetime curOpenTime = OrderOpenTime();
      
      if( all==1 ){
         if(curOpenTime < firstOpenTime){
            firstOpenTime = curOpenTime;
            needleTicket = OrderTicket();
         }
      } else if( all == 2 ){
         if( StringFind(OrderComment(), "HEDGE") == -1 ){ 
            if(curOpenTime < firstOpenTime){
               firstOpenTime = curOpenTime;
               needleTicket = OrderTicket();
            } 
         }
      } else {
         if( StringFind(OrderComment(), "HEDGE") != -1 ){ 
            if(curOpenTime < firstOpenTime){
               firstOpenTime = curOpenTime; 
               needleTicket = OrderTicket();
            }
         }
      }
      
   }
  
   return needleTicket;
}

int TotOrdCount( int all ) { //1- all, 2-no hedge, 3-hedge, OBTENGO EL TOTAL DE ORDENES ABIERTAS

  int result     = 0;
  int todayTotal = 0;
  for(int i=0;i<OrdersTotal();i++) {
      OrderSelect(i,SELECT_BY_POS ,MODE_TRADES);
      if (OrderMagicNumber()==MagicNumber)
      {
         if( all==1 ){
            result++;
         } else if( all==2 ){
            if ( StringFind(OrderComment(),"HEDGE") == -1 ) result++;
         } else {
            if ( StringFind(OrderComment(),"HEDGE") != -1 ) result++;
         }
      }
  }
  
  return (result);
}

int getLastOpen( int all ){// 1- all, 2-no hedge, 3-hedge, DEVUELVE LA FECHA Y HORA DE LA ULTIMA APERTURA SIN HEDGE
   
   datetime lastOpenTime, needleTicket;
   
   for(int i= 0;i<OrdersTotal();i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      datetime curOpenTime = OrderOpenTime();
      
      if( all==1 ){ 
         if(curOpenTime > lastOpenTime)
            lastOpenTime = curOpenTime; 
      } else if( all == 2 ){
         if( StringFind(OrderComment(), "HEDGE") == -1 ){ 
            if(curOpenTime > lastOpenTime)
               lastOpenTime = curOpenTime; 
         }
      } else {
         if( StringFind(OrderComment(), "HEDGE") != -1 ){ 
            if(curOpenTime > lastOpenTime)
               lastOpenTime = curOpenTime; 
         }
      }
      
   }
  
   return lastOpenTime;
}


int getFirstOpen( int all ){// 1- all, 2-no hedge, 3-hedge, DEVUELVE LA FECHA Y HORA DE LA ULTIMA APERTURA SIN HEDGE
   
   datetime firstOpenTime, needleTicket;
   
   for(int i= 0;i<OrdersTotal();i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      datetime curOpenTime = OrderOpenTime();
      
      if( all==1 ){ 
         if(curOpenTime < firstOpenTime)
            firstOpenTime = curOpenTime; 
      } else if( all == 2 ){
         if( StringFind(OrderComment(), "HEDGE") == -1 ){ 
            if(curOpenTime < firstOpenTime)
               firstOpenTime = curOpenTime; 
         }
      } else {
         if( StringFind(OrderComment(), "HEDGE") != -1 ){ 
            if(curOpenTime < firstOpenTime)
               firstOpenTime = curOpenTime; 
         }
      }
   }
  
   return firstOpenTime;
}

double getMiddlePoint( int all ){ // 1- all, 2-no hedge, 3-hedge, CALCULO EL PRECIO PROMEDIO DE APERTURA DE LAS ORDENES ABIERTAS

   double averageOpeningPrice = 0;
   int count                  = 0;
   
   for(int i= 0;i<OrdersTotal();i++) {
      OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
      
      if( all==1 ){ 
            averageOpeningPrice = averageOpeningPrice + OrderOpenPrice();
            count++;
      } else if( all == 2 ){
         if( StringFind(OrderComment(), "HEDGE") == -1 ){ 
            averageOpeningPrice = averageOpeningPrice + OrderOpenPrice();
            count++;
         }
      } else {
         if( StringFind(OrderComment(), "HEDGE") != -1 ){ 
            averageOpeningPrice = averageOpeningPrice + OrderOpenPrice();
            count++;
         }
      }
      
   }
   
   return averageOpeningPrice/count;
}

double getPipProfits( int type, double openPrice ){

   double profit = 0;
   
   if( type == OP_BUY ){
      profit = (Bid - openPrice);
   } else {
      profit = (openPrice - Ask);
   }
   
   int pp = profit * getMultiplier();
   
   if(pp > 0)
      return pp;
   else
      return 0; 
}

int getMultiplier(){
   if(Digits==5)
      return 100000;
   else
      return 10000;
}