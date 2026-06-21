//+------------------------------------------------------------------+
//|                           Orion_Hedge.mq5                       |
//|  ORION HEDGE — Grade COMPRA + VENDA Simultaneas (2 Cestos)       |
//|  v3.40 HEDGE — TP Bidirecional | Cooldown | Validacao de Simbolo  |
//+------------------------------------------------------------------+
#property copyright "Orion Logic Elite"
#property version   "3.40"
#property description "Orion Hedge v3.40 — Fix Base Ciclo Desatualizada | Taxa BRL 5.88"

#include <Trade\Trade.mqh>

#import "shell32.dll"
int ShellExecuteW(int hwnd, string lpOperation, string lpFile, string lpParameters, string lpDirectory, int nShowCmd);
#import

//===================================================================
// PALETA DE CORES
//===================================================================
#define PANEL_PREFIX     "OH_"
#define PANEL_W          340
#define CLR_BG_BASE      C'11,13,17'
#define CLR_BG_SECTION   C'16,20,26'
#define CLR_BG_CARD      C'20,25,33'
#define CLR_BG_HEADER    C'8,10,14'
#define CLR_BG_BTN_PANIC C'55,18,18'
#define CLR_LINE_HARD    C'30,38,50'
#define CLR_LINE_SOFT    C'22,28,38'
#define CLR_TXT_PRIMARY  C'230,236,248'
#define CLR_TXT_LABEL    C'108,118,135'
#define CLR_TXT_DIM      C'60,68,80'
#define CLR_TEAL         C'28,170,112'
#define CLR_TEAL_DIM     C'18,80,55'
#define CLR_RED          C'210,68,68'
#define CLR_RED_DIM      C'65,18,18'
#define CLR_AMBER        C'224,155,0'
#define CLR_BLUE         C'52,140,238'
#define CLR_PURPLE       C'140,80,220'

//===================================================================
// INPUTS Ã¢â‚¬â€ MODO HEDGE SOBREVIVENCIA (Resistente a Tendencias)
//===================================================================
input group "=== TIMEFRAMES ==="
input ENUM_TIMEFRAMES InpBaseTF    = PERIOD_H1;
input ENUM_TIMEFRAMES InpTrendTF   = PERIOD_M15;

input group "=== GRADE HEDGE (BALANCEADO) ==="
input double InpLotInitial         = 0.012;  // Lote Base (Reduzido para 0.012 - maior seguranca)
input double InpLotMultiplier      = 1.50;   // Multiplicador Recompra (Forte no sufoco)
input int    InpMaxOrdens          = 5;      // Max Niveis por cesto [Reduzido de 6 para 5 - maior conservadorismo]
input double InpTakeProfitDinheiro = 1.50;   // Alvo por cesto (USC) (Gira rapido e poe no bolso)
input double InpHedgeLotContraFator= 0.25;   // Fator lote cesto CONTRA tendencia [v3.31: 0.20->0.25]
input int    InpZoneCap            = 2;      // [v3.25] Max recompras por zona (0=deslig). Balas extras guardadas para oscilacoes maiores.

input group "=== FILTROS ==="
input int    InpMaxSpread          = 25;     // Spread Max (Pts) [v3.23: 35->25]
input int    InpATRPeriod          = 14;
input int    InpFR_Candles         = 24;
input double InpDist_Base          = 1.2;    // Distancia Grade [v3.24: 1.5->1.2 mais ciclos]
input double InpDistStep           = 0.30;   // Incremento Distancia [v3.23: 0.25->0.30]
input int    InpMinDistancePoints  = 400;    // [v3.29+] Piso minimo de distancia da grade em pts (200->400)
input bool   InpOneTradePerBar     = true;   // [v3.25+] 1 Recompra por barra H1 (evita avalanche)
input double InpAntiSpikeATR       = 2.5;    // Anti-Spike [v3.23: 2.0->2.5 mais protecao]
input bool   InpFiltroRollover     = true;   // Rollover
input double InpRecompra_ATR_Factor= 1.5;    // [v3.28] Fator ATR minimo (1.0->1.5). Mercado lateral: bloqueia.

input group "=== PROTECAO ==="
input double InpSoftStopEquity     = 400.0;  // SoftStop Global (USC) [v3.23: 500->400]
input double InpSoftStopPerCesto   = 0.35;   // SoftStop Cesto: fracao do total [v3.23: 0.50->0.35]
input double InpSwapAlertPct       = 0.5;

input group "=== SETUP ==="
input int    InpMagicNumberBase    = 88800;
input int    InpEmaTrend           = 200;
input int    InpConfirmTimeout     = 20;

input group "=== AUTO-COMPOUNDING ==="
input bool   InpAutoLot            = true;
input double InpBancaRef           = 1000.0;
input double InpLotDeceleration    = 0.90;   // [v3.31] Fator de Desaceleracao (0.90 = Risco Conservador)

input group "=== ADAPTACAO MERCADO PARADO ==="
input bool   InpDynamicTP          = true;   // Ativar TP Dinamico Bidirecional
input double InpDynamicAtrRef      = 150.0;  // ATR Normal (pontos) - referencia central
input double InpDynamicTpFloor     = 0.25;   // Piso do Alvo [v3.24: 0.35->0.25 gira em mercado morto]
input double InpDynamicTpCeiling   = 3.0;    // [v3.24 NOVO] Teto do Alvo (fator max, mercado forte)

input group "=== TRAILING TAKE PROFIT ==="
input bool   InpTrailingHabilitado = true;   // Ativar Perseguidor de Lucro
input double InpTrailingRecuoUsc   = 0.30;   // Recuo Fixo Permitido (USC) [v3.23: 0.40->0.30]
input bool   InpTrailingProtecao   = true;   // Trailing Rigido p/ Niveis Altos

input group "=== COOLDOWN ANTI-CHASING ==="
input bool   InpCooldownHabilitado = true;   // [v3.23 NOVO] Cooldown apos fechar cesto
input int    InpCooldownMinutos    = 20;     // [v3.24: 45->20] Reentrada rapida p/ meta 3%/mes
input bool   InpCooldownApenasContra= true;  // [v3.26] Ignorar cooldown a favor da tendencia

input group "=== RECUPERACAO AVANCADA ==="
input bool   InpAtivarDinBreakEven = true;   // Alt 2: Reduzir alvo para Zero a Zero no sufoco
input int    InpNivelBreakEven     = 5;      // Alt 2: Ativar quando atingir N recompras
input int    InpBreakEvenPips      = 8;      // Alt 2: Pips minimos de lucro ao sair do sufoco (0=comportamento antigo)
input bool   InpAtivarHedgeParcial = true;   // Alt 1: Usar lucro para fechar a pior ordem
input int    InpNivelHedgeParcial  = 5;      // Alt 1: Ativar quando cesto oposto tiver N recompras [v3.27: 4->5]
input double InpFatorLucroHedge    = 0.50;   // Alt 1: Queimar ate 50% do lucro na ordem ruim

input group "=== CICLO DE EQUITY AUTOMÁTICO ==="
input bool   InpAtivarCicloEquity      = true;  // Ativar Ciclo de P. Líquido (Realizado)
input double InpMetaCicloEquityPct     = 5.0;   // Meta de Lucro Líquido Real (%)
input bool   InpAutoResetCiclo         = true;  // Reiniciar Automático (sem pausar EA)
input int    InpCooldownCicloMinutos   = 5;     // Cooldown pós-fechamento (Minutos)

input group "=== PROTECAO ANTI-FACA CAINDO (RECOMPRAS) ==="
input bool            InpAtivarAntiFaca     = true;        // Ativar Gatilho Anti-Faca (Confirmacao)
input ENUM_TIMEFRAMES InpAntiFacaTF         = PERIOD_M5;   // Timeframe de Confirmacao (M1/M5/M15)

input group "=== VISUAL & EXTRAS ==="
input double InpTaxaBRL            = 5.88;   // Cotacao Dolar Estimada (USD/BRL)
input datetime InpFiltroDataInicio = 0;      // [Filtro] Data Inicial (0 = ignorar)
input datetime InpFiltroDataFim    = 0;      // [Filtro] Data Final   (0 = agora)

input group "=== NOTIFICACOES PUSH (CELULAR) ==="
input bool   InpPushAtivo           = true;      // Envio Automatico PUSH (Fim do Dia)
input bool   InpPushFechamento      = true;      // Envio PUSH no Fechamento Total (Trailing Equity)
input string InpTelegramToken       = "";        // Token do Bot do Telegram
input string InpTelegramChatID      = "";        // Chat ID do Telegram

enum ENUM_NEWS_IMPACT {
   NEWS_IMPACT_MEDIUM_HIGH = 0, // Medio e Alto impacto
   NEWS_IMPACT_HIGH_ONLY   = 1  // Apenas Alto impacto
};

input group "=== FILTRO DE NOTICIAS DEFENSIVO ==="
input bool              InpUseNewsFilter         = true;                    // Ativar Filtro de Noticias
input ENUM_NEWS_IMPACT  InpNewsImpact            = NEWS_IMPACT_HIGH_ONLY;   // Impacto Minimo
input int               InpMinBeforeNews         = 30;                      // Minutos antes para pausar
input int               InpMinAfterNews          = 30;                      // Minutos depois para retomar
input bool              InpFreezeNewLevels       = true;                    // Congelar novos niveis da grade?
input bool              InpBreakEvenDuringNews   = true;                    // Alvo em Empate (Breakeven)?
input bool              InpFilterByActivePairs   = true;                    // Filtrar apenas moedas operadas?
input double            InpNewsAtrMultiplier     = 1.4;                     // Multiplicador ATR de Estabilizacao

input group "=== FILTRO TENDENCIA FORTE + NOTICIA (RECOMPRAS) ==="
input bool             InpBloquearRecompraNoticia = true;       // Bloquear novas recompras com noticia ativa
input bool             InpFiltroTendenciaForte    = true;       // Ativar filtro de tendencia forte (ADX)
input ENUM_TIMEFRAMES  InpTendenciaTF             = PERIOD_H1;  // Timeframe para medir forca da tendencia
input int              InpADX_Periodo             = 14;         // Periodo do ADX
input double           InpADX_TrendThreshold      = 30.0;       // ADX acima disso = tendencia forte confirmada

input group "=== INTEGRACAO WEB ORION HEDGE ==="
input bool   InpWebAtiva            = true;      // Ativar envio de dados para o Dashboard Web
input string InpWebUrl              = "https://orion-theta-three.vercel.app/api/mt5/update"; // URL do servidor
input string InpWebApiKey           = "aura_secret_token_123456"; // Token de Seguranca
input int    InpWebIntervalo        = 30;        // Intervalo de envio em segundos

//===================================================================
// VARIAVEIS Ã¢â‚¬â€  DOIS CESTOS SIMULTANEOS
//===================================================================
CTrade   trade;
int      handleATR, handleEMA, handleATR_Long = INVALID_HANDLE;
double   g_ATR_Value, g_EMA_Value;

// Magic Numbers separados por direcao
int      g_MagicBuy;
int      g_MagicSell;

// Lote dinamico
double   g_LoteBase        = 0.01;
double   g_TaxaBRLAtual    = 5.88; // [v3.40] Taxa BRL atualizada de forma dinamica pelo par USDBRL
double   g_TakeProfitBase  = 0;
double   g_TakeProfitAtual = 0;
double   g_SoftStopAtual   = 0;
double   g_SoftStopPorCesto= 0;   // SoftStop individual de cada cesto
double   g_BuyLoteInicial  = 0;   // [FIX #11] Lote inicial do cesto Buy
double   g_SellLoteInicial = 0;   // [FIX #11] Lote inicial do cesto Sell
double   g_BuyTPEfetivo    = 0;   // [v3.26] TP efetivo do cesto Buy (pode ser BE proporcional)
double   g_SellTPEfetivo   = 0;   // [v3.26] TP efetivo do cesto Sell

// Trailing TP
bool     g_BuyEmTrailing   = false;
double   g_BuyLucroMaximo  = 0;
bool     g_SellEmTrailing  = false;
double   g_SellLucroMaximo = 0;

// Filtro de noticias
bool     g_NewsActive      = false;
bool     g_NewsFrozen      = false;
string   g_NewsName        = "";

// Cooldown anti-chasing [v3.23]
datetime g_BuyCooldownEnd  = 0;
datetime g_SellCooldownEnd = 0;



// Estado do Trailing de Patrimonio (Mantido para compatibilidade com Dashboard Web)
bool     g_DD_Reached10        = false;  // Indica se o DD bateu 10% (Amarelo)
bool     g_DD_Reached20        = false;  // Indica se o DD bateu 20% (Vermelho)
bool     g_TrailingActive      = false;  // Indica se o trailing está ativo no ciclo atual
double   g_PeakProfit          = -999.0; // Pico de lucro alcançado no trailing

// Estado do Ciclo de Equity Automático
double   g_EquityCycleBaseBalance = -1.0;   // Saldo de referÃªncia inicial do ciclo
datetime g_EquityCycleCooldownEnd = 0;      // Fim do perÃ­odo de cooldown do ciclo

// === CONTROLE DE COMANDOS EXECUTADOS ===
int      g_ExecCmdIds[];
int      g_ExecCmdCount    = 0;

// === CESTO COMPRA ===
int      g_BuyTotal        = 0;
int      g_BuyNivelAtual   = 0;   // [BUG #4 FIX] Nivel atual baseado no maior indice das ordens
double   g_BuyPrecoMedio   = 0;
double   g_BuyVolume       = 0;
double   g_BuyLucro        = 0;
double   g_BuySwap         = 0;
double   g_BuyAlvo         = 0;
double   g_BuyExtremo      = 0;
double   g_BuyProxFR       = 0;
double   g_BuyDistFalt     = 0;
double   g_BuyProxPreco    = 0;   // [v3.24+] Preco alvo da proxima recompra Buy
string   g_BuyTfAlvo       = "";
double   g_BuyZoneOrigin   = 0;   // [v3.25] Preco de abertura N1 do cesto Buy (origem da zona)
datetime g_BuyLastBarTime  = 0;   // [v3.25+] Controle de 1 recompra por candle
bool     g_AguardandoBuy   = false;
datetime g_ConfirmBuy      = 0;

// === CESTO VENDA ===
int      g_SellTotal       = 0;
int      g_SellNivelAtual  = 0;   // [BUG #4 FIX] Nivel atual baseado no maior indice das ordens
double   g_SellPrecoMedio  = 0;
double   g_SellVolume      = 0;
double   g_SellLucro       = 0;
double   g_SellSwap        = 0;
double   g_SellAlvo        = 0;
double   g_SellExtremo     = 0;
double   g_SellProxFR      = 0;
double   g_SellDistFalt    = 0;
double   g_SellProxPreco   = 0;   // [v3.24+] Preco alvo da proxima recompra Sell
string   g_SellTfAlvo      = "";
double   g_SellZoneOrigin  = 0;   // [v3.25] Preco de abertura N1 do cesto Sell (origem da zona)
datetime g_SellLastBarTime = 0;   // [v3.25+] Controle de 1 recompra por candle
bool     g_AguardandoSell  = false;
datetime g_ConfirmSell     = 0;

// === FILTRO TENDENCIA FORTE + NOTICIA (ADX/NEWS) ===
int      handleADXTrend  = INVALID_HANDLE;
double   g_ADX_Trend     = 0;
double   g_DIPlus_Trend  = 0;
double   g_DIMinus_Trend = 0;

// === SAÍDA ZERO A ZERO (GRADE) ===
bool     g_BuySaidaZeroAtiva  = false;
bool     g_SellSaidaZeroAtiva = false;

// === WIDGET DE STATUS (CANTO SUPERIOR DIREITO) ===
datetime g_LastTickTime       = 0;
int      g_AnaliseLegendHeight = 0;
int      g_StatusWidgetHeight  = 58;

// === MINI PAINEL S.O.S (CALCULO DE RESGATE) ===
bool     g_SOSPanelBuyAberto   = false;
bool     g_SOSPanelSellAberto  = false;
int      g_SOSPanelBuyHeight   = 160;
int      g_SOSPanelSellHeight  = 160;

bool     g_SOSForceBuyAguardando = false;
datetime g_SOSForceBuyTimestamp = 0;
bool     g_SOSForceSellAguardando = false;
datetime g_SOSForceSellTimestamp = 0;


void SetBuySaidaZeroAtiva(bool val) {
   g_BuySaidaZeroAtiva = val;
   GlobalVariableSet("OrionHedge_SOS_BuyAtiva_" + _Symbol, val ? 1.0 : 0.0);
}

void SetSellSaidaZeroAtiva(bool val) {
   g_SellSaidaZeroAtiva = val;
   GlobalVariableSet("OrionHedge_SOS_SellAtiva_" + _Symbol, val ? 1.0 : 0.0);
}

// Historico
int      g_DealsCountCache = -1;
// [BUG #6 FIX] Variaveis removidas Ã¢â‚¬â€ nao sao usadas em nenhum calculo
// double   g_HistLucroBuy = 0, g_HistLucroSell = 0;
// double   g_HistSwap     = 0;
double   g_HistLucroGlobal = 0;
double   g_HistLucroSymbol = 0;
double   g_HistLucroHoje = 0;
datetime g_LastPushSentDate = 0;
int      g_HistSimbolosCount = 0;
string   g_HistSimbolos[];
datetime g_InicioHistorico = 0;
datetime g_InicioHistoricoSymbol = 0;
int      g_FiltroHistorico = 0; // 0=Tudo, 1=7D, 2=30D, 3=MesAtual, 4=Personalizado
datetime g_FiltroDataIni  = 0; // Data inicial do filtro CUST (escolha rapida)
datetime g_FiltroDataFim  = 0; // Data final do filtro CUST (0=agora)
// [v3.32 FIX] Rastreia estado anterior do filtro para detectar mudanca e invalidar cache
int      g_FiltroHashAnterior    = -999;
datetime g_FiltroDataIniAnterior = 0;
datetime g_FiltroDataFimAnterior = 0;


// Rentabilidade Mensal (Removido g_BalanceMesInicio e g_MesAtual nao utilizados - BUG #10 FIX)

// Relatorio de Lucro Diario
datetime g_RepDataIni       = 0;
datetime g_RepDataFim       = 0;

struct SDiarioLucro {
   datetime data;
   double   lucro;
   double   volume;
   int      transacoes;
};

// FR
double   g_FR_H1_Sup=0,  g_FR_H1_Res=0;
double   g_FR_H4_Sup=0,  g_FR_H4_Res=0;
double   g_FR_H12_Sup=0, g_FR_H12_Res=0;  // [v3.27] Ponte H4->D1 para N4
double   g_FR_D1_Sup=0,  g_FR_D1_Res=0;
double   g_FR_W1_Sup=0,  g_FR_W1_Res=0;

// GUI
bool     g_BotPaused        = false;
bool     g_Minimized        = false;
bool     g_MinimizedCleaned = false;
bool     g_ShowLog          = true;
bool     g_ShowSettings     = false;
bool     g_LastShowSettings = false;
int      g_LinhasModo           = 0;
int      g_PreAnaliseLinhasModo = 0;  // [BUG-M2 FIX] Salva preferencia do usuario antes do modo analise
int      g_PanelHeight      = 600;
string   g_Log[6]           = {"Hedge Test Mode Ativo!", "---","---","---","---","---"};
bool     g_PanicoAguardando = false;
datetime g_PanicoTimestamp  = 0;
bool     g_PanicoLocalAguardando = false;
datetime g_PanicoLocalTimestamp  = 0;
bool     g_PanelInited       = false;  // [v3.24] Flag para limpar ghosts no 1o frame
bool     g_SoftStopAtivo    = false;
datetime g_SoftStopLogTime  = 0;
datetime g_SensorBarTime    = 0;
// [BUG-M4 FIX] Variaveis mortas removidas: g_CooldownAtivo, g_CooldownInicioTime

// [v3.29] Controle de fase de Drawdown para alertas nao-repetitivos
// Fase 0 = verde, 1 = amarelo (aviso), 2 = vermelho (critico)
int      g_DD_FaseAtual     = 0;  // Fase atual da barra de Drawdown %
int      g_SS_FaseAtual     = 0;  // Fase atual da barra SoftStop %

// === MODO ANÁLISE DE MERCADO (default OFF) ===
bool     g_ModoAnalise       = false;
int      g_AnaHandleADX      = INVALID_HANDLE;
int      g_AnaHandleRSI      = INVALID_HANDLE;
int      g_AnaHandleMACD     = INVALID_HANDLE;
int      g_AnaHandleStoch    = INVALID_HANDLE;
int      g_AnaHandleEMA50    = INVALID_HANDLE;
int      g_AnaHandleBB       = INVALID_HANDLE;
int      g_AnaHandleADX_D1   = INVALID_HANDLE;
int      g_AnaHandleRSI_D1   = INVALID_HANDLE;
int      g_AnaHandleEMA200D1 = INVALID_HANDLE;
// Cache de valores (atualizados no OnTimer)
double   g_Ana_ADX           = 0;
double   g_Ana_ADX_D1        = 0;
double   g_Ana_RSI           = 0;
double   g_Ana_RSI_D1        = 0;
double   g_Ana_MACD_Main     = 0;
double   g_Ana_MACD_Signal   = 0;
double   g_Ana_Stoch         = 0;
double   g_Ana_EMA50         = 0;
double   g_Ana_EMA200_D1     = 0;
double   g_Ana_BB_Upper      = 0;
double   g_Ana_BB_Lower      = 0;
double   g_Ana_BB_Middle     = 0;
int      g_Ana_Score         = 0;
ENUM_TIMEFRAMES g_Ana_TF     = PERIOD_CURRENT;

void LimparPainel();
void DesenharPainel();
void DesenharPainelSOS(bool isBuyRescue, int x, int y, int &outHeight);
void DesenharLinhas();
void LimparLinhasAnalise();
void DesenharLinhasAnalise();
void DesenharLegendaAnalise(int count, string &texts[], color &clrs[], string diag_text="", color diag_color=clrNONE);  // [BUG-C3 FIX] Forward declaration adicionada

datetime NormalizarDia(datetime dt) {
   MqlDateTime md;
   TimeToStruct(dt, md);
   md.hour = 0; md.min = 0; md.sec = 0;
   return StructToTime(md);
}

// ===== PERSISTENCIA FISICA DE RESET TIME (BLINDAGEM CONTRA QUEDAS) =====
void GuardarResetTime(string symbol, datetime dt) {
   string fileName = "orion_reset_" + symbol + ".txt";
   int handle = FileOpen(fileName, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle != INVALID_HANDLE) {
      FileWriteString(handle, TimeToString(dt, TIME_DATE|TIME_MINUTES|TIME_SECONDS));
      FileClose(handle);
   }
}

datetime LerResetTime(string symbol) {
   string fileName = "orion_reset_" + symbol + ".txt";
   datetime dt = 0;
   int handle = FileOpen(fileName, FILE_READ|FILE_TXT|FILE_ANSI);
   if(handle != INVALID_HANDLE) {
      string s = FileReadString(handle);
      dt = StringToTime(s);
      FileClose(handle);
   }
   return dt;
}

// ===================================================================
// VERIFICAR COMANDO LOCAL
// ===================================================================
bool VerificarComandoLocal(string resp, string comando, string simbolo) {
   string searchCmd = "\"command\":\"" + comando + "\"";
   string searchSym = "\"symbol\":\"" + simbolo + "\"";
   int startPos = 0;
   
   while(true) {
      int posCmd = StringFind(resp, searchCmd, startPos);
      if(posCmd < 0) break;
      
      int posClose = StringFind(resp, "}", posCmd);
      if(posClose < 0) break;
      
      string block = StringSubstr(resp, posCmd, posClose - posCmd);
      if(StringFind(block, searchSym) >= 0) {
         return true; // Encontrou um comando correspondente a este simbolo!
      }
      
      startPos = posClose + 1; // Avanca para procurar o proximo
   }
   return false;
}

//===================================================================
// UTILIDADES
//===================================================================
void AddLog(string msg) {
   for(int i=5;i>0;i--) g_Log[i]=g_Log[i-1];
   g_Log[0] = TimeToString(TimeCurrent(),TIME_SECONDS)+" "+msg;
   Print(msg);
}

void AtualizarLoteBase() {
   if(!InpAutoLot||InpBancaRef<=0||InpLotInitial<=0) {
      g_LoteBase=InpLotInitial; g_TakeProfitBase=InpTakeProfitDinheiro; g_TakeProfitAtual=InpTakeProfitDinheiro;
      g_SoftStopAtual=InpSoftStopEquity;
      g_SoftStopPorCesto=InpSoftStopEquity*InpSoftStopPerCesto;
      return;
   }
   double bal  = AccountInfoDouble(ACCOUNT_BALANCE);
   double step = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double minV = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxV = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   
   // Prevenção de divisão por zero caso o broker retorne dados vazios/inválidos
   if(step <= 0) step = 0.01;
   if(minV <= 0) minV = 0.01;
   if(maxV <= 0) maxV = 500.0;
   
   // [v3.30] Juros Compostos Sub-Lineares (Desaceleracao do Lote e Risco)
   double ratio = bal / InpBancaRef;
   if(ratio > 1.0 && InpLotDeceleration > 0.0 && InpLotDeceleration < 1.0) {
      ratio = MathPow(ratio, InpLotDeceleration);
   }
   double raw  = InpLotInitial * ratio;
   
   g_LoteBase  = MathMax(minV,MathFloor(raw/step)*step);
   if(g_LoteBase>maxV) g_LoteBase=maxV;
   double fat  = g_LoteBase/0.01;
   g_TakeProfitBase   = InpTakeProfitDinheiro*fat;   // [FIX #1] Usa valor configurado
   g_TakeProfitAtual  = g_TakeProfitBase;
   g_SoftStopAtual    = InpSoftStopEquity*fat;        // [FIX #1] Usa valor configurado
   g_SoftStopPorCesto = g_SoftStopAtual*InpSoftStopPerCesto;
}

void AtualizarLucroHoje() {
   datetime agora = TimeCurrent();
   MqlDateTime md;
   TimeToStruct(agora, md);
   md.hour = 0; md.min = 0; md.sec = 0;
   datetime inicioDia = StructToTime(md);

   datetime selectStart = MathMax(inicioDia, g_InicioHistorico);
   HistorySelect(selectStart, agora);
   int total = HistoryDealsTotal();
   g_HistLucroHoje = 0;
   for(int i = 0; i < total; i++) {
      ulong t = HistoryDealGetTicket(i);
      long type = HistoryDealGetInteger(t, DEAL_TYPE);
      if(type == DEAL_TYPE_BUY || type == DEAL_TYPE_SELL) {
         long dealMagic = HistoryDealGetInteger(t, DEAL_MAGIC);
         datetime dt = (datetime)HistoryDealGetInteger(t, DEAL_TIME);
         
         bool isOrionDeal = false;
         if(dealMagic >= InpMagicNumberBase && dealMagic <= InpMagicNumberBase + 999999) {
            isOrionDeal = true;
         } else if(dealMagic == 0 && dt >= g_InicioHistorico && HistoryDealGetString(t, DEAL_SYMBOL) == _Symbol) {
            isOrionDeal = true;
         }
         
         if(isOrionDeal) {
            double p   = HistoryDealGetDouble(t, DEAL_PROFIT);
            double sw  = HistoryDealGetDouble(t, DEAL_SWAP);
            double com = HistoryDealGetDouble(t, DEAL_COMMISSION);
            g_HistLucroHoje += p + sw + com;
         }
      }
   }
}

void AtualizarHistoricoGlobal() {
   datetime dtStart = g_InicioHistorico;
   datetime dtEnd   = TimeCurrent();
   if(g_FiltroHistorico == 1)      dtStart = TimeCurrent() - 7*86400;
   else if(g_FiltroHistorico == 2) dtStart = TimeCurrent() - 30*86400;
   else if(g_FiltroHistorico == 3) {
      MqlDateTime md; TimeToStruct(TimeCurrent(), md);
      md.day=1; md.hour=0; md.min=0; md.sec=0;
      dtStart = StructToTime(md);
   }
   else if(g_FiltroHistorico == 4) {
      // [v3.31 FIX] Desacoplamento: dtStart e dtEnd verificados independentemente
      if(g_FiltroDataIni > 0)          dtStart = g_FiltroDataIni;
      else if(InpFiltroDataInicio > 0) dtStart = InpFiltroDataInicio;

      if(g_FiltroDataFim > 0)          dtEnd = g_FiltroDataFim;
      else if(InpFiltroDataFim > 0)    dtEnd = InpFiltroDataFim;
   }

   // [v3.32 FIX] Detecta QUALQUER mudanca no filtro e invalida cache antes de comparar totais.
   // Antes: apenas o modo CUST forcava -1. Agora: qualquer troca de modo OU data tambem forca.
   // Isso evita falso cache-hit quando dois periodos diferentes tem o mesmo numero de deals.
   bool filtroMudou = (g_FiltroHistorico != g_FiltroHashAnterior ||
                       g_FiltroDataIni   != g_FiltroDataIniAnterior ||
                       g_FiltroDataFim   != g_FiltroDataFimAnterior);
   if(filtroMudou) {
      g_DealsCountCache        = -1;
      g_FiltroHashAnterior    = g_FiltroHistorico;
      g_FiltroDataIniAnterior = g_FiltroDataIni;
      g_FiltroDataFimAnterior = g_FiltroDataFim;
   }

   datetime dtStartGlobal = MathMax(dtStart, g_InicioHistorico);
   datetime dtStartSymbol = MathMax(dtStart, g_InicioHistoricoSymbol);
   datetime dtStartQuery = MathMin(dtStartGlobal, dtStartSymbol);

   HistorySelect(dtStartQuery, dtEnd);
   int total = HistoryDealsTotal();
   
   // BUG #3 FIX: AtualizarLucroHoje() tem seu proprio HistorySelect interno.
   // Deve ser chamada ANTES do cache-hit return para garantir que g_HistLucroHoje
   // nunca fique desatualizado, mesmo quando o total de deals nao mudou.
   AtualizarLucroHoje();
   // Restaura a selecao do historico principal apos AtualizarLucroHoje
   HistorySelect(dtStartQuery, dtEnd);

   if(total == g_DealsCountCache) return; // Early return seguro: LucroHoje ja atualizado
   g_DealsCountCache = total;
   g_HistLucroGlobal = 0;
   g_HistLucroSymbol = 0;
   g_HistSimbolosCount = 0;
   ArrayFree(g_HistSimbolos);
   for(int i = 0; i < total; i++) {
      ulong t = HistoryDealGetTicket(i);
      long type = HistoryDealGetInteger(t, DEAL_TYPE);
      if(type == DEAL_TYPE_BUY || type == DEAL_TYPE_SELL) {
         double p   = HistoryDealGetDouble(t, DEAL_PROFIT);
         double sw  = HistoryDealGetDouble(t, DEAL_SWAP);
         double com = HistoryDealGetDouble(t, DEAL_COMMISSION);
         double amt = p + sw + com;
         datetime dealTime = (datetime)HistoryDealGetInteger(t, DEAL_TIME);
         
         if(dealTime >= dtStartGlobal) {
            g_HistLucroGlobal += amt; // Conta TODAS as moedas (Account PL)
            
            // [ADD] Conta moedas globais operadas
            string sym = HistoryDealGetString(t, DEAL_SYMBOL);
            if(StringLen(sym) > 0) {
               bool found = false;
               for(int j=0; j<g_HistSimbolosCount; j++) {
                  if(g_HistSimbolos[j] == sym) { found = true; break; }
               }
               if(!found) {
                  ArrayResize(g_HistSimbolos, g_HistSimbolosCount+1);
                  g_HistSimbolos[g_HistSimbolosCount] = sym;
                  g_HistSimbolosCount++;
               }
            }
         }
         
         if(dealTime >= dtStartSymbol) {
            long dealMagic = HistoryDealGetInteger(t, DEAL_MAGIC);
            bool isSymbolDeal = false;
            if(dealTime >= g_InicioHistoricoSymbol) {
               isSymbolDeal = (HistoryDealGetString(t, DEAL_SYMBOL) == _Symbol &&
                               (dealMagic == 0 || (dealMagic >= InpMagicNumberBase && dealMagic <= InpMagicNumberBase + 999999)));
            } else {
               isSymbolDeal = (HistoryDealGetString(t, DEAL_SYMBOL) == _Symbol &&
                               (dealMagic == g_MagicBuy || dealMagic == g_MagicSell));
            }
            if(isSymbolDeal) {
               g_HistLucroSymbol += amt;
            }
         }
      }
   }
}

double CalcularPrecoAlvo(double precoMedio, double volume, double swapTotal, bool isBuy, double tpEfetivo) {
   double tickV = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tickS = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tickV<=0||tickS<=0||volume<=0) return 0;
   double spr   = (double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)*_Point/tickS*tickV*volume;
   double req   = tpEfetivo - swapTotal + spr;
   double dist  = (req/(volume*tickV))*tickS;
   return isBuy ? (precoMedio+dist) : (precoMedio-dist);
}

//===================================================================
// ATUALIZAR CESTOS
//===================================================================
void AtualizarCestoBuy() {
   g_BuyTotal=0; g_BuyPrecoMedio=0; g_BuyVolume=0; g_BuyLucro=0; g_BuySwap=0; g_BuyExtremo=0; g_BuyAlvo=0; g_BuyProxPreco=0; g_BuyDistFalt=0; g_BuyProxFR=0; g_BuyTfAlvo="";  // [FIX #8][BUG #5]
   double somaFin=0;
   datetime firstTime=0; double firstLot=0;
   double maxPrice=0; // [BUG-A1 FIX] captura N1 (maior preco) no mesmo loop
   int maxLvl = 0;
   for(int i=PositionsTotal()-1;i>=0;i--) {
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_MagicBuy) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE)!=POSITION_TYPE_BUY) continue;
      double p=PositionGetDouble(POSITION_PRICE_OPEN);
      double v=PositionGetDouble(POSITION_VOLUME);
      datetime posTime=(datetime)PositionGetInteger(POSITION_TIME);
      if(firstTime==0 || posTime<firstTime) { firstTime=posTime; firstLot=v; }
      somaFin+=p*v; g_BuyVolume+=v;
      g_BuyLucro+=PositionGetDouble(POSITION_PROFIT);
      g_BuySwap+=PositionGetDouble(POSITION_SWAP);
      g_BuyTotal++;
      if(g_BuyExtremo==0||p<g_BuyExtremo) g_BuyExtremo=p;  // menor preco (mais negativo)
      if(p>maxPrice) maxPrice=p;                             // maior preco (N1 original)
      
      // Parse level from comment to prevent drift (BUG #4 FIX)
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringSubstr(comment, 0, 4) == "OH_B") {
         int lvl = (int)StringToInteger(StringSubstr(comment, 4));
         if(lvl > maxLvl) maxLvl = lvl;
      }
   }
   g_BuyNivelAtual = (maxLvl > 0) ? maxLvl : g_BuyTotal;
   // [BUG-A3 FIX] Reset loteInicial quando cesto vazio
   if(g_BuyTotal==0) { g_BuyLoteInicial=0; }
   else if(firstLot>0) g_BuyLoteInicial = firstLot;
   if(g_BuyVolume>0) {
      g_BuyPrecoMedio=somaFin/g_BuyVolume;
      
      // [v3.26] Calcula TP efetivo por cesto ANTES do alvo visual/real
      double tpDinBuy = g_TakeProfitAtual;
      double tpBasBuy = g_TakeProfitBase;
      if(g_BuyLoteInicial > 0 && g_LoteBase > 0) {
         tpDinBuy = g_TakeProfitAtual * (g_BuyLoteInicial / g_LoteBase);
         tpBasBuy = g_TakeProfitBase  * (g_BuyLoteInicial / g_LoteBase);
      }
      g_BuyTPEfetivo = tpDinBuy;
      
      // Se filtro de noticia ativo e breakeven ativado, reduz o TP para empate (lucro simbolico de 10% do TP Base)
      if(g_NewsActive && InpBreakEvenDuringNews) {
         g_BuyTPEfetivo = MathMax(tpBasBuy * 0.10, 0.50);
         static datetime logBreakNewsB = 0;
         if(TimeCurrent() - logBreakNewsB > 60) {
            logBreakNewsB = TimeCurrent();
            AddLog("[BUY NOTICIA] Alvo em BreakEven Protetor: "+DoubleToString(g_BuyTPEfetivo,2)+" (Noticia: "+g_NewsName+")");
         }
      }
      else if(InpAtivarDinBreakEven && g_BuyTotal >= InpNivelBreakEven) {
         if(g_DD_FaseAtual > 0) {
            // [EMERGENCIA] Corta a ambicao. Sai no 0x0 com lucro simbolico (10% do TP Base)
            g_BuyTPEfetivo = MathMax(tpBasBuy * 0.10, 0.50);
            static datetime logBreakB = 0;
            if(TimeCurrent() - logBreakB > 60) {
               logBreakB = TimeCurrent();
               AddLog("[BUY S.O.S] BreakEven ATIVO N"+IntegerToString(g_BuyTotal)+" (DD > 10%). TP Reduzido: "+DoubleToString(g_BuyTPEfetivo,2));
            }
         } else {
            // [INTELIGENCIA] Mantem o TP cheio porque o mar esta tranquilo
            static datetime logBreakBOk = 0;
            if(TimeCurrent() - logBreakBOk > 600) {
               logBreakBOk = TimeCurrent();
               AddLog("[BUY] Nivel "+IntegerToString(g_BuyTotal)+" atingido, mas DD Seguro (<10%). Mantendo TP normal.");
            }
         }
      }
      
      g_BuyAlvo=CalcularPrecoAlvo(g_BuyPrecoMedio,g_BuyVolume,g_BuySwap,true,g_BuyTPEfetivo);
   } else {
      g_BuyTPEfetivo = 0;
   }
   // [v3.25][BUG-A1 FIX] Rastreia origem da zona (N1 = maior preco de entrada Buy)
   // [BUG-M1 FIX] Recalcula SEMPRE a partir do maxPrice atual (evita travar com fechamento parcial manual)
   if(g_BuyTotal==0) g_BuyZoneOrigin=0;
   else if(maxPrice > 0) g_BuyZoneOrigin = maxPrice;
   
   // PREDICT PARA O PAINEL
   g_BuyProxPreco=0; g_BuyDistFalt=0; g_BuyProxFR=0; g_BuyTfAlvo="";
   if(g_BuyNivelAtual>0 && g_BuyNivelAtual<InpMaxOrdens) {
      double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double dist=MathAbs(g_BuyExtremo-bid);
      int nivel=g_BuyNivelAtual+1;
      double mult=MathMax(InpDist_Base,InpDist_Base+(nivel-2)*InpDistStep);
      double distMinima = MathMax(g_ATR_Value*mult, InpMinDistancePoints * _Point);
      g_BuyDistFalt = MathMax(0,distMinima-dist);

      double supFR=0; g_BuyTfAlvo="DISTANCIA";
      // double v_h1=(g_FR_H1_Sup>0&&g_FR_H1_Sup<g_BuyExtremo)?g_FR_H1_Sup:0;
      double v_h4 =(g_FR_H4_Sup >0&&g_FR_H4_Sup <g_BuyExtremo)?g_FR_H4_Sup :0;
      double v_h12=(g_FR_H12_Sup>0&&g_FR_H12_Sup<g_BuyExtremo)?g_FR_H12_Sup:0;  // [v3.27]
      double v_d1 =(g_FR_D1_Sup >0&&g_FR_D1_Sup <g_BuyExtremo)?g_FR_D1_Sup :0;
      // double v_w1=(g_FR_W1_Sup>0&&g_FR_W1_Sup<g_BuyExtremo)?g_FR_W1_Sup:0;
      if(nivel<=3 &&v_h4 >0){supFR=v_h4; g_BuyTfAlvo="H4 FR";}  // N2, N3 -> H4
      else if(nivel==4&&v_h12>0){supFR=v_h12;g_BuyTfAlvo="H12 FR";} // N4  -> H12 (ponte)
      else if(v_d1 >0){supFR=v_d1; g_BuyTfAlvo="D1 FR";}  // N5, N6 -> D1 (Sweet-Spot)
      g_BuyProxFR=supFR;
      g_BuyProxPreco = (supFR > 0) ? supFR : MathMax(0, g_BuyExtremo - distMinima);

      if(InpZoneCap>0 && g_BuyNivelAtual>=InpZoneCap && g_BuyZoneOrigin>0) {
         // [BUG-M1 FIX] zona_min escala por nivel para protecao crescente em grades avancadas
         double totalDist = MathAbs(g_BuyZoneOrigin - bid);
         double zona_min  = nivel * InpDist_Base * g_ATR_Value;  // antes: InpZoneCap (fixo)
         if(totalDist < zona_min) {
            double dif = zona_min - totalDist;
            if(dif > g_BuyDistFalt) {
                g_BuyDistFalt = dif;
                g_BuyTfAlvo = "ZONE CAP";
                g_BuyProxPreco = g_BuyZoneOrigin - zona_min;
            }
         }
      }
   }
}

void AtualizarCestoSell() {
   g_SellTotal=0; g_SellPrecoMedio=0; g_SellVolume=0; g_SellLucro=0; g_SellSwap=0; g_SellExtremo=0; g_SellAlvo=0; g_SellProxPreco=0; g_SellDistFalt=0; g_SellProxFR=0; g_SellTfAlvo="";  // [FIX #8][BUG #5]
   double somaFin=0;
   datetime firstTime=0; double firstLot=0;
   double minPrice=0; // [BUG-A1 FIX] captura N1 (menor preco) no mesmo loop
   int maxLvl = 0;
   for(int i=PositionsTotal()-1;i>=0;i--) {
      ulong t=PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=g_MagicSell) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE)!=POSITION_TYPE_SELL) continue;
      double p=PositionGetDouble(POSITION_PRICE_OPEN);
      double v=PositionGetDouble(POSITION_VOLUME);
      datetime posTime=(datetime)PositionGetInteger(POSITION_TIME);
      if(firstTime==0 || posTime<firstTime) { firstTime=posTime; firstLot=v; }
      somaFin+=p*v; g_SellVolume+=v;
      g_SellLucro+=PositionGetDouble(POSITION_PROFIT);
      g_SellSwap+=PositionGetDouble(POSITION_SWAP);
      g_SellTotal++;
      if(g_SellExtremo==0||p>g_SellExtremo) g_SellExtremo=p;  // maior preco (mais negativo)
      if(minPrice==0||p<minPrice) minPrice=p;                   // menor preco (N1 original)
      
      // Parse level from comment to prevent drift (BUG #4 FIX)
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringSubstr(comment, 0, 4) == "OH_S") {
         int lvl = (int)StringToInteger(StringSubstr(comment, 4));
         if(lvl > maxLvl) maxLvl = lvl;
      }
   }
   g_SellNivelAtual = (maxLvl > 0) ? maxLvl : g_SellTotal;
   // [BUG-A3 FIX] Reset loteInicial quando cesto vazio
   if(g_SellTotal==0) { g_SellLoteInicial=0; }
   else if(firstLot>0) g_SellLoteInicial = firstLot;
   if(g_SellVolume>0) {
      g_SellPrecoMedio=somaFin/g_SellVolume;
      
      // [v3.26] Calcula TP efetivo por cesto ANTES do alvo visual/real
      double tpDinSell = g_TakeProfitAtual;
      double tpBasSell = g_TakeProfitBase;
      if(g_SellLoteInicial > 0 && g_LoteBase > 0) {
         tpDinSell = g_TakeProfitAtual * (g_SellLoteInicial / g_LoteBase);
         tpBasSell = g_TakeProfitBase  * (g_SellLoteInicial / g_LoteBase);
      }
      g_SellTPEfetivo = tpDinSell;
      
      // Se filtro de noticia ativo e breakeven ativado, reduz o TP para empate (lucro simbolico de 10% do TP Base)
      if(g_NewsActive && InpBreakEvenDuringNews) {
         g_SellTPEfetivo = MathMax(tpBasSell * 0.10, 0.50);
         static datetime logBreakNewsS = 0;
         if(TimeCurrent() - logBreakNewsS > 60) {
            logBreakNewsS = TimeCurrent();
            AddLog("[SELL NOTICIA] Alvo em BreakEven Protetor: "+DoubleToString(g_SellTPEfetivo,2)+" (Noticia: "+g_NewsName+")");
         }
      }
      else if(InpAtivarDinBreakEven && g_SellTotal >= InpNivelBreakEven) {
         if(g_DD_FaseAtual > 0) {
            // [EMERGENCIA] Corta a ambicao. Sai no 0x0 com lucro simbolico (10% do TP Base)
            g_SellTPEfetivo = MathMax(tpBasSell * 0.10, 0.50);
            static datetime logBreakS = 0;
            if(TimeCurrent() - logBreakS > 60) {
               logBreakS = TimeCurrent();
               AddLog("[SELL S.O.S] BreakEven ATIVO N"+IntegerToString(g_SellTotal)+" (DD > 10%). TP Reduzido: "+DoubleToString(g_SellTPEfetivo,2));
            }
         } else {
            // [INTELIGENCIA] Mantem o TP cheio porque o mar esta tranquilo
            static datetime logBreakSOk = 0;
            if(TimeCurrent() - logBreakSOk > 600) {
               logBreakSOk = TimeCurrent();
               AddLog("[SELL] Nível "+IntegerToString(g_SellTotal)+" atingido, mas DD Seguro (<10%). Mantendo TP normal.");
            }
         }
      }
      
      g_SellAlvo=CalcularPrecoAlvo(g_SellPrecoMedio,g_SellVolume,g_SellSwap,false,g_SellTPEfetivo);
   } else {
      g_SellTPEfetivo = 0;
   }
   // [v3.25][BUG-A1 FIX] Rastreia origem da zona (N1 = menor preco de entrada Sell)
   // [BUG-M1 FIX] Recalcula SEMPRE a partir do minPrice atual (evita travar com fechamento parcial manual)
   if(g_SellTotal==0) g_SellZoneOrigin=0;
   else if(minPrice > 0) g_SellZoneOrigin = minPrice;
   
   // PREDICT PARA O PAINEL
   g_SellProxPreco=0; g_SellDistFalt=0; g_SellProxFR=0; g_SellTfAlvo="";
   if(g_SellNivelAtual>0 && g_SellNivelAtual<InpMaxOrdens) {
      double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double dist=MathAbs(g_SellExtremo-ask);
      int nivel=g_SellNivelAtual+1;
      double mult=MathMax(InpDist_Base,InpDist_Base+(nivel-2)*InpDistStep);
      double distMinima = MathMax(g_ATR_Value*mult, InpMinDistancePoints * _Point);
      g_SellDistFalt = MathMax(0,distMinima-dist);

      double resFR=0; g_SellTfAlvo="DISTANCIA";
      // double v_h1=(g_FR_H1_Res>0&&g_FR_H1_Res>g_SellExtremo)?g_FR_H1_Res:0;
      double v_h4 =(g_FR_H4_Res >0&&g_FR_H4_Res >g_SellExtremo)?g_FR_H4_Res :0;
      double v_h12=(g_FR_H12_Res>0&&g_FR_H12_Res>g_SellExtremo)?g_FR_H12_Res:0;  // [v3.27]
      double v_d1 =(g_FR_D1_Res >0&&g_FR_D1_Res >g_SellExtremo)?g_FR_D1_Res :0;
      // double v_w1=(g_FR_W1_Res>0&&g_FR_W1_Res>g_SellExtremo)?g_FR_W1_Res:0;
      if(nivel<=3 &&v_h4 >0){resFR=v_h4; g_SellTfAlvo="H4 FR";}  // N2, N3 -> H4
      else if(nivel==4&&v_h12>0){resFR=v_h12;g_SellTfAlvo="H12 FR";} // N4  -> H12 (ponte)
      else if(v_d1 >0){resFR=v_d1; g_SellTfAlvo="D1 FR";}  // N5, N6 -> D1 (Sweet-Spot)
      g_SellProxFR=resFR;
      g_SellProxPreco = (resFR > 0) ? resFR : (g_SellExtremo + distMinima);

      if(InpZoneCap>0 && g_SellNivelAtual>=InpZoneCap && g_SellZoneOrigin>0) {
         // [BUG-M1 FIX] zona_min escala por nivel para protecao crescente em grades avancadas
         double totalDist = MathAbs(g_SellZoneOrigin - ask);
         double zona_min  = nivel * InpDist_Base * g_ATR_Value;  // antes: InpZoneCap (fixo)
         if(totalDist < zona_min) {
            double dif = zona_min - totalDist;
            if(dif > g_SellDistFalt) {
                g_SellDistFalt = dif;
                g_SellTfAlvo = "ZONE CAP";
                g_SellProxPreco = g_SellZoneOrigin + zona_min;
            }
         }
      }
   }
}

//===================================================================
// TAKE PROFIT Ã¢â‚¬â€  FECHA CESTO QUANDO ATINGE ALVO
//===================================================================
void GetWorstOrderInfo(int magicNum, double &worstProf, double &worstVol, double &costMinLot) {
   worstProf = 0;
   worstVol = 0;
   costMinLot = 0;
   ulong worstTicket = 0;
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNum) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      double p = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(worstTicket == 0 || p < worstProf) {
         worstTicket = t;
         worstProf = p;
         worstVol = PositionGetDouble(POSITION_VOLUME);
      }
   }
   if(worstTicket > 0 && worstProf < 0 && worstVol > 0) {
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(minLot <= 0) minLot = 0.01;
      costMinLot = MathAbs(worstProf) / (worstVol / minLot);
   }
}

void ExecutarHedgeParcial(bool isBuyWin, double maxGasto) {
   int magicOposto = isBuyWin ? g_MagicSell : g_MagicBuy;
   ulong worstTicket = 0;
   double worstProfit = 0;
   double worstVol = 0;
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicOposto) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      double p = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(worstTicket == 0 || p < worstProfit) {
         worstTicket = t;
         worstProfit = p;
         worstVol = PositionGetDouble(POSITION_VOLUME);
      }
   }
   if(worstTicket > 0 && worstProfit < 0 && worstVol > 0) {
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(minLot <= 0) minLot = 0.01;
      double custoPorMinLot = MathAbs(worstProfit) / (worstVol / minLot);
      if(custoPorMinLot > 0) {
         double fatorVolume = (maxGasto + 0.0001) / custoPorMinLot;
         double varredura = MathFloor(fatorVolume) * minLot;
         if(varredura >= minLot) {
            double volParaFechar = MathMin(varredura, worstVol);
            AddLog("[SOS] Queimando "+DoubleToString(maxGasto,2)+" USC do lucro para abater "+DoubleToString(volParaFechar,3)+" lotes da pior pos. do hedge!");
            trade.PositionClosePartial(worstTicket, volParaFechar);
         }
      }
   }
}

void GerenciarTPBuy() {
   if(g_BuyTotal==0) {
      g_BuyEmTrailing = false;
      g_BuyLucroMaximo = 0;
      return;
   }
   double lucroAtual = g_BuyLucro + g_BuySwap;

   if(!InpTrailingHabilitado) {
      if(lucroAtual >= g_BuyTPEfetivo) {
         if(InpAtivarHedgeParcial && g_SellTotal >= InpNivelHedgeParcial && lucroAtual > 0)
            ExecutarHedgeParcial(true, lucroAtual * InpFatorLucroHedge);
         FecharCesto(true);
         g_BuyZoneOrigin = 0;  // [BUG-C2 FIX] Reset zona apos fechamento por TP
         if(InpCooldownHabilitado && InpCooldownMinutos > 0)
            g_BuyCooldownEnd = TimeCurrent() + (InpCooldownMinutos * 60);
         AddLog("[BUY] Ciclo Fechado! +"+DoubleToString(lucroAtual,2)+" USC | TP Efetivo:"+DoubleToString(g_BuyTPEfetivo,2));
      }
   } else {
      // [v3.26] Protetor 50%: em emergencia, inicia trailing quando atinge metade do alvo
      double gatilhoTrailing = (g_BuyTotal >= InpNivelBreakEven)
         ? g_BuyTPEfetivo * 0.50   // Emergencia: aciona na metade
         : g_BuyTPEfetivo;          // Normal: aciona no alvo completo

      if(lucroAtual >= gatilhoTrailing && !g_BuyEmTrailing) {
         g_BuyEmTrailing = true;
         g_BuyLucroMaximo = lucroAtual;
         string msg = (g_BuyTotal >= InpNivelBreakEven)
            ? "[BUY] Protetor 50% ATIVO! Trailing anti-reversao ("+DoubleToString(lucroAtual,2)+" USC)"
            : "[BUY] Alvo atingido! Iniciando Trailing rastreador...";
         AddLog(msg);
      }

      if(g_BuyEmTrailing) {
         if(lucroAtual > g_BuyLucroMaximo) g_BuyLucroMaximo = lucroAtual;
         double folgaAtual = MathMin(InpTrailingRecuoUsc, g_BuyTPEfetivo * 0.50);
         if(InpTrailingProtecao && g_BuyTotal > 2)
            folgaAtual = MathMin(0.10, folgaAtual/2.0);
         if(lucroAtual <= (g_BuyLucroMaximo - folgaAtual) || (lucroAtual > 0 && lucroAtual <= g_BuyTPEfetivo * 0.30)) {
            if(InpAtivarHedgeParcial && g_SellTotal >= InpNivelHedgeParcial && lucroAtual > 0)
               ExecutarHedgeParcial(true, lucroAtual * InpFatorLucroHedge);
            FecharCesto(true);
            g_BuyZoneOrigin = 0;  // [BUG-C2 FIX] Reset zona apos Trailing
            if(InpCooldownHabilitado && InpCooldownMinutos > 0)
               g_BuyCooldownEnd = TimeCurrent() + (InpCooldownMinutos * 60);
            AddLog("[BUY] Trailing Executado! +"+DoubleToString(lucroAtual,2)+" USC (Max: "+DoubleToString(g_BuyLucroMaximo,2)+")");
            g_BuyEmTrailing = false;
            g_BuyLucroMaximo = 0;
         }
      }
   }
}

void GerenciarTPSell() {
   if(g_SellTotal==0) {
      g_SellEmTrailing = false;
      g_SellLucroMaximo = 0;
      return;
   }
   double lucroAtual = g_SellLucro + g_SellSwap;

   if(!InpTrailingHabilitado) {
      if(lucroAtual >= g_SellTPEfetivo) {
         if(InpAtivarHedgeParcial && g_BuyTotal >= InpNivelHedgeParcial && lucroAtual > 0)
            ExecutarHedgeParcial(false, lucroAtual * InpFatorLucroHedge);
         FecharCesto(false);
         g_SellZoneOrigin = 0;  // [BUG-C2 FIX] Reset zona apos fechamento por TP
         if(InpCooldownHabilitado && InpCooldownMinutos > 0)
            g_SellCooldownEnd = TimeCurrent() + (InpCooldownMinutos * 60);
         AddLog("[SELL] Ciclo Fechado! +"+DoubleToString(lucroAtual,2)+" USC | TP Efetivo:"+DoubleToString(g_SellTPEfetivo,2));
      }
   } else {
      // [v3.26] Protetor 50%: em emergencia, inicia trailing quando atinge metade do alvo
      double gatilhoTrailing = (g_SellTotal >= InpNivelBreakEven)
         ? g_SellTPEfetivo * 0.50
         : g_SellTPEfetivo;

      if(lucroAtual >= gatilhoTrailing && !g_SellEmTrailing) {
         g_SellEmTrailing = true;
         g_SellLucroMaximo = lucroAtual;
         string msg = (g_SellTotal >= InpNivelBreakEven)
            ? "[SELL] Protetor 50% ATIVO! Trailing anti-reversao ("+DoubleToString(lucroAtual,2)+" USC)"
            : "[SELL] Alvo atingido! Iniciando Trailing rastreador...";
         AddLog(msg);
      }

      if(g_SellEmTrailing) {
         if(lucroAtual > g_SellLucroMaximo) g_SellLucroMaximo = lucroAtual;
         double folgaAtual = MathMin(InpTrailingRecuoUsc, g_SellTPEfetivo * 0.50);
         if(InpTrailingProtecao && g_SellTotal > 2)
            folgaAtual = MathMin(0.10, folgaAtual/2.0);
         if(lucroAtual <= (g_SellLucroMaximo - folgaAtual) || (lucroAtual > 0 && lucroAtual <= g_SellTPEfetivo * 0.30)) {
            if(InpAtivarHedgeParcial && g_BuyTotal >= InpNivelHedgeParcial && lucroAtual > 0)
               ExecutarHedgeParcial(false, lucroAtual * InpFatorLucroHedge);
            FecharCesto(false);
            g_SellZoneOrigin = 0;  // [BUG-C2 FIX] Reset zona apos Trailing
            if(InpCooldownHabilitado && InpCooldownMinutos > 0)
               g_SellCooldownEnd = TimeCurrent() + (InpCooldownMinutos * 60);
            AddLog("[SELL] Trailing Executado! +"+DoubleToString(lucroAtual,2)+" USC (Max: "+DoubleToString(g_SellLucroMaximo,2)+")");
            g_SellEmTrailing = false;
            g_SellLucroMaximo = 0;
         }
      }
   }
}

//===================================================================
// SOFT STOP Ã¢â‚¬â€  MONITORA DD COMBINADO DOS 2 CESTOS
//===================================================================
bool SoftStopAtingido() {
   // [BUG-C2 FIX] Usa PNL real dos cestos do ROBO, nao DD da conta toda
   // Loga APENAS na transicao de estado (evita supressao por cooldown durante oscilacoes rapidas)
   double ddRobo = MathAbs(MathMin(0.0, (g_BuyLucro+g_BuySwap) + (g_SellLucro+g_SellSwap)));
   bool atual = (ddRobo >= g_SoftStopAtual);
   if(atual && !g_SoftStopAtivo) {  // Ativou agora
      AddLog("!! SoftStop ATIVADO ("+DoubleToString(g_SoftStopAtual,0)+" USC DD Robo) - AMBOS cestos bloqueados!");
      g_SoftStopLogTime = TimeCurrent();
   }
   if(!atual && g_SoftStopAtivo) {  // Liberou agora
      AddLog("OK SoftStop LIBERADO. DD Robo: "+DoubleToString(ddRobo,2)+" USC");
      g_SoftStopLogTime = TimeCurrent();
   }
   g_SoftStopAtivo = atual;
   return atual;
}

bool AntiSpike() {
   if(g_ATR_Value<=0) return true;
   double r=iHigh(_Symbol,InpTrendTF,1)-iLow(_Symbol,InpTrendTF,1);
   return(r>(g_ATR_Value*InpAntiSpikeATR));
}

bool FiltroRollover() {
   if(!InpFiltroRollover) return false;
   MqlDateTime dt; TimeCurrent(dt);
   return((dt.hour==23&&dt.min>=50)||(dt.hour==0&&dt.min<=30));
}

//===================================================================
// FILTRO DE PALAVRAS-CHAVE CRÍTICAS (Estilo Pasta Vermelha do Forex Factory)
//===================================================================
bool IsCriticalHighImpactNews(string eventName) {
   string nameLower = eventName;
   StringToLower(nameLower);
   
   // 1. Decisões de Taxa de Juros e FOMC
   if(StringFind(nameLower, "taxa de juros") >= 0 || StringFind(nameLower, "interest rate") >= 0) return true;
   if(StringFind(nameLower, "decisão sobre a taxa") >= 0 || StringFind(nameLower, "rate decision") >= 0) return true;
   if(StringFind(nameLower, "fomc") >= 0 || StringFind(nameLower, "política monetária") >= 0 || StringFind(nameLower, "monetary policy") >= 0) return true;
   if(StringFind(nameLower, "bank rate") >= 0 || StringFind(nameLower, "overnight rate") >= 0) return true;
   
   // 2. Inflação (CPI / IPC)
   if(StringFind(nameLower, "cpi") >= 0 || StringFind(nameLower, "ipc") >= 0 || StringFind(nameLower, "inflação") >= 0 || StringFind(nameLower, "inflation") >= 0) return true;
   
   // 3. Emprego (NFP / Non-Farm Payrolls)
   if(StringFind(nameLower, "payroll") >= 0 || StringFind(nameLower, "non-farm") >= 0 || StringFind(nameLower, "nfp") >= 0) return true;
   if(StringFind(nameLower, "relatório de emprego") >= 0 || StringFind(nameLower, "employment report") >= 0) return true;
   if(StringFind(nameLower, "desemprego") >= 0 || StringFind(nameLower, "unemployment") >= 0) return true;
   
   // 4. PIB (GDP)
   if(StringFind(nameLower, "pib") >= 0 || StringFind(nameLower, "gdp") >= 0) return true;
   
   // 5. Vendas no Varejo (Retail Sales)
   if(StringFind(nameLower, "retail sales") >= 0 || StringFind(nameLower, "vendas no varejo") >= 0) return true;
   
   // 6. Discursos dos Presidentes dos Bancos Centrais (Powell, Lagarde, Bailey, Ueda, Macklem)
   // Ignora discursos de membros menores que não movem o mercado
   if(StringFind(nameLower, "discurso") >= 0 || StringFind(nameLower, "speaks") >= 0 || StringFind(nameLower, "speech") >= 0) {
      if(StringFind(nameLower, "powell") >= 0 || StringFind(nameLower, "lagarde") >= 0 || StringFind(nameLower, "bailey") >= 0 || StringFind(nameLower, "ueda") >= 0 || StringFind(nameLower, "macklem") >= 0) {
         return true;
      }
   }
   
   return false;
}

bool IsNewsEventActive(bool &isFrozen, string &newsName) {
   isFrozen = false;
   newsName = "";
   if(!InpUseNewsFilter) return false;

   datetime utcNow = TimeGMT();
   datetime from = utcNow - InpMinAfterNews * 60;
   datetime to   = utcNow + InpMinBeforeNews * 60;

   MqlCalendarValue values[];
   // [FIX] CalendarValueHistory e a assinatura correta nesta build do MT5
   int total = CalendarValueHistory(values, from, to);
   if(total <= 0) return false;

   for(int i = 0; i < total; i++) {
      MqlCalendarEvent event;
      MqlCalendarCountry country;
      if(!CalendarEventById(values[i].event_id, event)) continue;
      // [FIX] Busca o pais para obter o codigo da moeda (event.currency nao existe)
      if(!CalendarCountryById(event.country_id, country)) continue;

      if(InpFilterByActivePairs) {
         // [FIX] Usa country.currency (string do pais) em vez de event.currency
         if(StringFind(_Symbol, country.currency) < 0) continue;
      }

      // Filtra apenas notícias críticas de altíssimo impacto (Pastas Vermelhas do Forex Factory)
      if(!IsCriticalHighImpactNews(event.name)) continue;

      // Filtro por nivel de impacto
      bool matchesImpact = false;
      if(InpNewsImpact == NEWS_IMPACT_HIGH_ONLY) {
         matchesImpact = (event.importance == CALENDAR_IMPORTANCE_HIGH);
      } else {
         // [FIX] CALENDAR_IMPORTANCE_MODERATE e o enum correto para medio impacto
         matchesImpact = (event.importance == CALENDAR_IMPORTANCE_HIGH ||
                          event.importance == CALENDAR_IMPORTANCE_MODERATE);
      }

      if(!matchesImpact) continue;

      datetime eventTime = values[i].time;

      // Dentro da janela de protecao (antes ou logo apos a noticia)
      if(utcNow >= eventTime - InpMinBeforeNews * 60 && utcNow <= eventTime + InpMinAfterNews * 60) {
         isFrozen = true;
         newsName = event.name + " (" + country.currency + ")";
         return true;
      }

      // Apos a janela: verifica estabilizacao por ATR
      if(utcNow > eventTime + InpMinAfterNews * 60) {
         double buf14[], buf100[];
         ArraySetAsSeries(buf14, true);
         ArraySetAsSeries(buf100, true);
         double atr14 = 0, atr100 = 0;
         if(CopyBuffer(handleATR, 0, 0, 1, buf14) > 0) atr14 = buf14[0];
         if(CopyBuffer(handleATR_Long, 0, 0, 1, buf100) > 0) atr100 = buf100[0];

         if(atr14 > 0 && atr100 > 0 && atr14 > (InpNewsAtrMultiplier * atr100)) {
            isFrozen = true;
            // [FIX] Usa country.currency em vez de event.currency
            newsName = event.name + " (" + country.currency + ") [Volatilidade Elevada]";
            return true;
         }
      }
   }
   return false;
}

void AtualizarEstadoNoticias() {
   g_NewsActive = IsNewsEventActive(g_NewsFrozen, g_NewsName);
}

//===================================================================
// FILTRO ATR [v3.28] — Distancia Minima por ATR entre Recompras
// Retorna TRUE se a recompra esta LIBERADA (preco se afastou o suficiente)
// Retorna FALSE se BLOQUEADA (mercado lateral, muito perto da ultima entrada)
//===================================================================
bool FiltroATRDistanciaOK(int magicNum, bool isBuy) {
   if(InpRecompra_ATR_Factor <= 0.0) return true;  // Filtro desligado
   if(g_ATR_Value <= 0) return true;               // ATR invalido: nao bloqueia

   // [v3.29 FIX] Usa o preco EXTREMO do cesto como referencia — mesmo ponto da grade
   // Antes usava a entrada mais recente, causando inconsistencia com o filtro de grade
   // e permitindo entradas proximas em mercados de bounce
   double dist_minima_pts = g_ATR_Value * InpRecompra_ATR_Factor;
   double preco_atual = isBuy
      ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Busca o preco EXTREMO do cesto (mais adverso = mais baixo para Buy, mais alto para Sell)
   double extremoPreco = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magicNum) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      double p = PositionGetDouble(POSITION_PRICE_OPEN);
      if(isBuy) {
         if(extremoPreco == 0 || p < extremoPreco) extremoPreco = p;  // menor preco Buy
      } else {
         if(extremoPreco == 0 || p > extremoPreco) extremoPreco = p;  // maior preco Sell
      }
   }

   if(extremoPreco == 0) return true; // Cesto vazio, libera

   double dist_atual = MathAbs(preco_atual - extremoPreco);
   if(dist_atual < dist_minima_pts) {
      static datetime logATR_Buy  = 0;
      static datetime logATR_Sell = 0;
      string dir = isBuy ? "BUY" : "SELL";
      bool   podeLog = false;
      if(isBuy)  { if((TimeCurrent() - logATR_Buy)  >= 60) { logATR_Buy  = TimeCurrent(); podeLog = true; } }
      else       { if((TimeCurrent() - logATR_Sell) >= 60) { logATR_Sell = TimeCurrent(); podeLog = true; } }
      if(podeLog)
         AddLog("[" + dir + "] ATR-Filter BLOQUEOU (extremo): dist=" +
                DoubleToString(dist_atual/_Point, 1) + "pts < min=" +
                DoubleToString(dist_minima_pts/_Point, 1) + "pts (" +
                DoubleToString(InpRecompra_ATR_Factor, 1) + "xATR)");
      return false;  // Muito perto do extremo! Bloqueia.
   }
   return true;  // Distancia suficiente do extremo: libera recompra
}

double GetWorstOrderCostByMagic(int magicNum) {
   double worstProf = 0, worstVol = 0, costMinLot = 0;
   GetWorstOrderInfo(magicNum, worstProf, worstVol, costMinLot);
   return costMinLot;
}

void FecharTudoCiclo(bool autoReset) {
   // Loop de retentativas para garantir o fechamento sob slippage/requotes
   for(int retry = 0; retry < 5; retry++) {
      ulong tickets[];
      int total = PositionsTotal();
      ArrayResize(tickets, total);
      int count = 0;
      
      for(int i = 0; i < total; i++) {
         ulong t = PositionGetTicket(i);
         if(t > 0) {
            if(PositionSelectByTicket(t)) {
               int mag = (int)PositionGetInteger(POSITION_MAGIC);
               if(mag >= InpMagicNumberBase && mag <= InpMagicNumberBase + 999999) {
                  tickets[count] = t;
                  count++;
               }
            }
         }
      }
      
      if(count == 0) break; // Todas as posicoes fechadas com sucesso!
      
      for(int i = 0; i < count; i++) {
         trade.PositionClose(tickets[i]);
      }
      
      if(retry < 4) Sleep(200); // Aguarda 200ms para processamento do servidor
   }
   
   Sleep(300); // Aguarda tempo adicional para garantir que o saldo terminal foi atualizado pelo broker
   
   g_PanicoAguardando=false;
   g_AguardandoBuy=false; g_ConfirmBuy=0;
   g_AguardandoSell=false; g_ConfirmSell=0;
   g_BuyEmTrailing  = false;  g_BuyLucroMaximo  = 0;
   g_SellEmTrailing = false;  g_SellLucroMaximo = 0;
   
   g_DD_Reached10        = false;
   g_DD_Reached20        = false;
   g_TrailingActive      = false;
   g_PeakProfit          = 0.0;
   
   // Resets para evitar origens stale
   g_BuyZoneOrigin       = 0;
   g_SellZoneOrigin      = 0;
   g_BuyLoteInicial      = 0;
   g_SellLoteInicial     = 0;
   g_BuyNivelAtual       = 0;
   g_SellNivelAtual      = 0;
   g_DD_FaseAtual        = 0;
   g_SS_FaseAtual        = 0;
   
   // Zera contadores de lucro imediatamente (painel mostra 0 na hora)
   g_HistLucroGlobal   = 0;
   g_HistLucroSymbol   = 0;
   g_HistLucroHoje     = 0;
   g_HistSimbolosCount = 0;
   ArrayFree(g_HistSimbolos);
   
   // Definir data de reset global e local
   g_InicioHistorico = TimeCurrent();
   g_InicioHistoricoSymbol = g_InicioHistorico;
   GlobalVariableSet("OrionHedge_Global_ResetTime", (double)g_InicioHistorico);
   GuardarResetTime("global", g_InicioHistorico);
   GuardarResetTime(_Symbol, g_InicioHistoricoSymbol);
   
   // [v3.40 Senior Sync] Atualiza o saldo de referência para o novo saldo pós-fechamento na base global
   double newBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_EquityCycleBaseBalance = newBalance;
   string globalVarName = "OrionHedge_Global_EqBase";
   GlobalVariableSet(globalVarName, g_EquityCycleBaseBalance);
    
   // Reset global de DD e Trailing no término do ciclo
   GlobalVariableSet("OrionHedge_Global_DDReached10", 0.0);
   GlobalVariableSet("OrionHedge_Global_DDReached20", 0.0);
   GlobalVariableSet("OrionHedge_Global_TrailingActive", 0.0);
   GlobalVariableSet("OrionHedge_Global_PeakProfit", 0.0);

   g_DealsCountCache = -1;

   if(!autoReset) {
      // Ativar pausa global no terminal
      GlobalVariableSet("OrionHedge_Global_BotPaused", 1.0);
      g_BotPaused = true;
      AddLog("CICLO DE EQUITY: Cestos ZERADOS e EA PAUSADO.");
   } else {
      // Ativar cooldown
      if(InpCooldownCicloMinutos > 0) {
         datetime cdEnd = TimeCurrent() + (InpCooldownCicloMinutos * 60);
         g_BuyCooldownEnd = cdEnd;
         g_SellCooldownEnd = cdEnd;
         g_EquityCycleCooldownEnd = cdEnd;
         AddLog("CICLO DE EQUITY: Cestos ZERADOS. Cooldown de " + IntegerToString(InpCooldownCicloMinutos) + " min ativado.");
      } else {
         g_BuyCooldownEnd = 0;
         g_SellCooldownEnd = 0;
         g_EquityCycleCooldownEnd = 0;
         AddLog("CICLO DE EQUITY: Cestos ZERADOS. Novo ciclo iniciado.");
      }
      
      // Garante que o robô continue ativo
      GlobalVariableSet("OrionHedge_Global_BotPaused", 0.0);
      g_BotPaused = false;
   }
}

void VerificarCicloEquity() {
   if(!InpAtivarCicloEquity) return;
   if(g_BotPaused) return;
   if(TimeCurrent() < g_EquityCycleCooldownEnd) return;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance <= 0) return;

   // 1. Inicializa ou recupera o saldo de referência usando GlobalVariables do MT5 (segurança contra queda da VPS)
   string globalVarName = "OrionHedge_Global_EqBase";
   string migratedVarName = "OrionHedge_Global_EqBaseMigrated_V2";
   
   // Check if global base is already set and valid
   bool hasGlobalBase = false;
   if(GlobalVariableCheck(globalVarName)) {
      double curBase = GlobalVariableGet(globalVarName);
      if(curBase > 0) hasGlobalBase = true;
   }
   
   // [MIGRATION-FALLBACK] Uma única migração se o ciclo estiver ativo e houver base antiga salva
   // Usamos TemPosicoesLocais() para garantir que apenas o gráfico com posições ativas faça a migração inicial.
   if(!hasGlobalBase && !GlobalVariableCheck(migratedVarName) && TemPosicoesLocais()) {
      string oldVarName = "OrionHedge_EqBase_" + _Symbol;
      if(GlobalVariableCheck(oldVarName)) {
         double oldBase = GlobalVariableGet(oldVarName);
         if(oldBase > 0) {
            g_EquityCycleBaseBalance = oldBase;
            GlobalVariableSet(globalVarName, g_EquityCycleBaseBalance);
            GlobalVariableSet(migratedVarName, 1.0);
            AddLog("CICLO: Migrada base antiga do simbolo " + _Symbol + " = " + DoubleToString(g_EquityCycleBaseBalance, 2) + " para a base global.");
         }
      }
   }

   if(g_EquityCycleBaseBalance <= 0) {
      if(GlobalVariableCheck(globalVarName)) {
         double savedBase = GlobalVariableGet(globalVarName);
         // [BUG-FIX] Sanity check: se a base salva desviou > 20% do saldo real,
         // ela está desatualizada (ex: depósito externo, troca de conta, migração).
         // Reinicializa com o saldo real para corrigir o "preço base antigo".
         double deviation = (balance > 0) ? MathAbs(savedBase - balance) / balance * 100.0 : 100.0;
         if(deviation > 20.0) {
            g_EquityCycleBaseBalance = balance;
            GlobalVariableSet(globalVarName, g_EquityCycleBaseBalance);
            AddLog(StringFormat("CICLO: Base desatualizada detectada (salva=%.2f, real=%.2f, desvio=%.1f%%). Reinicializando com saldo atual.", savedBase, balance, deviation));
         } else {
            g_EquityCycleBaseBalance = savedBase;
         }
      } else {
         g_EquityCycleBaseBalance = balance;
         GlobalVariableSet(globalVarName, g_EquityCycleBaseBalance);
      }
   }

   // Se não houver posições em nenhum dos cestos de nenhuma moeda (ciclo global ocioso)
   if(!TemPosicoesGlobais()) {
      g_DD_Reached10        = false;
      g_DD_Reached20        = false;
      g_TrailingActive      = false;
      g_PeakProfit          = 0.0;
      g_EquityCycleCooldownEnd = 0;
      
      GlobalVariableSet("OrionHedge_Global_DDReached10", 0.0);
      GlobalVariableSet("OrionHedge_Global_DDReached20", 0.0);
      GlobalVariableSet("OrionHedge_Global_TrailingActive", 0.0);
      GlobalVariableSet("OrionHedge_Global_PeakProfit", 0.0);

      bool updated = false;
      // [FIX] A base do ciclo de equity agora permanece fixa para acumular lucros.
      // Só resincronizamos a base se houver um depósito ou saque externo (diferença > 200 USC / $2 USD entre o saldo real e o esperado).
      double expectedBalance = g_EquityCycleBaseBalance + g_HistLucroGlobal;
      if(MathAbs(balance - expectedBalance) > 200.0) {
         g_EquityCycleBaseBalance = balance;
         GlobalVariableSet(globalVarName, g_EquityCycleBaseBalance);
         updated = true;
      }
      
      if(updated) {
         g_InicioHistorico = TimeCurrent();
         GlobalVariableSet("OrionHedge_Global_ResetTime", (double)g_InicioHistorico);
         GuardarResetTime("global", g_InicioHistorico);
         g_DealsCountCache = -1; // Força recálculo do histórico
         AddLog("CICLO DE EQUITY: Depósito/Saque ou ajuste detectado. Nova base definida para " + DoubleToString(balance, 2) + " e reiniciando histórico do ciclo.");
      }
      return;
   }

   // 2. Calcula lucros e swaps de ordens abertas para estatísticas de drawdown
   double global_profit = 0, global_swap = 0;
   for(int i = 0; i < PositionsTotal(); i++) {
      ulong tck = PositionGetTicket(i);
      if(tck > 0) {
         long mag = PositionGetInteger(POSITION_MAGIC);
         if(mag >= InpMagicNumberBase && mag <= InpMagicNumberBase + 999999) {
            global_swap   += PositionGetDouble(POSITION_SWAP);
            global_profit += PositionGetDouble(POSITION_PROFIT);
         }
      }
   }
   double global_total = global_profit + global_swap;
   
   // Calcula rebaixamento flutuante da conta (%)
   double dd_glb_pct = (balance > 0) ? MathAbs(MathMin(0.0, global_total)) / balance * 100.0 : 0.0;
   
   if(dd_glb_pct >= 20.0) {
      g_DD_Reached20 = true;
      GlobalVariableSet("OrionHedge_Global_DDReached20", 1.0);
   } else if(dd_glb_pct >= 10.0) {
      g_DD_Reached10 = true;
      GlobalVariableSet("OrionHedge_Global_DDReached10", 1.0);
   }

   // Sincronizar localmente flags se outro EA as ativou
   if(GlobalVariableCheck("OrionHedge_Global_DDReached10") && GlobalVariableGet("OrionHedge_Global_DDReached10") > 0.5) g_DD_Reached10 = true;
   if(GlobalVariableCheck("OrionHedge_Global_DDReached20") && GlobalVariableGet("OrionHedge_Global_DDReached20") > 0.5) g_DD_Reached20 = true;

   // 3. Calcula o lucro líquido real acumulado do ciclo (L. LÍQUIDO = Fechado + Aberto)
   double profitNet = g_HistLucroGlobal + global_total;
   double pctNet = (g_EquityCycleBaseBalance > 0) ? (profitNet / g_EquityCycleBaseBalance * 100.0) : 0.0;
   
   // A meta percentual Ã© fixa em relaÃ§Ã£o Ã  base de referÃªncia deste ciclo
   double currentTargetPct = InpMetaCicloEquityPct;
   
   g_PeakProfit = pctNet;
   g_TrailingActive = true;

   // 4. Verifica se a meta de lucro do ciclo foi atingida
   if(pctNet >= currentTargetPct) {
      string msg = "ORION HEDGE - META DE EQUITY ATINGIDA! ✅\n";
      msg += "Ativo: " + _Symbol + "\n";
      msg += "Saldo Anterior: " + DoubleToString(g_EquityCycleBaseBalance, 2) + "\n";
      msg += "Lucro Realizado Líquido: " + DoubleToString(profitNet, 2) + " (" + DoubleToString(pctNet, 2) + "%)\n";
      msg += "Novo Saldo de Referência: " + DoubleToString(equity, 2) + "\n";
      
      if(InpAutoResetCiclo) {
         msg += "Ação: Fechando tudo e reiniciando ciclo automático.";
      } else {
         msg += "Ação: Fechando tudo e Pausando o robô.";
      }

      if(InpPushFechamento) {
         SendNotification(msg);
      }
      AddLog(msg);

      FecharTudoCiclo(InpAutoResetCiclo);
   }
}

//===================================================================
// EXECUTAR GRADE — RECOMPRAS
//===================================================================
double CalcNovoLote(int nivelAtual, double loteInicial=0) {
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double minV=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxV=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   
   // [v3.33 Senior Audit] Prevenção de divisão por zero caso o broker retorne dados vazios/inválidos
   if(step <= 0) step = 0.01;
   if(minV <= 0) minV = 0.01;
   if(maxV <= 0) maxV = 500.0;
   
   double base=(loteInicial>0)?loteInicial:g_LoteBase;  // [FIX #11] Escala do lote correto
   double raw=base*MathPow(InpLotMultiplier,nivelAtual);
   double lot=MathMax(MathFloor(raw/step)*step,minV);
   return MathMin(lot,maxV);
}

bool FiltroAntiFacaConfirmado(bool isBuy) {
   if(!InpAtivarAntiFaca) return true; // Se estiver desligado, libera sempre
   
   double openPrice  = iOpen(_Symbol, InpAntiFacaTF, 1);
   double closePrice = iClose(_Symbol, InpAntiFacaTF, 1);
   
   if(openPrice <= 0 || closePrice <= 0) return true; // Segurança caso falhe a leitura dos dados
   
   // BUG #6 FIX: Tolerancia minima para evitar bloqueio por doji em baixa liquidez.
   // Um candle com diff de 1 pip nao deve bloquear recompras indefinidamente.
   double minDiff = _Point * 2;
   
   if(isBuy) {
      // Para Compra: espera o candle fechar com alta de pelo menos 2 pips
      return (closePrice > openPrice + minDiff);
   } else {
      // Para Venda: espera o candle fechar com baixa de pelo menos 2 pips
      return (closePrice < openPrice - minDiff);
   }
}

//===================================================================
// FILTRO DE TENDÊNCIA E NOTÍCIA PARA NOVAS RECOMPRAS
//===================================================================
bool BloquearNovaRecompra(bool isBuy) {
   if(InpBloquearRecompraNoticia && g_NewsActive) {
      return true;
   }

   if(InpFiltroTendenciaForte && g_ADX_Trend >= InpADX_TrendThreshold) {
      bool tendenciaDeAlta  = (g_DIPlus_Trend  > g_DIMinus_Trend);
      bool tendenciaDeBaixa = (g_DIMinus_Trend > g_DIPlus_Trend);
      if(isBuy  && tendenciaDeBaixa) return true;
      if(!isBuy && tendenciaDeAlta)  return true;
   }

   return false;
}

void ExecutarGradeBuy() {
   if(g_ATR_Value<=0||!TerminalInfoInteger(TERMINAL_CONNECTED)) return;
   trade.SetExpertMagicNumber(g_MagicBuy);
   if(g_AguardandoBuy) return;

   if(g_BuyDistFalt > 0) return; // Nao atingiu a distancia minima projetada

   // [v3.28] FILTRO ATR: bloqueia recompra se preco nao se afastou 1xATR da ultima entrada
   if(!FiltroATRDistanciaOK(g_MagicBuy, true)) return;

   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   int nivel=g_BuyNivelAtual+1;
   datetime currentBar = iTime(_Symbol, InpBaseTF, 0);
         if(InpOneTradePerBar && g_BuyLastBarTime == currentBar) return;
   
   double supFR = g_BuyProxFR;

   bool tenta=false;
   if(supFR>0) tenta=(bid<=supFR);
   else { tenta=true; AddLog("[BUY] FR indisponivel N"+IntegerToString(nivel)+". Forcado."); }
   if(!tenta) return;

   // [v3.38] Gatilho Anti-Faca: aguarda fechamento de candle na direção do cesto
   if(!FiltroAntiFacaConfirmado(true)) return;

   // [FILTRO NOTICIA/TENDENCIA]
   if(BloquearNovaRecompra(true)) {
      static datetime lastLogBuy = 0;
      if(TimeCurrent() - lastLogBuy > 60) {
         AddLog("[TENDÊNCIA/NOTÍCIA] Recompra de COMPRA bloqueada: Filtro ativo.");
         lastLogBuy = TimeCurrent();
      }
      return;
   }

   if((int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>InpMaxSpread) return;

   double novoLote=CalcNovoLote(g_BuyNivelAtual, g_BuyLoteInicial);  // [FIX #11]
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double margem=0;
   if(OrderCalcMargin(ORDER_TYPE_BUY,_Symbol,novoLote,ask,margem))
      if(AccountInfoDouble(ACCOUNT_MARGIN_FREE)<margem*1.2){AddLog("[BUY] Margem insuficiente N"+IntegerToString(nivel));return;}

   g_AguardandoBuy=true; g_ConfirmBuy=TimeCurrent();
   if(trade.Buy(novoLote,_Symbol,ask,0,0,"OH_B"+IntegerToString(nivel))) {
      uint rc=trade.ResultRetcode();
      if(rc==TRADE_RETCODE_DONE||rc==TRADE_RETCODE_PLACED) {
         AddLog("[BUY] Recompra N"+IntegerToString(nivel)+" Lote:"+DoubleToString(novoLote,3));
         if(InpOneTradePerBar) g_BuyLastBarTime = currentBar;
      }
      else { g_AguardandoBuy=false; g_ConfirmBuy=0; }
   } else { g_AguardandoBuy=false; g_ConfirmBuy=0; }
}

void ExecutarGradeSell() {
   if(g_ATR_Value<=0||!TerminalInfoInteger(TERMINAL_CONNECTED)) return;
   trade.SetExpertMagicNumber(g_MagicSell);
   if(g_AguardandoSell) return;

   if(g_SellDistFalt > 0) return; // Nao atingiu a distancia minima projetada

   // [v3.28] FILTRO ATR: bloqueia recompra se preco nao se afastou 1xATR da ultima entrada
   if(!FiltroATRDistanciaOK(g_MagicSell, false)) return;

   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   int nivel=g_SellNivelAtual+1;
   datetime currentBar = iTime(_Symbol, InpBaseTF, 0);
   if(InpOneTradePerBar && g_SellLastBarTime == currentBar) return;
   
   double resFR = g_SellProxFR;

   bool tenta=false;
   if(resFR>0) tenta=(ask>=resFR);
   else { tenta=true; AddLog("[SELL] FR indisponivel N"+IntegerToString(nivel)+". Forcado."); }
   if(!tenta) return;

   // [v3.38] Gatilho Anti-Faca: aguarda fechamento de candle na direção do cesto
   if(!FiltroAntiFacaConfirmado(false)) return;

   // [FILTRO NOTICIA/TENDENCIA]
   if(BloquearNovaRecompra(false)) {
      static datetime lastLogSell = 0;
      if(TimeCurrent() - lastLogSell > 60) {
         AddLog("[TENDÊNCIA/NOTÍCIA] Recompra de VENDA bloqueada: Filtro ativo.");
         lastLogSell = TimeCurrent();
      }
      return;
   }

   if((int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>InpMaxSpread) return;

   double novoLote=CalcNovoLote(g_SellNivelAtual, g_SellLoteInicial);  // [FIX #11]
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double margem=0;
   if(OrderCalcMargin(ORDER_TYPE_SELL,_Symbol,novoLote,bid,margem))
      if(AccountInfoDouble(ACCOUNT_MARGIN_FREE)<margem*1.2){AddLog("[SELL] Margem insuficiente N"+IntegerToString(nivel));return;}

   g_AguardandoSell=true; g_ConfirmSell=TimeCurrent();
   if(trade.Sell(novoLote,_Symbol,bid,0,0,"OH_S"+IntegerToString(nivel))) {
      uint rc=trade.ResultRetcode();
      if(rc==TRADE_RETCODE_DONE||rc==TRADE_RETCODE_PLACED) {
         AddLog("[SELL] Recompra N"+IntegerToString(nivel)+" Lote:"+DoubleToString(novoLote,3));
         if(InpOneTradePerBar) g_SellLastBarTime = currentBar;
      }
      else { g_AguardandoSell=false; g_ConfirmSell=0; }
   } else { g_AguardandoSell=false; g_ConfirmSell=0; }
}

//===================================================================
// SENSORES
//===================================================================
bool DetectarFR(ENUM_TIMEFRAMES tf,int nc,double &sup,double &res) {
   sup=0;res=0;
   int tot=nc+2; double hi[],lo[],cl[];
   ArraySetAsSeries(hi,true);ArraySetAsSeries(lo,true);ArraySetAsSeries(cl,true);
   if(CopyHigh(_Symbol,tf,1,tot,hi)<tot) return false;
   if(CopyLow(_Symbol,tf,1,tot,lo)<tot) return false;
   if(CopyClose(_Symbol,tf,1,tot,cl)<tot) return false;
   for(int i=0;i<nc;i++) {
      if(lo[i]<lo[i+1]&&cl[i]>lo[i+1]) {
         if(sup==0) sup=lo[i+1];
      }
      if(hi[i]>hi[i+1]&&cl[i]<hi[i+1]) {
         if(res==0) res=hi[i+1];
      }
      if(sup>0 && res>0) break;
   }
   return true;
}

void AtualizarSensores() {
   double buf[]; ArraySetAsSeries(buf,true);
   if(CopyBuffer(handleATR,0,0,1,buf)>0) g_ATR_Value=buf[0];
   if(CopyBuffer(handleEMA,0,0,1,buf)>0) g_EMA_Value=buf[0];
   if(CopyBuffer(handleADXTrend,0,0,1,buf)>0) g_ADX_Trend=buf[0];
   if(CopyBuffer(handleADXTrend,1,0,1,buf)>0) g_DIPlus_Trend=buf[0];
   if(CopyBuffer(handleADXTrend,2,0,1,buf)>0) g_DIMinus_Trend=buf[0];
   datetime bar=iTime(_Symbol,InpBaseTF,0);
   if(bar==g_SensorBarTime && g_SensorBarTime>0) return;
   
   double sup_h1=0,  res_h1=0;
   double sup_h4=0,  res_h4=0;
   double sup_h12=0, res_h12=0;
   double sup_d1=0,  res_d1=0;
   double sup_w1=0,  res_w1=0;
   
   bool ok = true;
   ok = ok && DetectarFR(PERIOD_H1,  InpFR_Candles, sup_h1,  res_h1);
   ok = ok && DetectarFR(PERIOD_H4,  InpFR_Candles, sup_h4,  res_h4);
   ok = ok && DetectarFR(PERIOD_H12, InpFR_Candles, sup_h12, res_h12);
   ok = ok && DetectarFR(PERIOD_D1,  InpFR_Candles, sup_d1,  res_d1);
   ok = ok && DetectarFR(PERIOD_W1,  InpFR_Candles, sup_w1,  res_w1);
   
   if(ok) {
      g_FR_H1_Sup   = sup_h1;  g_FR_H1_Res   = res_h1;
      g_FR_H4_Sup   = sup_h4;  g_FR_H4_Res   = res_h4;
      g_FR_H12_Sup  = sup_h12; g_FR_H12_Res  = res_h12;
      g_FR_D1_Sup   = sup_d1;  g_FR_D1_Res   = res_d1;
      g_FR_W1_Sup   = sup_w1;  g_FR_W1_Res   = res_w1;
      g_SensorBarTime = bar;
   }
}

void PublishGlobalFilterParams() {
   // [v3.31] Publica os 3 parametros de filtro para sincronizar TODOS os pares abertos
   GlobalVariableSet("OrionHedge_Global_FiltroHistorico", (double)g_FiltroHistorico);
   GlobalVariableSet("OrionHedge_Global_FiltroDataIni",  (double)g_FiltroDataIni);
   GlobalVariableSet("OrionHedge_Global_FiltroDataFim",  (double)g_FiltroDataFim);
}

//===================================================================
// INIT / DEINIT
//===================================================================
int OnInit() {
   // ===== VALIDACAO DE SIMBOLO [v3.24+] =====
   // [BUG #2 FIX] Verifica se o simbolo CONTEM o par base (aceita qualquer sufixo de broker)
   // Ex: EURUSD, EURUSDc, EURUSD., EURUSD_m, EURUSDpro — todos aceitos
   string basePares[] = {"EURUSD","GBPUSD","USDJPY","USDCHF","AUDUSD","USDCAD"};
   bool   simboloOk   = false;
   for(int k=0; k<6; k++) {
      if(StringFind(_Symbol, basePares[k]) >= 0) { simboloOk = true; break; }
   }
   if(!simboloOk) {
      Print("[ORION v3.24] ERRO CRITICO: Simbolo '", _Symbol, "' NAO suportado!");
      Print("  Pares validos: EURUSD | GBPUSD | USDJPY | USDCHF | AUDUSD | USDCAD");
      Print("  (qualquer sufixo aceito: EURUSDc, EURUSD., EURUSD_m, EURUSDpro, etc.)");
      return INIT_FAILED;
   }

   // Dois Magic Numbers: Buy usa base, Sell usa base+1
   long hash=0; string sym=_Symbol;
   for(int i=0;i<StringLen(sym);i++) hash=hash*31+StringGetCharacter(sym,i);
   g_MagicBuy  = (int)(InpMagicNumberBase + MathAbs(hash)%999999);
   g_MagicSell = g_MagicBuy + 1;

   trade.SetDeviationInPoints(50);
   trade.SetTypeFillingBySymbol(_Symbol);

   ChartSetInteger(0, CHART_SHOW_OBJECT_DESCR, true); // Forca exibir descricoes das linhas

   handleATR=iATR(_Symbol,InpBaseTF,InpATRPeriod);
   handleATR_Long=iATR(_Symbol,InpBaseTF,100);
   handleEMA=iMA(_Symbol,InpTrendTF,InpEmaTrend,0,MODE_EMA,PRICE_CLOSE);
   handleADXTrend=iADX(_Symbol,InpTendenciaTF,InpADX_Periodo);
   if(handleATR==INVALID_HANDLE||handleATR_Long==INVALID_HANDLE||handleEMA==INVALID_HANDLE||handleADXTrend==INVALID_HANDLE) {
      Print("Erro indicadores."); return INIT_FAILED;
   }

   LimparIndicadoresAnalise();

   g_TaxaBRLAtual = ObterTaxaBRLDinamica();
   AtualizarLoteBase();
   // Restaurar agendamentos S.O.S persistidos
   if(GlobalVariableCheck("OrionHedge_SOS_BuyAtiva_" + _Symbol))
      g_BuySaidaZeroAtiva = (GlobalVariableGet("OrionHedge_SOS_BuyAtiva_" + _Symbol) > 0.5);
   if(GlobalVariableCheck("OrionHedge_SOS_SellAtiva_" + _Symbol))
      g_SellSaidaZeroAtiva = (GlobalVariableGet("OrionHedge_SOS_SellAtiva_" + _Symbol) > 0.5);
   LimparPainel();  // [v3.25] Vassoura completa on init — remove fantasmas de sessoes anteriores
   EventSetTimer(1);
   AddLog("ORION v3.40 OK! Par: "+_Symbol+" | MagicBuy="+IntegerToString(g_MagicBuy));
   AddLog("[WEB] Web Ativa: " + (InpWebAtiva ? "SIM" : "NAO") + " | URL: " + InpWebUrl);
   AddLog("Lote:"+DoubleToString(g_LoteBase,3)+" TP:"+DoubleToString(g_TakeProfitAtual,2)+" SS:"+DoubleToString(g_SoftStopAtual,0)+" [LotBase="+DoubleToString(InpLotInitial,3)+"]");
   if(InpCooldownHabilitado) AddLog("Cooldown Ativo: "+IntegerToString(InpCooldownMinutos)+" min apos cada ciclo.");
   if(InpRecompra_ATR_Factor > 0)
      AddLog("[v3.28] ATR-Filter ATIVO: dist min = "+DoubleToString(InpRecompra_ATR_Factor,1)+" x ATR("+IntegerToString(InpATRPeriod)+") entre recompras.");
   else
      AddLog("[v3.28] ATR-Filter DESLIGADO (InpRecompra_ATR_Factor=0).");

    // ===== DATA DE RESET DE ESTATISTICAS: CARREGA EXISTENTE OU INICIALIZA =====
    datetime agora = TimeCurrent();
    MqlDateTime md;
    TimeToStruct(agora, md);
    md.hour = 0; md.min = 0; md.sec = 0;
    datetime inicioDia = StructToTime(md);

    // 1. Inicializa g_InicioHistorico
    if(InpFiltroDataInicio > 0) {
       // Se o usuario configurou uma data nos inputs, ela tem prioridade total e sobrescreve qualquer variavel global e arquivo
       g_InicioHistorico = InpFiltroDataInicio;
       GlobalVariableSet("OrionHedge_Global_ResetTime", (double)g_InicioHistorico);
       GuardarResetTime("global", g_InicioHistorico);
    } else {
       bool usarFallback = true;
       // Tenta carregar do arquivo primeiro (blindagem total contra quedas do terminal)
       datetime fileReset = LerResetTime("global");
       if(fileReset > 0) {
          g_InicioHistorico = fileReset;
          GlobalVariableSet("OrionHedge_Global_ResetTime", (double)g_InicioHistorico);
          usarFallback = false;
       } else if(GlobalVariableCheck("OrionHedge_Global_ResetTime")) {
          g_InicioHistorico = (datetime)GlobalVariableGet("OrionHedge_Global_ResetTime");
          if(g_InicioHistorico > TimeCurrent() + 60) { // Protecao apenas contra horario futuro corrompido
             g_InicioHistorico = TimeCurrent();
             GlobalVariableSet("OrionHedge_Global_ResetTime", (double)g_InicioHistorico);
             GuardarResetTime("global", g_InicioHistorico);
          } else {
             usarFallback = false;
          }
       }
       
       if(usarFallback) {
          // Em caso de fallback (arquivo/global inexistentes ou corrompidos), tenta recuperar a data da posicao aberta mais antiga do EA
          datetime oldestTime = 0;
          for(int i = 0; i < PositionsTotal(); i++) {
             ulong tck = PositionGetTicket(i);
             if(tck > 0) {
                long mag = PositionGetInteger(POSITION_MAGIC);
                if(mag >= InpMagicNumberBase && mag <= InpMagicNumberBase + 999999) {
                   datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
                   if(oldestTime == 0 || posTime < oldestTime) oldestTime = posTime;
                }
             }
          }
          if(oldestTime > 0) {
             g_InicioHistorico = oldestTime;
             Print("[PERSISTENCIA] Fallback: Iniciando historico global na posicao aberta mais antiga: ", TimeToString(g_InicioHistorico));
          } else {
             g_InicioHistorico = TimeCurrent();
          }
          GlobalVariableSet("OrionHedge_Global_ResetTime", (double)g_InicioHistorico);
          GuardarResetTime("global", g_InicioHistorico);
       }
    }

    // 2. Inicializa g_InicioHistoricoSymbol
    string symResetVar = "OrionHedge_ResetTime_" + _Symbol;
    if(InpFiltroDataInicio > 0) {
       g_InicioHistoricoSymbol = InpFiltroDataInicio;
       GlobalVariableSet(symResetVar, (double)g_InicioHistoricoSymbol);
       GuardarResetTime(_Symbol, g_InicioHistoricoSymbol);
    } else {
       bool usarFallbackSym = true;
       datetime fileResetSym = LerResetTime(_Symbol);
       if(fileResetSym > 0) {
          g_InicioHistoricoSymbol = fileResetSym;
          GlobalVariableSet(symResetVar, (double)g_InicioHistoricoSymbol);
          usarFallbackSym = false;
       } else if(GlobalVariableCheck(symResetVar)) {
          g_InicioHistoricoSymbol = (datetime)GlobalVariableGet(symResetVar);
          if(g_InicioHistoricoSymbol > TimeCurrent() + 60) { // Protecao contra horario futuro corrompido
             g_InicioHistoricoSymbol = TimeCurrent();
             GlobalVariableSet(symResetVar, (double)g_InicioHistoricoSymbol);
             GuardarResetTime(_Symbol, g_InicioHistoricoSymbol);
          } else {
             usarFallbackSym = false;
          }
       }
       
       if(usarFallbackSym) {
          datetime oldestTimeSym = 0;
          for(int i = 0; i < PositionsTotal(); i++) {
             ulong tck = PositionGetTicket(i);
             if(tck > 0) {
                long mag = PositionGetInteger(POSITION_MAGIC);
                if(PositionGetString(POSITION_SYMBOL) == _Symbol && (mag == g_MagicBuy || mag == g_MagicSell)) {
                   datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
                   if(oldestTimeSym == 0 || posTime < oldestTimeSym) oldestTimeSym = posTime;
                }
             }
          }
          if(oldestTimeSym > 0) {
             g_InicioHistoricoSymbol = oldestTimeSym;
             Print("[PERSISTENCIA] Fallback: Iniciando historico local na posicao aberta mais antiga deste par: ", TimeToString(g_InicioHistoricoSymbol));
          } else {
             g_InicioHistoricoSymbol = g_InicioHistorico;
          }
          GlobalVariableSet(symResetVar, (double)g_InicioHistoricoSymbol);
          GuardarResetTime(_Symbol, g_InicioHistoricoSymbol);
       }
    }

    g_DealsCountCache = -1; // Forca recalculo imediato com nova janela de tempo

    bool temLocais = TemPosicoesLocais();
    bool temGlobais = TemPosicoesGlobais();
    AddLog("Inicializacao: Estatisticas zeradas a partir de agora (" + TimeToString(g_InicioHistorico, TIME_DATE|TIME_MINUTES) + "). L.Global e P.Liquido iniciam do zero.");

    // [FIX AUTO-START] Inicia PAUSADO por seguranca se nao houver ordens abertas localmente.
    // So retoma se houver posicoes abertas locais OU se a GlobalVariable for explicitamente 0 (Retomado).
    g_BotPaused = true;
    if(temLocais) {
       if(GlobalVariableCheck("OrionHedge_Global_BotPaused")) {
          if(GlobalVariableGet("OrionHedge_Global_BotPaused") < 0.5)
             g_BotPaused = false;
       } else {
          g_BotPaused = false;
       }
    } else {
       g_BotPaused = true;
       if(!temGlobais) {
          GlobalVariableSet("OrionHedge_Global_BotPaused", 1.0);
       }
       AddLog("Inicializacao: Sem posicoes abertas neste par. Iniciando em modo PAUSADO.");
    }

   // ===== AUTO-ATIVACAO MODO CUST (inputs de data configurados) [v3.31] =====
   // Se o usuario configurou datas nos inputs do MT5, ativa CUST imediatamente
   // e sobrepoe variaveis globais que possam existir de sessoes anteriores.
   if(InpFiltroDataInicio > 0 || InpFiltroDataFim > 0) {
      g_FiltroHistorico = 4;
      if(InpFiltroDataInicio > 0) g_FiltroDataIni = InpFiltroDataInicio;
      if(InpFiltroDataFim   > 0) g_FiltroDataFim = InpFiltroDataFim;
      PublishGlobalFilterParams(); // Propaga para todos os outros pares abertos
      AddLog("[v3.31] Modo CUST auto-ativado pelos inputs de data. Filtro sincronizado.");
   } else {
      // ===== RECUPERAR FILTRO GLOBAL COMPARTILHADO =====
      if(GlobalVariableCheck("OrionHedge_Global_FiltroHistorico"))
         g_FiltroHistorico = (int)GlobalVariableGet("OrionHedge_Global_FiltroHistorico");
      if(GlobalVariableCheck("OrionHedge_Global_FiltroDataIni"))
         g_FiltroDataIni = (datetime)GlobalVariableGet("OrionHedge_Global_FiltroDataIni");
      if(GlobalVariableCheck("OrionHedge_Global_FiltroDataFim"))
         g_FiltroDataFim = (datetime)GlobalVariableGet("OrionHedge_Global_FiltroDataFim");
      // BUG #7 FIX: Republica os parametros recuperados para garantir consistencia entre
      // todos os pares abertos. Evita desincronizacao quando um grafico abre apos outros.
      PublishGlobalFilterParams();
   }

   // Inicializacao do Relatorio de Lucro Diario
   MqlDateTime md_init;
   TimeToStruct(TimeCurrent(), md_init);
   md_init.hour = 0; md_init.min = 0; md_init.sec = 0;
   g_RepDataFim = StructToTime(md_init);
   g_RepDataIni = g_RepDataFim - (30 * 86400);

   AtualizarCestoBuy();
   AtualizarCestoSell();
   return INIT_SUCCEEDED;
}

double ObterSaldoHistorico(datetime dt) {
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   datetime agora = TimeCurrent();
   if(dt >= agora) return currentBalance;
   
   HistorySelect(dt, agora);
   int total = HistoryDealsTotal();
   double totalChange = 0;
   for(int i = 0; i < total; i++) {
      ulong t = HistoryDealGetTicket(i);
      long type = HistoryDealGetInteger(t, DEAL_TYPE);
      if(type == DEAL_TYPE_BUY || type == DEAL_TYPE_SELL || type == DEAL_TYPE_BALANCE || type == DEAL_TYPE_CREDIT) {
         double p   = HistoryDealGetDouble(t, DEAL_PROFIT);
         double sw  = HistoryDealGetDouble(t, DEAL_SWAP);
         double com = HistoryDealGetDouble(t, DEAL_COMMISSION);
         totalChange += p + sw + com;
      }
   }
   return currentBalance - totalChange;
}

void GerarRelatorioHTML() {
   HistorySelect(g_RepDataIni, g_RepDataFim + 86399);
   int totalDeals = HistoryDealsTotal();
   
   SDiarioLucro dias[];
   int diasCount = 0;
   
   for(int i = 0; i < totalDeals; i++) {
      ulong t = HistoryDealGetTicket(i);
      long type = HistoryDealGetInteger(t, DEAL_TYPE);
      if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL) continue;
      
      datetime dealTime = (datetime)HistoryDealGetInteger(t, DEAL_TIME);
      datetime dia = NormalizarDia(dealTime);
      
      double p   = HistoryDealGetDouble(t, DEAL_PROFIT);
      double sw  = HistoryDealGetDouble(t, DEAL_SWAP);
      double com = HistoryDealGetDouble(t, DEAL_COMMISSION);
      double net = p + sw + com;
      double vol = HistoryDealGetDouble(t, DEAL_VOLUME);
      
      bool found = false;
      if(diasCount > 0 && dias[diasCount - 1].data == dia) {
         dias[diasCount - 1].lucro += net;
         dias[diasCount - 1].volume += vol;
         dias[diasCount - 1].transacoes++;
         found = true;
      }
      
      if(!found) {
         for(int j = 0; j < diasCount - 1; j++) {
            if(dias[j].data == dia) {
               dias[j].lucro += net;
               dias[j].volume += vol;
               dias[j].transacoes++;
               found = true;
               break;
            }
         }
      }
      
      if(!found) {
         ArrayResize(dias, diasCount + 1);
         dias[diasCount].data = dia;
         dias[diasCount].lucro = net;
         dias[diasCount].volume = vol;
         dias[diasCount].transacoes = 1;
         diasCount++;
      }
   }
   
   double lucroAcumulado = 0;
   double volumeAcumulado = 0;
   int transacoesAcumuladas = 0;
   int diasPositivos = 0;
   int diasNegativos = 0;
   
   for(int i = 0; i < diasCount; i++) {
      lucroAcumulado += dias[i].lucro;
      volumeAcumulado += dias[i].volume;
      transacoesAcumuladas += dias[i].transacoes;
      if(dias[i].lucro >= 0) diasPositivos++;
      else diasNegativos++;
   }
   
   // CALCULO DO TWR (Time-Weighted Return) ACUMULADO E SALDO INICIAL
   double accumulatedFactor = 1.0;
   for(int i = 0; i < diasCount; i++) {
      double saldoFimDia = ObterSaldoHistorico(dias[i].data + 86400);
      double baseSaldo = saldoFimDia - dias[i].lucro;
      double pctDia = (baseSaldo > 0) ? (dias[i].lucro / baseSaldo) : 0.0;
      
      double factor = 1.0 + pctDia;
      if(factor < 0.0) factor = 0.0; // Evita fatores negativos em caso de perdas catastróficas
      accumulatedFactor *= factor;
   }
   
   double pctTotalPeriodo = (accumulatedFactor - 1.0) * 100.0;
   double mediaDiariaPct = (diasCount > 0) ? (pctTotalPeriodo / diasCount) : 0.0;

   // Saldo inicial estimado do período para exibição informativa nos KPIs
   double saldoInicialPeriodo = 0;
   if(diasCount > 0) {
      saldoInicialPeriodo = ObterSaldoHistorico(dias[0].data);
      if(saldoInicialPeriodo <= 0) {
         double saldoFimDia = ObterSaldoHistorico(dias[0].data + 86400);
         saldoInicialPeriodo = saldoFimDia - dias[0].lucro;
      }
   }
   if(saldoInicialPeriodo <= 0) {
      saldoInicialPeriodo = ObterSaldoHistorico(g_RepDataIni);
   }
   if(saldoInicialPeriodo <= 0) {
      saldoInicialPeriodo = AccountInfoDouble(ACCOUNT_BALANCE);
   }

   // Calcular total de depósitos no período para o Retorno de Caixa (Cash-on-Cash)
   double totalDepositosPeriodo = 0.0;
   for(int i = 0; i < totalDeals; i++) {
      ulong t = HistoryDealGetTicket(i);
      long type = HistoryDealGetInteger(t, DEAL_TYPE);
      if(type == DEAL_TYPE_BALANCE) {
         double p = HistoryDealGetDouble(t, DEAL_PROFIT);
         if(p > 0) totalDepositosPeriodo += p;
      }
   }
   double capitalTotalComprometido = saldoInicialPeriodo + totalDepositosPeriodo;
   double pctRetornoCaixa = (capitalTotalComprometido > 0) ? (lucroAcumulado / capitalTotalComprometido * 100.0) : 0.0;

   int handle = FileOpen("Orion_Historico_Lucro.html", FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE) {
      AddLog("Erro ao criar arquivo HTML de relatorio.");
      return;
   }

   FileWrite(handle, "<!DOCTYPE html>");
   FileWrite(handle, "<html lang=\"pt-BR\">");
   FileWrite(handle, "<head>");
   FileWrite(handle, "<meta charset=\"UTF-8\">");
   FileWrite(handle, "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">");
   FileWrite(handle, "<title>Orion Hedge &mdash; Historico de Performance Diaria</title>");
   FileWrite(handle, "<style>");
   FileWrite(handle, "  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;600&display=swap');");
   FileWrite(handle, "  *{box-sizing:border-box;margin:0;padding:0}");
   FileWrite(handle, "  :root{");
   FileWrite(handle, "    --bg:#0b0d11;--bg2:#10141a;--bg3:#141820;--card:#161c26;");
   FileWrite(handle, "    --border:#1e2632;--border2:#2a3448;");
   FileWrite(handle, "    --teal:#1caa70;--teal-dim:#0f4a2e;");
   FileWrite(handle, "    --red:#d24444;--red-dim:#410e0e;");
   FileWrite(handle, "    --amber:#e09b00;--blue:#3490ee;--purple:#8c50dc;");
   FileWrite(handle, "    --txt:#e6ecf8;--txt2:#6c7687;--txt3:#3c4450;");
   FileWrite(handle, "    --green:#00c853;--green2:#00b248;");
   FileWrite(handle, "  }");
   FileWrite(handle, "  body{font-family:'Inter',sans-serif;background:var(--bg);color:var(--txt);min-height:100vh;padding:20px}");
   FileWrite(handle, "  h1{font-size:22px;font-weight:700;color:var(--txt);letter-spacing:-0.5px}");
   FileWrite(handle, "  h2{font-size:14px;font-weight:600;color:var(--txt2);letter-spacing:1px;text-transform:uppercase;margin-bottom:12px}");
   FileWrite(handle, "  .header{display:flex;align-items:center;gap:12px;margin-bottom:28px;padding:16px 20px;background:var(--bg2);border:1px solid var(--border);border-top:2px solid var(--purple);border-radius:10px}");
   FileWrite(handle, "  .header-icon{width:36px;height:36px;background:linear-gradient(135deg,var(--purple),var(--blue));border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:18px}");
   FileWrite(handle, "  .header-sub{font-size:12px;color:var(--txt2)}");
   FileWrite(handle, "  .card{background:var(--card);border:1px solid var(--border);border-radius:10px;padding:16px 20px;margin-bottom:16px}");
   FileWrite(handle, "  .grid-4{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:16px}");
   FileWrite(handle, "  @media(max-width:800px){.grid-4{grid-template-columns:repeat(2,1fr)}}");
   FileWrite(handle, "  .kpi{background:var(--card);border:1px solid var(--border);border-radius:10px;padding:14px 16px}");
   FileWrite(handle, "  .kpi-label{font-size:11px;color:var(--txt2);text-transform:uppercase;letter-spacing:.8px;margin-bottom:6px}");
   FileWrite(handle, "  .kpi-value{font-size:22px;font-weight:700;font-family:'JetBrains Mono',monospace}");
   FileWrite(handle, "  .kpi-sub{font-size:11px;color:var(--txt2);margin-top:4px}");
   FileWrite(handle, "  .green{color:var(--green)}");
   FileWrite(handle, "  .red{color:var(--red)}");
   FileWrite(handle, "  .amber{color:var(--amber)}");
   FileWrite(handle, "  .blue{color:var(--blue)}");
   FileWrite(handle, "  .white{color:#fff}");
   FileWrite(handle, "  table{width:100%;border-collapse:collapse;font-size:12px}");
   FileWrite(handle, "  th{padding:8px 12px;text-align:left;color:var(--txt2);font-weight:500;font-size:11px;text-transform:uppercase;letter-spacing:.6px;border-bottom:1px solid var(--border)}");
   FileWrite(handle, "  td{padding:10px 12px;border-bottom:1px solid var(--border);font-family:'JetBrains Mono',monospace;font-size:12px}");
   FileWrite(handle, "  tr:last-child td{border-bottom:none}");
   FileWrite(handle, "  tr:nth-child(even){background:rgba(255,255,255,0.015)}");
   FileWrite(handle, "  tr:hover td{background:rgba(140,80,220,.08)}");
   FileWrite(handle, "  .badge{display:inline-block;padding:2px 8px;border-radius:20px;font-size:10px;font-weight:600}");
   FileWrite(handle, "  .badge-large{display:inline-block;padding:4px 12px;border-radius:20px;font-weight:700}");
   FileWrite(handle, "  .badge-large.badge-green{background:rgba(0,200,83,.22);color:#00e676;border:1px solid rgba(0,200,83,.4);font-size:11px}");
   FileWrite(handle, "  .badge-large.badge-red{background:rgba(210,68,68,.22);color:#ff5252;border:1px solid rgba(210,68,68,.4);font-size:11px}");
   FileWrite(handle, "  .badge-green{background:rgba(0,200,83,.15);color:var(--green)}");
   FileWrite(handle, "  .badge-red{background:rgba(210,68,68,.15);color:var(--red)}");
   FileWrite(handle, "  .badge-amber{background:rgba(224,155,0,.15);color:var(--amber)}");
   FileWrite(handle, "</style>");
   FileWrite(handle, "</head>");
   FileWrite(handle, "<body>");
 
   FileWrite(handle, "<div class=\"header\">");
   FileWrite(handle, "  <div class=\"header-icon\">&#128202;</div>");
   FileWrite(handle, "  <div>");
   FileWrite(handle, "    <h1>Orion Hedge &mdash; Relatorio de Lucro Diario Global</h1>");
   string accLogin = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   FileWrite(handle, "    <div class=\"header-sub\">Conta: " + accLogin + " &middot; Relatorio Global (Todos os Ativos) | Periodo: " + TimeToString(g_RepDataIni, TIME_DATE) + " a " + TimeToString(g_RepDataFim, TIME_DATE) + "</div>");
   FileWrite(handle, "  </div>");
   FileWrite(handle, "</div>");
 
   FileWrite(handle, "<div class=\"grid-4\">");
   
   string signTotal = (lucroAcumulado >= 0) ? "+" : "";
   string clrTotal = (lucroAcumulado >= 0) ? "green" : "red";
   double brlTotal = UscToBrl(lucroAcumulado);
   FileWrite(handle, "  <div class=\"kpi\">");
   FileWrite(handle, "    <div class=\"kpi-label\">&#128176; Lucro do Periodo</div>");
   FileWrite(handle, "    <div class=\"kpi-value " + clrTotal + "\">" + signTotal + DoubleToString(lucroAcumulado, 2) + " <small style=\"font-size:12px\">USC</small></div>");
   FileWrite(handle, "    <div class=\"kpi-sub\">Equivalente: R$ " + DoubleToString(brlTotal, 2) + "</div>");
   FileWrite(handle, "  </div>");
   
   string signPct = (pctTotalPeriodo >= 0) ? "+" : "";
   string clrPct = (pctTotalPeriodo >= 0) ? "green" : "red";
   string signCaixa = (pctRetornoCaixa >= 0) ? "+" : "";
   FileWrite(handle, "  <div class=\"kpi\">");
   FileWrite(handle, "    <div class=\"kpi-label\">&#128200; Rentabilidade Acumulada</div>");
   FileWrite(handle, "    <div class=\"kpi-value " + clrPct + "\">" + signPct + DoubleToString(pctTotalPeriodo, 2) + "%</div>");
   FileWrite(handle, "    <div class=\"kpi-sub\">Retorno de Caixa: " + signCaixa + DoubleToString(pctRetornoCaixa, 2) + "% &middot; Inicial: " + DoubleToString(saldoInicialPeriodo, 2) + " USC</div>");
   FileWrite(handle, "  </div>");
   
   string signMedia = (mediaDiariaPct >= 0) ? "+" : "";
   string clrMedia = (mediaDiariaPct >= 0) ? "green" : "red";
   FileWrite(handle, "  <div class=\"kpi\">");
   FileWrite(handle, "    <div class=\"kpi-label\">&#128202; Media Diaria %</div>");
   FileWrite(handle, "    <div class=\"kpi-value " + clrMedia + "\">" + signMedia + DoubleToString(mediaDiariaPct, 2) + "%</div>");
   FileWrite(handle, "    <div class=\"kpi-sub\">Base de dias operados: " + IntegerToString(diasCount) + " dias</div>");
   FileWrite(handle, "  </div>");
   
   double winRateDias = (diasCount > 0) ? ((double)diasPositivos / diasCount * 100.0) : 0.0;
   FileWrite(handle, "  <div class=\"kpi\">");
   FileWrite(handle, "    <div class=\"kpi-label\">&#128197; Aproveitamento de Dias</div>");
   FileWrite(handle, "    <div class=\"kpi-value white\">" + DoubleToString(winRateDias, 1) + "%</div>");
   FileWrite(handle, "    <div class=\"kpi-sub\">" + IntegerToString(diasPositivos) + " Verdes &middot; " + IntegerToString(diasNegativos) + " Vermelhos</div>");
   FileWrite(handle, "  </div>");
   
   FileWrite(handle, "</div>");
 
   FileWrite(handle, "<div class=\"card\">");
   FileWrite(handle, "  <h2>&#128203; Detalhamento dos Lucros por Dia</h2>");
   FileWrite(handle, "  <div style=\"overflow-x:auto\">");
   FileWrite(handle, "    <table>");
   FileWrite(handle, "      <thead>");
   FileWrite(handle, "        <tr>");
   FileWrite(handle, "          <th>Data</th>");
   FileWrite(handle, "          <th>Operacoes</th>");
   FileWrite(handle, "          <th>Volume total</th>");
   FileWrite(handle, "          <th>Lucro (USC)</th>");
   FileWrite(handle, "          <th>Lucro (BRL)</th>");
   FileWrite(handle, "          <th>Retorno %</th>");
   FileWrite(handle, "          <th>Saldo no Dia</th>");
   FileWrite(handle, "          <th>Status</th>");
   FileWrite(handle, "        </tr>");
   FileWrite(handle, "      </thead>");
   FileWrite(handle, "      <tbody>");

   for(int i = 0; i < diasCount; i++) {
      double saldoFimDia = ObterSaldoHistorico(dias[i].data + 86400);
      double baseSaldo = saldoFimDia - dias[i].lucro;
      double pctDia = (baseSaldo > 0) ? (dias[i].lucro / baseSaldo * 100.0) : 0.0;
      double brl = UscToBrl(dias[i].lucro);
      
      string rowColorClass = (dias[i].lucro >= 0) ? "green" : "red";
      string rowBadgeClass = (dias[i].lucro >= 0) ? "badge-green" : "badge-red";
      string rowBadgeText = (dias[i].lucro >= 0) ? "POSITIVO" : "NEGATIVO";
      string sign = (dias[i].lucro >= 0) ? "+" : "";
      string pctSign = (pctDia >= 0) ? "+" : "";
      
      FileWrite(handle, "        <tr>");
      FileWrite(handle, "          <td><b style=\"color:var(--txt)\">" + TimeToString(dias[i].data, TIME_DATE) + "</b></td>");
      FileWrite(handle, "          <td><span class=\"badge badge-amber\">" + IntegerToString(dias[i].transacoes) + " ops</span></td>");
      FileWrite(handle, "          <td>" + DoubleToString(dias[i].volume, 2) + " lotes</td>");
      FileWrite(handle, "          <td class=\"" + rowColorClass + "\" style=\"font-weight:600\">" + sign + DoubleToString(dias[i].lucro, 2) + " USC</td>");
      FileWrite(handle, "          <td class=\"" + rowColorClass + "\" style=\"font-weight:700;font-size:13px;letter-spacing:0.3px\">R$ " + DoubleToString(brl, 2) + "</td>");
      FileWrite(handle, "          <td><span class=\"badge-large " + rowBadgeClass + "\">" + pctSign + DoubleToString(pctDia, 2) + "%</span></td>");
      FileWrite(handle, "          <td>" + DoubleToString(saldoFimDia, 2) + " USC</td>");
      FileWrite(handle, "          <td><span class=\"badge " + rowBadgeClass + "\">" + rowBadgeText + "</span></td>");
      FileWrite(handle, "        </tr>");
   }

   if(diasCount == 0) {
      FileWrite(handle, "        <tr><td colspan=\"8\" style=\"text-align:center;color:var(--txt2);padding:20px\">Nenhuma operacao fechada encontrada no periodo selecionado.</td></tr>");
   }

   FileWrite(handle, "      </tbody>");
   FileWrite(handle, "    </table>");
   FileWrite(handle, "  </div>");
   FileWrite(handle, "</div>");
   FileWrite(handle, "</body>");
   FileWrite(handle, "</html>");
   FileClose(handle);

   if(MQLInfoInteger(MQL_DLLS_ALLOWED)) {
      string filePath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\Orion_Historico_Lucro.html";
      ShellExecuteW(0, "open", filePath, "", "", 1);
      AddLog("Relatorio HTML gerado e aberto com sucesso!");
   } else {
      AddLog("Relatorio gerado em MQL5\\Files\\Orion_Historico_Lucro.html");
      AddLog("Habilite 'Permitir importacao de DLL' para abrir de forma automatica.");
   }
}

void OnDeinit(const int reason) {
   EventKillTimer();
   if(handleATR!=INVALID_HANDLE) IndicatorRelease(handleATR);
   if(handleATR_Long!=INVALID_HANDLE) IndicatorRelease(handleATR_Long);
   if(handleEMA!=INVALID_HANDLE) IndicatorRelease(handleEMA);
   if(handleADXTrend!=INVALID_HANDLE) IndicatorRelease(handleADXTrend);
   // Libera handles do Modo Analise
   if(g_AnaHandleADX    !=INVALID_HANDLE) IndicatorRelease(g_AnaHandleADX);
   if(g_AnaHandleRSI    !=INVALID_HANDLE) IndicatorRelease(g_AnaHandleRSI);
   if(g_AnaHandleMACD   !=INVALID_HANDLE) IndicatorRelease(g_AnaHandleMACD);
   if(g_AnaHandleStoch  !=INVALID_HANDLE) IndicatorRelease(g_AnaHandleStoch);
   if(g_AnaHandleEMA50  !=INVALID_HANDLE) IndicatorRelease(g_AnaHandleEMA50);
   if(g_AnaHandleBB       !=INVALID_HANDLE) IndicatorRelease(g_AnaHandleBB);
   if(g_AnaHandleADX_D1 !=INVALID_HANDLE) IndicatorRelease(g_AnaHandleADX_D1);
   if(g_AnaHandleRSI_D1 !=INVALID_HANDLE) IndicatorRelease(g_AnaHandleRSI_D1);
   if(g_AnaHandleEMA200D1!=INVALID_HANDLE)IndicatorRelease(g_AnaHandleEMA200D1);
   LimparLinhasAnalise();
   LimparIndicadoresAnalise();
   LimparPainel();
   ChartRedraw(0);
}

//===================================================================
// ONTRADE TRANSACTION
//===================================================================
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result) {
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD&&trans.symbol==_Symbol) {
      // [FIX #9] Filtrar por MagicNumber para ignorar trades manuais/outros EAs
      if(HistoryDealSelect(trans.deal)) {
         long mag=HistoryDealGetInteger(trans.deal,DEAL_MAGIC);
         if(trans.deal_type==DEAL_TYPE_BUY && mag==g_MagicBuy)
            { g_AguardandoBuy=false; g_ConfirmBuy=0; }
         if(trans.deal_type==DEAL_TYPE_SELL && mag==g_MagicSell)
            { g_AguardandoSell=false; g_ConfirmSell=0; }
      }
   }
}

//===================================================================
// MONITORAMENTO AUTOMÁTICO DE RESGATE AGENDADO (S.O.S)
//===================================================================
void ProcessarAgendamentoSOS() {
   // Se cesto Buy tem agendamento ativo
   if(g_BuySaidaZeroAtiva) {
      if(g_BuyNivelAtual < 2) {
         SetBuySaidaZeroAtiva(false); // Cancela se não houver recompras
      } else {
         int level; ulong ticket; double loss; double lucroOposto; int magicOposto;
         if(ObterDadosRecompraDirecao(true, level, ticket, loss, lucroOposto, magicOposto)) {
            double absLoss = MathAbs(loss);
            double buffer = MathMax(1.00, absLoss * 0.10);
            if(lucroOposto >= absLoss + buffer) {
               AddLog("[S.O.S AUTOMÁTICO] Executando resgate agendado de COMPRA N" + IntegerToString(level) + " (" + DoubleToString(loss, 2) + " USC) com lucro de VENDA (+" + DoubleToString(lucroOposto, 2) + " USC).");
               
               if(trade.PositionClose(ticket)) {
                  for(int i = PositionsTotal() - 1; i >= 0; i--) {
                     ulong t = PositionGetTicket(i);
                     if(t > 0 && PositionSelectByTicket(t)) {
                        if(PositionGetInteger(POSITION_MAGIC) == magicOposto && PositionGetString(POSITION_SYMBOL) == _Symbol) {
                           trade.PositionClose(t);
                        }
                     }
                  }
                  g_BuyZoneOrigin = 0; g_BuyEmTrailing = false;
                  SetBuySaidaZeroAtiva(false);
                  DesenharPainel();
                  ChartRedraw(0);
               } else {
                  AddLog("[S.O.S AUTOMÁTICO] Erro ao fechar posição de resgate COMPRA N" + IntegerToString(level) + ". Abortando fechamento do cesto oposto.");
               }
            }
         }
      }
   }

   // Se cesto Sell tem agendamento ativo
   if(g_SellSaidaZeroAtiva) {
      if(g_SellNivelAtual < 2) {
         SetSellSaidaZeroAtiva(false); // Cancela se não houver recompras
      } else {
         int level; ulong ticket; double loss; double lucroOposto; int magicOposto;
         if(ObterDadosRecompraDirecao(false, level, ticket, loss, lucroOposto, magicOposto)) {
            double absLoss = MathAbs(loss);
            double buffer = MathMax(1.00, absLoss * 0.10);
            if(lucroOposto >= absLoss + buffer) {
               AddLog("[S.O.S AUTOMÁTICO] Executando resgate agendado de VENDA N" + IntegerToString(level) + " (" + DoubleToString(loss, 2) + " USC) com lucro de COMPRA (+" + DoubleToString(lucroOposto, 2) + " USC).");
               
               if(trade.PositionClose(ticket)) {
                  for(int i = PositionsTotal() - 1; i >= 0; i--) {
                     ulong t = PositionGetTicket(i);
                     if(t > 0 && PositionSelectByTicket(t)) {
                        if(PositionGetInteger(POSITION_MAGIC) == magicOposto && PositionGetString(POSITION_SYMBOL) == _Symbol) {
                           trade.PositionClose(t);
                        }
                     }
                  }
                  g_SellZoneOrigin = 0; g_SellEmTrailing = false;
                  SetSellSaidaZeroAtiva(false);
                  DesenharPainel();
                  ChartRedraw(0);
               } else {
                  AddLog("[S.O.S AUTOMÁTICO] Erro ao fechar posição de resgate VENDA N" + IntegerToString(level) + ". Abortando fechamento do cesto oposto.");
               }
            }
         }
      }
   }
}

//===================================================================
// ONTICK — MOTOR HEDGE
//===================================================================
void OnTick() {
   g_LastTickTime = TimeCurrent();
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) return;

   AtualizarEstadoNoticias();

   // Timeout confirmacoes
   if(g_AguardandoBuy&&g_ConfirmBuy>0&&(TimeCurrent()-g_ConfirmBuy)>=InpConfirmTimeout) {
      g_AguardandoBuy=false; g_ConfirmBuy=0;
   }
   if(g_AguardandoSell&&g_ConfirmSell>0&&(TimeCurrent()-g_ConfirmSell)>=InpConfirmTimeout) {
      g_AguardandoSell=false; g_ConfirmSell=0;
   }

   // [BUG-A2 FIX] Atualiza os sensores de volatilidade (g_ATR_Value) primeiro
   AtualizarSensores();

   // [BUG-A2 FIX] Calcula o TP dinâmico com dados de volatilidade frescos
   if(InpDynamicTP && InpDynamicAtrRef > 0 && g_ATR_Value > 0) {
      double atr_ref_preco = InpDynamicAtrRef * _Point;
      // [v3.24] "Foto Instantanea": detecta candle grande IMEDIATAMENTE
      double range_candle  = iHigh(_Symbol, InpBaseTF, 0) - iLow(_Symbol, InpBaseTF, 0);
      double vol_ref       = MathMax(g_ATR_Value, range_candle);  // so aumenta, nunca diminui
      double ratio_atr     = vol_ref / atr_ref_preco;  // <1 parado, >1 forte
      
      double tp_calc = g_TakeProfitBase * ratio_atr;
      double tp_min  = g_TakeProfitBase * InpDynamicTpFloor;    // ex: 0.35x = 0.53 USC
      double tp_max  = g_TakeProfitBase * InpDynamicTpCeiling;  // ex: 3.0x  = 4.50 USC
      
      if(tp_calc < tp_min) tp_calc = tp_min;
      if(tp_calc > tp_max) tp_calc = tp_max;  // [v3.24] Teto em vez de travar no base
      g_TakeProfitAtual = tp_calc;
   } else {
      g_TakeProfitAtual = g_TakeProfitBase;
   }

   // [BUG-C1 FIX] Atualizar cestos PRIMEIRO para ter dados frescos antes de calcular TP
   AtualizarCestoBuy();
   AtualizarCestoSell();
   
   // Monitoramento automático da saída zero a zero agendada
   ProcessarAgendamentoSOS();
   
   GerenciarTPBuy();
   GerenciarTPSell();
   AtualizarCestoBuy();
   AtualizarCestoSell();

   if(g_BotPaused) return;

   bool ssAtivo=SoftStopAtingido();
   bool spike=AntiSpike();
   bool roll=FiltroRollover();
   int spr=(int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);

   // HEDGE ASSIMETRICO: usa EMA para dar lote maior na direcao da tendencia
   double close1  = iClose(_Symbol,InpTrendTF,1);
   bool   tendBuy = (close1>g_EMA_Value);  // tendencia de alta -> Buy e o favorito
   double step    = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double minV    = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);

   // Lote do cesto favorito (tendencia) = lote cheio
   // Lote do cesto contra-tendencia = InpHedgeLotContraFator * lote base
   double loteContra = MathMax(minV, MathFloor(g_LoteBase*InpHedgeLotContraFator/step)*step);
   double loteBuy    = tendBuy ? g_LoteBase : loteContra;
   double loteSell   = tendBuy ? loteContra : g_LoteBase;

   // SoftStop individual: cada cesto tem seu proprio freio
   bool ssBuyAtivo  = (g_BuyTotal>0  && (g_BuyLucro+g_BuySwap)<-g_SoftStopPorCesto);
   bool ssSellAtivo = (g_SellTotal>0 && (g_SellLucro+g_SellSwap)<-g_SoftStopPorCesto);

   // Apenas Aviso Sonoro e Visual caso limite do cesto seja atingido (nao fecha automaticamente)
   // [v3.29 FIX] Alerta UMA vez por par enquanto houver posicoes — reseta APENAS quando o cesto fechar
   static bool alertBuySent = false;
   if(ssBuyAtivo) {
      if(!alertBuySent) {
         // Alert removido a pedido do usuario
         AddLog("[BUY] ALERTA: SoftStop da cesta Atingido. Cesto flutuando livremente.");
         alertBuySent = true;
      }
   } else if(g_BuyTotal == 0) {
      alertBuySent = false;  // Reseta SOMENTE quando o cesto estiver vazio (fechado)
   }

   static bool alertSellSent = false;
   if(ssSellAtivo) {
      if(!alertSellSent) {
         // Alert removido a pedido do usuario
         AddLog("[SELL] ALERTA: SoftStop da cesta Atingido. Cesto flutuando livremente.");
         alertSellSent = true;
      }
   } else if(g_SellTotal == 0) {
      alertSellSent = false;  // Reseta SOMENTE quando o cesto estiver vazio (fechado)
   }

   // === CESTO COMPRA === [v3.23: aplica cooldown]
   bool ignorarCooldownBuy = (InpCooldownApenasContra && tendBuy);
   bool buyCooldownAtivo = (InpCooldownHabilitado && TimeCurrent() < g_BuyCooldownEnd && !ignorarCooldownBuy) || (TimeCurrent() < g_EquityCycleCooldownEnd);
   if(!ssAtivo&&!ssBuyAtivo&&!spike&&!roll&&spr<=InpMaxSpread&&!buyCooldownAtivo) {
      if(g_BuyTotal==0&&!g_AguardandoBuy) {
         if(!g_NewsActive) {
            double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
            trade.SetExpertMagicNumber(g_MagicBuy);
            g_AguardandoBuy=true; g_ConfirmBuy=TimeCurrent();
            g_BuyLoteInicial=loteBuy;   // [FIX #11] Armazena lote inicial
            string dir_tag=tendBuy?"[TENDENCIA]":"[CONTRA]";
            if(trade.Buy(loteBuy,_Symbol,ask,0,0,"OH_B1"))
               AddLog("[BUY] INICIO "+dir_tag+" Lote:"+DoubleToString(loteBuy,3));
            else { g_AguardandoBuy=false; g_ConfirmBuy=0; }
         }
      }
      else if(g_BuyTotal>0&&g_BuyTotal<InpMaxOrdens) {
         if(!(g_NewsActive && InpFreezeNewLevels)) {
            trade.SetExpertMagicNumber(g_MagicBuy);
            ExecutarGradeBuy();
         }
      }
   } else if(buyCooldownAtivo && g_BuyTotal==0) {
      // Mostra tempo restante de cooldown a cada 10 minutos
      static datetime lastCooldownLogBuy = 0;
      if((TimeCurrent()-lastCooldownLogBuy) >= 600) {
         int restante = (int)((g_BuyCooldownEnd - TimeCurrent()) / 60);
         AddLog("[BUY] Cooldown ativo: "+IntegerToString(restante)+" min restantes.");
         lastCooldownLogBuy = TimeCurrent();
      }
   }

   // === CESTO VENDA === [v3.23: aplica cooldown]
   bool ignorarCooldownSell = (InpCooldownApenasContra && !tendBuy);
   bool sellCooldownAtivo = (InpCooldownHabilitado && TimeCurrent() < g_SellCooldownEnd && !ignorarCooldownSell) || (TimeCurrent() < g_EquityCycleCooldownEnd);
   if(!ssAtivo&&!ssSellAtivo&&!spike&&!roll&&spr<=InpMaxSpread&&!sellCooldownAtivo) {
      if(g_SellTotal==0&&!g_AguardandoSell) {
         if(!g_NewsActive) {
            double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
            trade.SetExpertMagicNumber(g_MagicSell);
            g_SellLoteInicial=loteSell;  // [FIX #11] Armazena lote inicial
            string dir_tag=!tendBuy?"[TENDENCIA]":"[CONTRA]";
            if(trade.Sell(loteSell,_Symbol,bid,0,0,"OH_S1"))
               AddLog("[SELL] INICIO "+dir_tag+" Lote:"+DoubleToString(loteSell,3));
            else { g_AguardandoSell=false; g_ConfirmSell=0; }
         }
      }
      else if(g_SellTotal>0&&g_SellTotal<InpMaxOrdens) {
         if(!(g_NewsActive && InpFreezeNewLevels)) {
            trade.SetExpertMagicNumber(g_MagicSell);
            ExecutarGradeSell();
         }
      }
   } else if(sellCooldownAtivo && g_SellTotal==0) {
      // Mostra tempo restante de cooldown a cada 10 minutos
      static datetime lastCooldownLogSell = 0;
      if((TimeCurrent()-lastCooldownLogSell) >= 600) {
         int restante = (int)((g_SellCooldownEnd - TimeCurrent()) / 60);
         AddLog("[SELL] Cooldown ativo: "+IntegerToString(restante)+" min restantes.");
         lastCooldownLogSell = TimeCurrent();
      }
   }

   // [v3.29] Monitora fases de DD e dispara alertas na transicao entre zonas
   MonitorarFasesDD();
}

//===================================================================
// [v3.29] MONITOR DE FASES DE DRAWDOWN — Alerta UMA vez por transicao
// DD %  : verde <10% | amarelo 10-20% | vermelho >=20%
// SS %  : verde <33% | amarelo 33-66% | vermelho >=66%
//===================================================================
void MonitorarFasesDD() {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0) return;

   // [BUG-A1/BUG-A4 FIX] Calcula o rebaixamento considerando apenas as posições do Orion
   double global_profit = 0, global_swap = 0;
   for(int i = 0; i < PositionsTotal(); i++) {
      ulong tck = PositionGetTicket(i);
      if(tck > 0) {
         long mag = PositionGetInteger(POSITION_MAGIC);
         if(mag >= InpMagicNumberBase && mag <= InpMagicNumberBase + 999999) {
            global_swap   += PositionGetDouble(POSITION_SWAP);
            global_profit += PositionGetDouble(POSITION_PROFIT);
         }
      }
   }
   double global_pnl = global_profit + global_swap;
   double dd_usd = MathMax(0.0, -global_pnl);
   double dd_pct = dd_usd / balance * 100.0;
   double pct_ss = (g_SoftStopAtual > 0) ? MathMin(1.0, dd_usd / g_SoftStopAtual) : 0.0;

   // --- FASE DRAWDOWN % ---
   // [BUG FIX] Implementa Histerese para evitar que o alarme toque sem parar na divisao
   int novaFaseDD = g_DD_FaseAtual;
   if(novaFaseDD == 0) {
      if(dd_pct >= 20.0) novaFaseDD = 2;
      else if(dd_pct >= 10.0) novaFaseDD = 1;
   } else if(novaFaseDD == 1) {
      if(dd_pct >= 20.0) novaFaseDD = 2;
      else if(dd_pct < 8.0) novaFaseDD = 0; // Histerese (8% ao inves de 10%)
   } else if(novaFaseDD == 2) {
      if(dd_pct < 18.0) novaFaseDD = 1; // Histerese (18% ao inves de 20%)
   }

   if(novaFaseDD > g_DD_FaseAtual) {
      if(novaFaseDD == 2)  // Log apenas (Alert removido)
         AddLog("[DD VERMELHO] Drawdown critico: " + DoubleToString(dd_pct,1) +
               "% (" + DoubleToString(dd_usd,2) + " USC) — PERIGO MAXIMO! Par: " + _Symbol);
      AddLog((novaFaseDD==1?"[DD] AMARELO: ":"[DD] VERMELHO: ") +
             DoubleToString(dd_pct,1)+"% | "+DoubleToString(dd_usd,2)+" USC");
      g_DD_FaseAtual = novaFaseDD;
   } else if(novaFaseDD < g_DD_FaseAtual) {
      // BUG #5 FIX: Só loga recuperação se havia DD genuíno (equity estava abaixo do balance)
      // Evita mensagens enganosas de "recuperação" quando um cesto lucrativo fecha e
      // o lucro flutuante some do patrimônio, mas não havia perda real de capital.
      if(g_DD_FaseAtual > 0 && dd_usd > 0)
         AddLog("[DD] Recuperado para zona " + (novaFaseDD==0?"VERDE":"AMARELA") +
                " — " + DoubleToString(dd_pct,1) + "%");
      g_DD_FaseAtual = novaFaseDD;
   }

   // --- FASE SOFTSTOP % ---
   int novaFaseSS = g_SS_FaseAtual;
   if(novaFaseSS == 0) {
      if(pct_ss >= 0.66) novaFaseSS = 2;
      else if(pct_ss >= 0.33) novaFaseSS = 1;
   } else if(novaFaseSS == 1) {
      if(pct_ss >= 0.66) novaFaseSS = 2;
      else if(pct_ss < 0.28) novaFaseSS = 0; // Histerese
   } else if(novaFaseSS == 2) {
      if(pct_ss < 0.61) novaFaseSS = 1; // Histerese
   }

   if(novaFaseSS > g_SS_FaseAtual) {
      if(novaFaseSS == 2)  // Log apenas (Alert removido)
         AddLog("[SS VERMELHO] SoftStop CRITICO: " + DoubleToString(pct_ss*100.0,1) +
               "% do limite (" + DoubleToString(g_SoftStopAtual,0) + " USC) — PERIGO! Par: " + _Symbol);
      AddLog((novaFaseSS==1?"[SS] AMARELO: ":"[SS] VERMELHO: ") +
             DoubleToString(pct_ss*100.0,1)+"% do limite");
      g_SS_FaseAtual = novaFaseSS;
   } else if(novaFaseSS < g_SS_FaseAtual) {
      if(g_SS_FaseAtual > 0)
         AddLog("[SS] Recuperado para zona " + (novaFaseSS==0?"VERDE":"AMARELA") +
                " — " + DoubleToString(pct_ss*100.0,1) + "%");
      g_SS_FaseAtual = novaFaseSS;
   }
}


//===================================================================
// GUI — HELPERS
//===================================================================
void PClear(string id) {
   string t1=PANEL_PREFIX+id; if(ObjectFind(0,t1)>=0) ObjectSetString(0,t1,OBJPROP_TEXT,"");
   string t2=PANEL_PREFIX+"R_"+id; if(ObjectFind(0,t2)>=0) ObjectSetString(0,t2,OBJPROP_TEXT,"");
   string t3=PANEL_PREFIX+id+"_l"; if(ObjectFind(0,t3)>=0) ObjectSetString(0,t3,OBJPROP_TEXT,"");
   string t4=PANEL_PREFIX+id+"_v"; if(ObjectFind(0,t4)>=0) ObjectSetString(0,t4,OBJPROP_TEXT,"");
}
void PRect(string nm,int x,int y,int w,int h,color bg,long brd=-1,int z=200,bool back=false){
   string n=PANEL_PREFIX+nm;
   if(ObjectFind(0,n)<0)ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,n,OBJPROP_COLOR,brd>=0?(color)brd:bg);ObjectSetInteger(0,n,OBJPROP_WIDTH,brd>=0?1:0);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(0,n,OBJPROP_BACK,back);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);ObjectSetInteger(0,n,OBJPROP_ZORDER,z);
}
void PLabel(string nm,int x,int y,string txt,color clr,int sz=9,bool bold=false){
   string n=PANEL_PREFIX+nm;
   if(ObjectFind(0,n)<0)ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,n,OBJPROP_TEXT,txt);ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetString(0,n,OBJPROP_FONT,bold?"Arial Bold":"Arial");ObjectSetInteger(0,n,OBJPROP_FONTSIZE,sz);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(0,n,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_BACK,false);ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);ObjectSetInteger(0,n,OBJPROP_ZORDER,250);
}
void PLabelR(string nm,int x,int y,string txt,color clr,int sz=9,bool bold=false){
   string n=PANEL_PREFIX+"R_"+nm;
   if(ObjectFind(0,n)<0)ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,n,OBJPROP_TEXT,txt);ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetString(0,n,OBJPROP_FONT,bold?"Arial Bold":"Arial");ObjectSetInteger(0,n,OBJPROP_FONTSIZE,sz);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(0,n,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_BACK,false);ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);ObjectSetInteger(0,n,OBJPROP_ZORDER,250);
}
void PButton(string nm,int x,int y,int w,int h,string txt,color bg,color clr){
   string n=PANEL_PREFIX+nm;
   if(ObjectFind(0,n)<0)ObjectCreate(0,n,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x);ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w);ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetString(0,n,OBJPROP_TEXT,txt);ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,n,OBJPROP_COLOR,clr);ObjectSetString(0,n,OBJPROP_FONT,"Arial Bold");
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,8);ObjectSetInteger(0,n,OBJPROP_STATE,false);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);ObjectSetInteger(0,n,OBJPROP_ZORDER,300);
}
void PRow(string id,int lx,int rx,int y,string lbl,string val,color cv){
   PLabel(id+"_l",lx,y,lbl,CLR_TXT_LABEL,9);PLabelR(id+"_v",rx,y,val,cv,9);
}
void PSect(string id,int px,int y,int pw,string lbl,color ac){
   int pad=10,lw=(int)StringLen(lbl)*6+12;
   PRect(id+"_la",px+pad,y+5,3,1,ac,-1,212);PRect(id+"_bg",px+pad+6,y+1,lw,12,ac,-1,212);
   PLabel(id+"_tx",px+pad+10,y+2,lbl,CLR_BG_BASE,7,true);
   PRect(id+"_lb",px+pad+6+lw+3,y+5,pw-(pad*2)-lw-20,1,CLR_LINE_SOFT,-1,212);
}
// Barra de progresso horizontal (fundo + fill proporcional, 0.0~1.0)
void PBar(string nm, int x, int y, int w, int bh, double pct, color bgClr, color fillClr) {
   PRect(nm+"_bg",   x, y, w, bh, bgClr, -1, 204);
   int fw = (int)MathRound(MathMin(1.0, MathMax(0.0, pct)) * (double)w);
   if(fw > 1) PRect(nm+"_fill", x, y, fw, bh, fillClr, -1, 206);
   else        PRect(nm+"_fill", x, y, 1,  1,  bgClr,  -1, 206);
}
// Barra bidirecional (Termometro de Guerra: -1.0 a 1.0)
void PBiBar(string nm, int x, int y, int w, int bh, double pct, color bgClr, color posClr, color negClr) {
   PRect(nm+"_bg", x, y, w, bh, bgClr, -1, 204);
   double safePct = MathMax(-1.0, MathMin(1.0, pct));
   int halfW = w / 2;
   int cx = x + halfW;
   PRect(nm+"_zero", cx, y, 1, bh, clrGray, -1, 208); // Marca central
   
   if(safePct > 0) {
      int fw = (int)MathRound(safePct * (double)halfW);
      if(fw > 0) PRect(nm+"_fill", cx, y, fw, bh, posClr, -1, 206);
      else       PRect(nm+"_fill", cx, y, 1,  1,  bgClr,  -1, 206);
   } else if(safePct < 0) {
      int fw = (int)MathRound(MathAbs(safePct) * (double)halfW);
      if(fw > 0) PRect(nm+"_fill", cx - fw, y, fw, bh, negClr, -1, 206);
      else       PRect(nm+"_fill", cx, y, 1,  1,  bgClr,  -1, 206);
   } else {
      PRect(nm+"_fill", cx, y, 1, 1, bgClr, -1, 206);
   }
}
// Caixinhas de nivel da grade: maxN boxes, filledN preenchidas
void PGradeBar(string prefix, int x, int y, int totalW, int bh, int maxN, int filledN, color cFill, color cEmpty) {
   if(maxN <= 0) return;
   int boxW = (totalW - (maxN-1)*2) / maxN;
   if(boxW < 4) boxW = 4;
   int filledClamped = (int)MathMin(filledN, maxN);
   for(int i = 0; i < maxN; i++) {
      bool f = (i < filledClamped);
      PRect(prefix+"_b"+IntegerToString(i), x+i*(boxW+2), y, boxW, bh,
            f ? cFill : cEmpty, f ? cFill : CLR_LINE_SOFT, 210);
   }
}

//===================================================================
// LIMPAR PAINEL
//===================================================================
void LimparPainel() {
   for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--){
      string nm=ObjectName(0,i,0,-1);
      if(StringFind(nm,PANEL_PREFIX)==0) ObjectDelete(0,nm);
   }
   ChartRedraw(0);
}

//===================================================================
// LIMPAR MINI PAINEL S.O.S (por instancia, prefixo "sb_" ou "ss_")
//===================================================================
void LimparPainelSOS(string pfx) {
   for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--) {
      string nm=ObjectName(0,i,0,-1);
      if(StringFind(nm,PANEL_PREFIX+pfx)==0 || StringFind(nm,PANEL_PREFIX+"R_"+pfx)==0) ObjectDelete(0,nm);
   }
}

//===================================================================

//===================================================================
// STATUS DE SESSAO DE MERCADO (usa as sessoes reais configuradas pelo broker)
//===================================================================
bool ObterStatusSessaoMercado(bool &aberto, datetime &proximaTransicao) {
   datetime agora = TimeTradeServer();
   MqlDateTime dtAgora;
   TimeToStruct(agora, dtAgora);

   for(int dayOffset = 0; dayOffset <= 7; dayOffset++) {
      datetime diaBase = agora - (dtAgora.hour*3600 + dtAgora.min*60 + dtAgora.sec) + (dayOffset * 86400);
      MqlDateTime dtDia;
      TimeToStruct(diaBase, dtDia);
      ENUM_DAY_OF_WEEK diaSemana = (ENUM_DAY_OF_WEEK)dtDia.day_of_week;

      for(uint i = 0; i < 5; i++) {
         datetime from, to;
         if(!SymbolInfoSessionTrade(_Symbol, diaSemana, i, from, to)) break;
         long fromSec = (long)(from - D'1970.01.01 00:00:00');
         long toSec   = (long)(to   - D'1970.01.01 00:00:00');
         datetime sessFrom = (datetime)(diaBase + fromSec);
         datetime sessTo   = (datetime)(diaBase + toSec);

         if(dayOffset == 0 && agora >= sessFrom && agora < sessTo) {
            aberto = true;
            proximaTransicao = sessTo;
            return true;
         }
         if(sessFrom > agora) {
            aberto = false;
            proximaTransicao = sessFrom;
            return true;
         }
      }
   }
   aberto = false;
   proximaTransicao = 0;
   return false;
}

//===================================================================
//===================================================================
// FORMATAR DURACAO EM TEXTO COMPACTO (Xd Yh / Yh Zmin / Zmin)
//===================================================================
string FormatDuracao(long segundos) {
   if(segundos < 0) segundos = 0;
   long dias  = segundos / 86400;
   long horas = (segundos % 86400) / 3600;
   long mins  = (segundos % 3600) / 60;
   if(dias > 0) return IntegerToString(dias) + "d " + IntegerToString(horas) + "h";
   if(horas > 0) return IntegerToString(horas) + "h " + IntegerToString(mins) + "min";
   return IntegerToString(mins) + "min";
}

//===================================================================
// WIDGET DE STATUS (CANTO SUPERIOR DIREITO): conexao + sessao de mercado
//===================================================================
void DesenharWidgetStatus() {
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int w = 155, pad = 8;
   int margemDireita = 58; // espaco para nao invadir a escala de precos do grafico
   int x = chartW - w - margemDireita;
   if(x < 0) x = 0;
   int topo = 20 + g_AnaliseLegendHeight;
   int lx = x + pad;
   int rx = x + w - pad;
   int cur = topo;

   color cardBg = C'20,25,33';      // Fundo cinza escuro
   color cardBorder = C'45,52,65';  // Borda cinza azulada discreta

   PRect("st_border", x-1, cur-1, w+2, g_StatusWidgetHeight+2, cardBorder, cardBorder, 198);
   PRect("st_bg",      x,   cur,   w,   g_StatusWidgetHeight,   cardBg,     -1,         199);
   cur += 8;

   long semTick = (g_LastTickTime > 0) ? (long)(TimeTradeServer() - g_LastTickTime) : 0;
   bool mercadoAberto = false;
   datetime proxTransicao = 0;
   bool sessaoOk = ObterStatusSessaoMercado(mercadoAberto, proxTransicao);

   bool alertaSemTick = (mercadoAberto && g_LastTickTime > 0 && semTick >= 30);

   color statusClr = alertaSemTick ? C'210,68,68' : C'46,204,113';
   string statusTxt = alertaSemTick ? "SEM TICKS" : "EA ONLINE";

   PRect("st_dot", lx, cur+3, 5, 5, statusClr, -1, 250);
   PLabel("st_online", lx+10, cur, statusTxt, statusClr, 8, true);

   string tickAgeTxt = "tick " + IntegerToString(semTick) + "s";
   if(semTick >= 86400) tickAgeTxt = "tick >1d";
   else if(semTick >= 3600) tickAgeTxt = "tick >1h";
   color tickAgeClr = alertaSemTick ? C'210,68,68' : CLR_TXT_LABEL;
   PLabelR("st_tickage", rx, cur, tickAgeTxt, tickAgeClr, 8, false);
   cur += 15;

   if(!sessaoOk) {
      PRow("st_sessao", lx, rx, cur, "MERCADO:", "INDISPONIVEL", CLR_TXT_DIM); cur += 12;
      PRow("st_transicao", lx, rx, cur, "", "", CLR_TXT_DIM); cur += 12;
   } else if(mercadoAberto) {
      PRow("st_sessao", lx, rx, cur, "MERCADO:", "ABERTO", C'46,204,113'); cur += 12;
      PRow("st_transicao", lx, rx, cur, "FECHA EM:", FormatDuracao((long)(proxTransicao-TimeTradeServer())), CLR_AMBER); cur += 12;
   } else {
      PRow("st_sessao", lx, rx, cur, "MERCADO:", "FECHADO", C'210,68,68'); cur += 12;
      PRow("st_transicao", lx, rx, cur, "ABRE EM:", FormatDuracao((long)(proxTransicao-TimeTradeServer())), CLR_AMBER); cur += 12;
   }

   g_StatusWidgetHeight = cur - topo + 4;
   ObjectSetInteger(0, PANEL_PREFIX+"st_border", OBJPROP_YSIZE, g_StatusWidgetHeight+2);
   ObjectSetInteger(0, PANEL_PREFIX+"st_bg",     OBJPROP_YSIZE, g_StatusWidgetHeight);
}

//===================================================================
// DESENHAR PAINEL — ESTILO ORIGINAL V3.22
//===================================================================
// LIMPAR CONTEUDO (mantém header/border/botoes) — fix sobreposição
void LimparConteudoPainel() {
   for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--) {
      string nm=ObjectName(0,i,0,-1);
      if(StringFind(nm,PANEL_PREFIX)==0)
         if(StringFind(nm,"hdr_")<0 && StringFind(nm,"border")<0 &&
            StringFind(nm,"bg_main")<0 && StringFind(nm,"btn_cfg")<0 &&
            StringFind(nm,"btn_min")<0)
            ObjectDelete(0,nm);
   }
}
//===================================================================
string FormatUSC(double val, bool showSign = false) {
   long integer_val = (long)MathRound(val);
   string raw = IntegerToString(integer_val);
   bool isNeg = (integer_val < 0);
   if(isNeg) raw = StringSubstr(raw, 1);
   
   string res = "";
   int len = StringLen(raw);
   int count = 0;
   
   for(int i = len - 1; i >= 0; i--) {
      if(count > 0 && count % 3 == 0) {
         res = "." + res;
      }
      res = StringSubstr(raw, i, 1) + res;
      count++;
   }
   
   if(isNeg) res = "-" + res;
   else if(showSign && integer_val > 0) res = "+" + res;
   return res;
}
//===================================================================
string FormatBRL(double val) {
   bool isNeg = (val < -0.005);
   double absVal = MathAbs(val);
   long integer_part = (long)absVal;
   int fractional_part = (int)MathRound((absVal - integer_part) * 100.0);
   if(fractional_part >= 100) {
      integer_part += 1;
      fractional_part -= 100;
   }
   
   string raw_int = IntegerToString(integer_part);
   string res_int = "";
   int len = StringLen(raw_int);
   int count = 0;
   
   for(int i = len - 1; i >= 0; i--) {
      if(count > 0 && count % 3 == 0) {
         res_int = "." + res_int;
      }
      res_int = StringSubstr(raw_int, i, 1) + res_int;
      count++;
   }
   
   string res_frac = StringFormat("%02d", fractional_part);
   
   string signStr = "";
   if(isNeg) signStr = "-";
   
   return "R$ " + signStr + res_int + "," + res_frac;
}
//===================================================================
// OBTER COTACAO USD/BRL VIA API WEB (AWESOMEAPI)
//===================================================================
double GetUSDBRLFromAPI() {
   char data[], result[];
   string result_headers;
   string url = "https://economia.awesomeapi.com.br/json/last/USD-BRL";
   
   // WebRequest necessita que a URL "https://economia.awesomeapi.com.br"
   // esteja cadastrada nas Opções do MT5 -> Expert Advisors
   ResetLastError();
   int res = WebRequest("GET", url, "", 3000, data, result, result_headers);
   
   if(res == 200 && ArraySize(result) > 0) {
      string json = CharArrayToString(result, 0, -1, CP_UTF8);
      int pos = StringFind(json, "\"bid\":");
      if(pos < 0) pos = StringFind(json, "\"bid\" :");
      if(pos >= 0) {
         int valStart = StringFind(json, "\"", pos + 5) + 1;
         if(valStart > 0) {
            int valEnd = StringFind(json, "\"", valStart);
            if(valEnd > valStart) {
               string valStr = StringSubstr(json, valStart, valEnd - valStart);
               double val = StringToDouble(valStr);
               if(val > 3.0 && val < 10.0) {
                  return val;
               }
            }
         }
      }
   } else {
      int err = _LastError;
      static datetime lastLogTime = 0;
      if(TimeCurrent() - lastLogTime > 600) {
         lastLogTime = TimeCurrent();
         if(res == -1) {
            Print("[USD/BRL WEB] WebRequest falhou (Erro MQL5 ", err, "). Para atualizar a conversão em R$ dinamicamente com o Dólar real, adicione a URL 'https://economia.awesomeapi.com.br' no menu Ferramentas -> Opcoes -> Expert Advisors -> Permitir WebRequest.");
         } else {
            Print("[USD/BRL WEB] API retornou erro HTTP: ", res);
         }
      }
   }
   return 0;
}

//===================================================================
// OBTER TAXA BRL DINAMICA (USD/BRL)
//===================================================================
double ObterTaxaBRLDinamica() {
   // 1. Tenta obter a cotação em tempo real via API Web
   double apiBid = GetUSDBRLFromAPI();
   if(apiBid > 0) {
      return apiBid;
   }
   
   // 2. Se falhar, tenta buscar nomes de símbolos USDBRL comuns no broker
   string commonNames[] = {"USDBRL", "USDBRLc", "USDBRLm", "USDBRL_ec", "USDBRL_i", "USDBRL_k"};
   int numNames = ArraySize(commonNames);
   
   for(int i = 0; i < numNames; i++) {
      string sym = commonNames[i];
      if(SymbolSelect(sym, true)) {
         double bid = SymbolInfoDouble(sym, SYMBOL_BID);
         if(bid <= 0) {
            bid = SymbolInfoDouble(sym, SYMBOL_LAST);
         }
         if(bid <= 0) {
            MqlRates rates[];
            if(CopyRates(sym, PERIOD_M1, 0, 1, rates) > 0) {
               bid = rates[0].close;
            }
         }
         if(bid > 0) {
            return bid;
         }
      }
   }
   
   // Se falhar a busca direta, tenta varrer a lista de símbolos
   string symbolFound = "";
   int totalSymbols = SymbolsTotal(false);
   for(int i = 0; i < totalSymbols; i++) {
      string symName = SymbolName(i, false);
      string symUpper = symName;
      StringToUpper(symUpper);
      if(StringFind(symUpper, "USDBRL") >= 0) {
         symbolFound = symName;
         break;
      }
   }
   
   if(symbolFound != "") {
      if(SymbolSelect(symbolFound, true)) {
         double bid = SymbolInfoDouble(symbolFound, SYMBOL_BID);
         if(bid <= 0) {
            bid = SymbolInfoDouble(symbolFound, SYMBOL_LAST);
         }
         if(bid <= 0) {
            MqlRates rates[];
            if(CopyRates(symbolFound, PERIOD_M1, 0, 1, rates) > 0) {
               bid = rates[0].close;
            }
         }
         if(bid > 0) {
            return bid;
         }
      }
   }
   
   // Se tudo falhar, gera relatório de diagnóstico para descobrirmos os nomes dos símbolos BRL (apenas uma vez para economizar disco)
   static bool diagnosticWritten = false;
   if(!diagnosticWritten) {
      int fileHandle = FileOpen("orion_brl_symbols.txt", FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(fileHandle != INVALID_HANDLE) {
         FileWriteString(fileHandle, "=== DIAGNOSTICO DE SIMBOLOS BRL ===\n");
         FileWriteString(fileHandle, "Total de simbolos: " + IntegerToString(totalSymbols) + "\n");
         for(int i = 0; i < totalSymbols; i++) {
            string symName = SymbolName(i, false);
            string symUpper = symName;
            StringToUpper(symUpper);
            if(StringFind(symUpper, "BRL") >= 0) {
               FileWriteString(fileHandle, "Simbolo com BRL: " + symName + "\n");
            }
         }
         FileClose(fileHandle);
      }
      diagnosticWritten = true;
   }
   
   return InpTaxaBRL;
}

// Converte USC (centavos) para BRL
double UscToBrl(double v) { return (v / 100.0) * g_TaxaBRLAtual; }
//===================================================================
void DesenharPainel() {
   int px=20,py=20,pw=340,pad=10;
   int lx=px+pad+4,rx=px+pw-pad;
   int cur=py;
   int thm_w=pw-(pad*2)-8;

   // [FIX v3.24] Inicializacao: limpa TUDO no primeiro frame para eliminar ghosts
   if(!g_PanelInited) { LimparPainel(); g_PanelInited=true; }

   // Limpa conteudo ao trocar de modo (evita flicker)
   if(g_ShowSettings != g_LastShowSettings) LimparConteudoPainel();
   g_LastShowSettings = g_ShowSettings;

   PRect("border",px-1,py-1,pw+2,g_PanelHeight+2,CLR_LINE_HARD,CLR_LINE_HARD,198);
   PRect("bg_main",px,py,pw,g_PanelHeight,CLR_BG_BASE,-1,199);

   //=======================================================  HEADER
   PRect("hdr_bg",px,cur,pw,40,CLR_BG_HEADER,-1,200);
   PRect("hdr_top",px,cur,pw,2,CLR_BLUE,-1,201); cur+=2;
   PLabel("hdr_ico",px+pad,cur+7,"*",CLR_BLUE,11,true);
   PLabel("hdr_title",px+pad+16,cur+7,"ORION HEDGE v3.40",CLR_TXT_PRIMARY,10,true);  // [v3.40] Trailing de Patrimonio Ajustado | Layout Premium
   PLabel("hdr_ver",px+pad+16,cur+20,_Symbol+(g_BotPaused?"  [PAUSADO]":"  . Pro Hedge")+"  [USD/BRL: "+DoubleToString(g_TaxaBRLAtual,2)+"]",
          g_BotPaused?CLR_RED:CLR_AMBER,7);
   PButton("btn_cfg",rx-40,cur+7,18,18,g_ShowSettings?"X":"S",CLR_BG_CARD,g_ShowSettings?CLR_AMBER:CLR_TXT_LABEL);
   PButton("btn_min",rx-18,cur+7,18,18,g_Minimized?"v":"^",CLR_BG_CARD,CLR_TXT_LABEL);
   cur+=40;

   //=======================================================  MINIMIZADO
   if(g_Minimized) {
      g_PanelHeight=cur-py;
      ObjectSetInteger(0,PANEL_PREFIX+"border",OBJPROP_YSIZE,g_PanelHeight+2);
      ObjectSetInteger(0,PANEL_PREFIX+"bg_main",OBJPROP_YSIZE,g_PanelHeight);
      if(!g_MinimizedCleaned) {
         for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--) {
            string delnm=ObjectName(0,i,0,-1);
            if(StringFind(delnm,PANEL_PREFIX)==0)
               if(StringFind(delnm,"hdr_")<0&&StringFind(delnm,"border")<0&&
                  StringFind(delnm,"bg_main")<0&&StringFind(delnm,"btn_min")<0&&
                  StringFind(delnm,"btn_cfg")<0)
                  ObjectDelete(0,delnm);
         }
         g_MinimizedCleaned=true;
      }
      return;
   }
   g_MinimizedCleaned=false;

    //=======================================================  TELA CONFIGURACAO
   if(g_ShowSettings) {
      // ----- HISTÓRICO DE LUCRO (NOVO) -----
      PSect("cfg_rep_sec",px,cur,pw,"HISTORICO DE LUCRO (RELATORIO)",CLR_PURPLE); cur+=22;
      
      // Decompoem a data de inicio do relatorio
      MqlDateTime mdt_start; TimeToStruct(g_RepDataIni, mdt_start);
      string sDiaS = StringFormat("%02d", mdt_start.day);
      string sMesS = StringFormat("%02d", mdt_start.mon);
      string sAnoS = IntegerToString(mdt_start.year);
      
      // Decompoem a data de fim do relatorio
      MqlDateTime mdt_end; TimeToStruct(g_RepDataFim, mdt_end);
      string sDiaE = StringFormat("%02d", mdt_end.day);
      string sMesE = StringFormat("%02d", mdt_end.mon);
      string sAnoE = IntegerToString(mdt_end.year);
      
      int aw = 18; // largura dos botoes seta
      int vw = 38; // largura do valor central
      int gp = 6;  // gap entre grupos
      int x1 = lx;
      int x2 = lx + aw*2 + vw + gp;
      int x3 = lx + (aw*2 + vw + gp)*2;
      
      // Linha de labels data inicio
      PLabel("cfg_rep_lds", x1+aw, cur, "DIA", C'50,60,75', 7);
      PLabel("cfg_rep_lms", x2+aw, cur, "MES", C'50,60,75', 7);
      PLabel("cfg_rep_las", x3+aw, cur, "ANO", C'50,60,75', 7);
      PLabel("cfg_rep_lbl_start", lx+180, cur, "DATA INICIAL", CLR_TXT_DIM, 7); cur+=10;
      
      // Setas e valores - DATA INICIO
      PButton("btn_rep_sdm", x1,       cur, aw, 18, "<", C'20,28,42', CLR_TXT_DIM);
      PButton("btn_rep_sdv", x1+aw,    cur, vw, 18, sDiaS, C'12,18,28', clrWhite);
      PButton("btn_rep_sdp", x1+aw+vw, cur, aw, 18, ">", C'20,28,42', CLR_TXT_DIM);
      
      PButton("btn_rep_smm", x2,       cur, aw, 18, "<", C'20,28,42', CLR_TXT_DIM);
      PButton("btn_rep_smv", x2+aw,    cur, vw, 18, sMesS, C'12,18,28', clrWhite);
      PButton("btn_rep_smp", x2+aw+vw, cur, aw, 18, ">", C'20,28,42', CLR_TXT_DIM);
      
      PButton("btn_rep_sym", x3,       cur, aw, 18, "<", C'20,28,42', CLR_TXT_DIM);
      PButton("btn_rep_syv", x3+aw,    cur, vw, 18, sAnoS, C'12,18,28', clrWhite);
      PButton("btn_rep_syp", x3+aw+vw, cur, aw, 18, ">", C'20,28,42', CLR_TXT_DIM);
      cur+=22;
      
      // Linha de labels data fim
      PLabel("cfg_rep_lde", x1+aw, cur, "DIA", C'50,60,75', 7);
      PLabel("cfg_rep_lme", x2+aw, cur, "MES", C'50,60,75', 7);
      PLabel("cfg_rep_lae", x3+aw, cur, "ANO", C'50,60,75', 7);
      PLabel("cfg_rep_lbl_end", lx+180, cur, "DATA FINAL", CLR_TXT_DIM, 7); cur+=10;
      
      // Setas e valores - DATA FIM
      PButton("btn_rep_edm", x1,       cur, aw, 18, "<", C'20,28,42', CLR_TXT_DIM);
      PButton("btn_rep_edv", x1+aw,    cur, vw, 18, sDiaE, C'12,18,28', clrWhite);
      PButton("btn_rep_edp", x1+aw+vw, cur, aw, 18, ">", C'20,28,42', CLR_TXT_DIM);
      
      PButton("btn_rep_emm", x2,       cur, aw, 18, "<", C'20,28,42', CLR_TXT_DIM);
      PButton("btn_rep_emv", x2+aw,    cur, vw, 18, sMesE, C'12,18,28', clrWhite);
      PButton("btn_rep_emp", x2+aw+vw, cur, aw, 18, ">", C'20,28,42', CLR_TXT_DIM);
      
      PButton("btn_rep_eym", x3,       cur, aw, 18, "<", C'20,28,42', CLR_TXT_DIM);
      PButton("btn_rep_eyv", x3+aw,    cur, vw, 18, sAnoE, C'12,18,28', clrWhite);
      PButton("btn_rep_eyp", x3+aw+vw, cur, aw, 18, ">", C'20,28,42', CLR_TXT_DIM);
      cur+=22;
      
      // Botao para Gerar Relatorio HTML
      PButton("btn_rep_gen", lx+4, cur, pw-pad*2-18, 22, "GERAR RELATORIO EM HTML", C'25,50,90', clrWhite);
      cur+=28;
      
      // Botao para Enviar Resumo p/ Telegram
      PButton("btn_rep_push", lx+4, cur, pw-pad*2-18, 22, "ENVIAR NOTIFICACAO PUSH", C'0,110,180', clrWhite);
      cur+=28;
      
      // Linha divisoria
      PRect("cfg_rep_div",px+pad,cur,pw-(pad*2),1,CLR_LINE_SOFT,-1,210); cur+=10;

      // ----- FILTRO DO LUCRO GLOBAL (TOPO) -----
      PSect("cfg_flt_sec",px,cur,pw,"FILTRO DO LUCRO GLOBAL",CLR_BLUE); cur+=22;
      
      // 5 botoes abreviados para caber na linha
      string fAbr[] = {"TUDO","7D","30D","M.AT","CUST"};
      int fBtnW = (thm_w-4)/5;
      for(int fi=0; fi<5; fi++) {
         color fBg2 = (g_FiltroHistorico==fi) ? C'15,55,35' : C'18,25,38';
         color fTx2 = (g_FiltroHistorico==fi) ? C'0,200,83' : CLR_TXT_DIM;
         PButton("btn_flt_"+IntegerToString(fi),lx+fi*(fBtnW+1),cur,fBtnW,16,fAbr[fi],fBg2,fTx2);
      }
      cur+=22;
      
      // Seletor de data com navegacao por dia/mes/ano (modo CUST)
      if(g_FiltroHistorico == 4) {
         if(g_FiltroDataIni == 0) {
            MqlDateTime md; TimeToStruct(TimeCurrent(), md);
            md.hour = 0; md.min = 0; md.sec = 0;
            g_FiltroDataIni = StructToTime(md);
         }
         
         // Decompoem a data de inicio
         MqlDateTime mdt; TimeToStruct(g_FiltroDataIni, mdt);
         string sDia = StringFormat("%02d", mdt.day);
         string sMes = StringFormat("%02d", mdt.mon);
         string sAno = IntegerToString(mdt.year);
         
         int aw = 18; // largura dos botoes seta
         int vw = 38; // largura do valor central
         int gp = 6;  // gap entre grupos
         int x1 = lx;
         int x2 = lx + aw*2 + vw + gp;
         int x3 = lx + (aw*2 + vw + gp)*2;
         
         // Linha de labels
         PLabel("cfg_flt_ldl", x1+aw, cur,   "DIA", C'50,60,75', 7);
         PLabel("cfg_flt_lml", x2+aw, cur,   "MES", C'50,60,75', 7);
         PLabel("cfg_flt_lal", x3+aw, cur,   "ANO", C'50,60,75', 7); cur+=10;
         
         // Setas e valores - DIA
         PButton("btn_flt_dm", x1,       cur, aw, 18, "<", C'20,28,42', CLR_TXT_DIM);
         PButton("btn_flt_dv", x1+aw,    cur, vw, 18, sDia, C'12,18,28', clrWhite);
         PButton("btn_flt_dp", x1+aw+vw, cur, aw, 18, ">", C'20,28,42', CLR_TXT_DIM);
         // Setas e valores - MES
         PButton("btn_flt_mm", x2,       cur, aw, 18, "<", C'20,28,42', CLR_TXT_DIM);
         PButton("btn_flt_mv", x2+aw,    cur, vw, 18, sMes, C'12,18,28', clrWhite);
         PButton("btn_flt_mp", x2+aw+vw, cur, aw, 18, ">", C'20,28,42', CLR_TXT_DIM);
         // Setas e valores - ANO
         PButton("btn_flt_ym", x3,       cur, aw, 18, "<", C'20,28,42', CLR_TXT_DIM);
         PButton("btn_flt_yv", x3+aw,    cur, vw, 18, sAno, C'12,18,28', clrWhite);
         PButton("btn_flt_yp", x3+aw+vw, cur, aw, 18, ">", C'20,28,42', CLR_TXT_DIM);
         cur+=22;
         
         PLabel("cfg_flt_dt",lx+4,cur,"De: "+TimeToString(g_FiltroDataIni,TIME_DATE)+"  ate: Agora",CLR_AMBER,8,true); cur+=14;
      } else {
         // Limpa todos os objetos do seletor CUST quando nao estiver ativo
         string custObjs[] = {"cfg_flt_ldl","cfg_flt_lml","cfg_flt_lal",
                               "btn_flt_dm","btn_flt_dv","btn_flt_dp",
                               "btn_flt_mm","btn_flt_mv","btn_flt_mp",
                               "btn_flt_ym","btn_flt_yv","btn_flt_yp",
                               "cfg_flt_dt","cfg_flt_ini_l","cfg_flt_dt"};
         for(int ci=0; ci<ArraySize(custObjs); ci++) ObjectDelete(0,PANEL_PREFIX+custObjs[ci]);
         // Limpa botoes antigos ini_0..5 se existirem
         for(int si=0; si<6; si++) ObjectDelete(0,PANEL_PREFIX+"btn_flt_ini_"+IntegerToString(si));
         cur+=4;
      }
      PRect("cfg_flt_div",px+pad,cur,pw-(pad*2),1,CLR_LINE_SOFT,-1,210); cur+=10;
      
      // ----- GESTAO DE RISCO -----
      PSect("cfg_sec",px,cur,pw,"GESTAO DE RISCO E ACOMPANHAMENTO",CLR_AMBER); cur+=22;
      PLabel("c_mod_l",lx+4,cur,"Modo de Escala:",CLR_TXT_LABEL,9);
      PLabelR("c_mod_v",rx-4,cur,InpAutoLot?"AUTOMATICO":"MANUAL",InpAutoLot?CLR_TEAL:CLR_TXT_PRIMARY,9,true); cur+=14;
      double fatorRender=InpAutoLot?(g_LoteBase/0.01):1.0;
      PLabel("c_prp_l",lx+4,cur,"Multiplicador de Tabela:",CLR_TXT_LABEL,9);
      PLabelR("c_prp_v",rx-4,cur,DoubleToString(fatorRender,2)+"x",CLR_TXT_PRIMARY,9,true); cur+=24;
      // BOX 1
      PRect("bg_lt",lx,cur,pw-pad*2-10,38,CLR_BG_CARD,CLR_LINE_SOFT,205);
      PLabel("c_lt_id",lx+8,cur+10,"1",CLR_TXT_DIM,14,true);
      PLabel("c_lt_t",lx+26,cur+5,"Lote Base (por Cesto)",CLR_TXT_PRIMARY,9,true);
      PLabel("c_lt_d",lx+26,cur+18,"(Semente: "+DoubleToString(InpLotInitial,3)+" | Freio: "+DoubleToString(InpLotDeceleration,2)+")",CLR_TXT_DIM,8);
      PLabelR("c_lt_v",rx-8,cur+11,DoubleToString(g_LoteBase,3)+" Lotes",CLR_TEAL,11,true); cur+=44;
      // BOX 2
      PRect("bg_al",lx,cur,pw-pad*2-10,38,CLR_BG_CARD,CLR_LINE_SOFT,205);
      PLabel("c_al_id",lx+8,cur+10,"2",CLR_TXT_DIM,14,true);
      PLabel("c_al_t",lx+26,cur+4,"Alvo Bidirecional (Cesto)",CLR_TXT_PRIMARY,9,true);
      string tpModeText="Modo Fixo"; color tc=CLR_TXT_DIM;
      if(InpDynamicTP){
         if(g_TakeProfitAtual>g_TakeProfitBase*1.1){tpModeText="TURBO - Mercado Forte!";tc=CLR_TEAL;}
         else if(g_TakeProfitAtual<g_TakeProfitBase*0.9){tpModeText="ECO - Giro Rapido";tc=CLR_AMBER;}
         else{tpModeText="NORMAL - Volatilidade OK";tc=CLR_BLUE;}
      }
      if(g_BuyEmTrailing||g_SellEmTrailing){tpModeText="Trailing Ativo! Rastreando...";tc=CLR_PURPLE;}
      PLabel("c_al_d",lx+26,cur+16,tpModeText,tc,7,true);
      string tpRangeText="Base: "+DoubleToString(InpTakeProfitDinheiro,2)+" | Range: "+DoubleToString(g_TakeProfitBase*InpDynamicTpFloor,2)+"~"+DoubleToString(g_TakeProfitBase*InpDynamicTpCeiling,2)+" USC";
      PLabel("c_al_b",lx+26,cur+26,tpRangeText,CLR_TXT_DIM,7);
      PLabelR("c_al_v",rx-8,cur+11,DoubleToString(g_TakeProfitAtual,2)+" USC",CLR_TEAL,11,true); cur+=44;
      // BOX 3
      PRect("bg_fr",lx,cur,pw-pad*2-10,38,CLR_BG_CARD,CLR_LINE_SOFT,205);
      PLabel("c_fr_id",lx+8,cur+10,"3",CLR_TXT_DIM,14,true);
      PLabel("c_fr_t",lx+26,cur+5,"Freio Drawdown (2 Cestos)",CLR_TXT_PRIMARY,9,true);
      PLabel("c_fr_d",lx+26,cur+19,"("+DoubleToString(InpSoftStopEquity,0)+" USC base)",CLR_TXT_DIM,8);
      PLabelR("c_fr_v",rx-8,cur+11,DoubleToString(g_SoftStopAtual,2)+" USC",CLR_AMBER,11,true); cur+=44;
      // BOX 4
      PRect("bg_nx",lx,cur,pw-pad*2-10,48,CLR_BG_CARD,CLR_LINE_SOFT,205);
      PLabel("c_nx_id",lx+8,cur+15,"4",CLR_TXT_DIM,14,true);
      PLabel("c_nx_t",lx+26,cur+4,"Limite Max. Recompras (por Cesto)",CLR_TXT_PRIMARY,9,true);
      PLabel("c_nx_d",lx+26,cur+17,"(MaxOrdens="+IntegerToString(InpMaxOrdens)+" | Mult: "+DoubleToString(InpLotMultiplier,2)+"x)",CLR_TXT_DIM,8);
      PLabel("c_nx_tf",lx+26,cur+29,"Escala ALVOS: H4, H4, H12, D1, D1... [v3.27]",CLR_AMBER,8);
      PLabelR("c_nx_v",rx-8,cur+15,IntegerToString(InpMaxOrdens)+" Niveis",CLR_TXT_PRIMARY,11,true); cur+=56;
      PRect("cfg_sep",px+pad,cur,pw-(pad*2),1,CLR_LINE_SOFT,-1,210); cur+=8;
      
      cur+=4;
      string ptxtLoc=g_PanicoLocalAguardando?"[!] CONFIRMAR LOCAL?":"[X] ZERAR LOCAL";
      string ptxtGlb=g_PanicoAguardando?"[!] CONFIRMAR GLOBAL?":"[X] PANICO GLOBAL";
      PButton("btn_panic_loc",lx+4,cur,148,24,ptxtLoc,g_PanicoLocalAguardando?CLR_RED_DIM:CLR_BG_BTN_PANIC,CLR_RED);
      PButton("btn_panic_glb",lx+158,cur,148,24,ptxtGlb,g_PanicoAguardando?CLR_RED_DIM:CLR_BG_BTN_PANIC,CLR_RED);
      cur+=30;
      
      PRect("cfg_sep_bot",px+pad,cur,pw-(pad*2),1,CLR_LINE_SOFT,-1,212); cur+=8;

      double bal_cfg=AccountInfoDouble(ACCOUNT_BALANCE);
      PRow("c_b_ref",lx+4,rx-4,cur,"Banca Referencia (BancaRef)",DoubleToString(InpBancaRef,0)+" USC",CLR_TXT_DIM); cur+=12;
      PRow("c_b_cur",lx+4,rx-4,cur,"Banca Atual na Conta",DoubleToString(bal_cfg,2)+" USC",CLR_TXT_DIM); cur+=18;
      PLabel("c_f_1",px+pw/2-100,cur,"Estes sao os parametros REAIS inseridos",CLR_TXT_DIM,8); cur+=11;
      PLabel("c_f_2",px+pw/2-100,cur,"na matematica do robo neste momento.",CLR_TXT_DIM,8); cur+=18;
      g_PanelHeight=cur-py;
      ObjectSetInteger(0,PANEL_PREFIX+"border",OBJPROP_YSIZE,g_PanelHeight+2);
      ObjectSetInteger(0,PANEL_PREFIX+"bg_main",OBJPROP_YSIZE,g_PanelHeight);
      return;
   }

   //=======================================================  SECAO 1: CONTA
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double lucroTotal = (g_BuyLucro+g_BuySwap) + (g_SellLucro+g_SellSwap);
   // [BUG-C3 FIX] DD exibido usa PNL do ROBO (nao conta toda) para nao confundir com trades manuais
   double dd_usd  = MathAbs(MathMin(0.0, lucroTotal));
   double global_profit=0, global_swap=0;
   string open_symbols[];
   int open_symbols_count=0;
   
   // [BUG-M3 FIX] Filtra por todas as moedas deste EA (Range Global)
   for(int i=0;i<PositionsTotal();i++) {
      ulong tck=PositionGetTicket(i);
      if(tck>0) {
         long mag=PositionGetInteger(POSITION_MAGIC);
         if(mag >= InpMagicNumberBase && mag <= InpMagicNumberBase + 999999) {
            global_swap   += PositionGetDouble(POSITION_SWAP);
            global_profit += PositionGetDouble(POSITION_PROFIT);
            
            string sym = PositionGetString(POSITION_SYMBOL);
            bool found = false;
            for(int j=0; j<open_symbols_count; j++) {
               if(open_symbols[j] == sym) { found = true; break; }
            }
            if(!found) {
               ArrayResize(open_symbols, open_symbols_count+1);
               open_symbols[open_symbols_count] = sym;
               open_symbols_count++;
            }
         }
      }
   }
   double global_total = global_profit + global_swap;
   double global_media = (open_symbols_count > 0) ? (global_total / open_symbols_count) : 0;

    // SEÇÃO VISÃO GLOBAL - TABULAR 4 COLUNAS
    double fatBRL = g_TaxaBRLAtual;
    string accCurr = AccountInfoString(ACCOUNT_CURRENCY);
    if(StringFind(accCurr, "USC") >= 0 || StringFind(accCurr, "Cent") >= 0 || StringFind(accCurr, "c") >= 0) fatBRL = g_TaxaBRLAtual / 100.0;
    cur+=4;
    
    // 1. SALDO CONTA
    PLabel("lbl_sal_l", lx, cur+2, "SALDO CONTA", CLR_TXT_DIM, 8);
    PLabelR("lbl_sal_brl", lx + 160, cur+2, FormatBRL(balance * fatBRL), CLR_TXT_DIM, 8);
    PLabelR("lbl_sal_usc", rx - 55, cur+1, FormatUSC(balance) + " USC", CLR_TXT_PRIMARY, 10, true);
    cur += 20;
    
    // Separador 1
    PRect("sep_sal", lx, cur, thm_w, 1, CLR_LINE_SOFT, -1, 204); cur += 10;
    
    // 2. PATRIMÔNIO (Saldo Líquido)
    double pct_total = (balance > 0) ? ((equity - balance) / balance * 100.0) : 0.0;
    string sPctTotal = (pct_total >= 0 ? "+" : "") + DoubleToString(pct_total, 2) + "%";
    color clrTotal = (pct_total >= 0) ? C'0,200,83' : C'255,82,82';
    
    PLabel("lbl_eq_l", lx, cur+2, "PATRIMÔNIO", CLR_TXT_DIM, 8);
    PLabelR("lbl_eq_brl", lx + 160, cur+2, FormatBRL(equity * fatBRL), CLR_TXT_DIM, 8);
    PLabelR("lbl_eq_usc", rx - 55, cur+1, FormatUSC(equity) + " USC", clrTotal, 10, true);
    ObjectDelete(0, PANEL_PREFIX + "R_lbl_eq_pct"); // Deleta a porcentagem do patrimonio
    cur += 16;
    
    // 3. P&L ABERTO
    double usagePct = (balance > 0) ? (global_total / balance * 100.0) : 0.0;
    string sPctPl = (usagePct >= 0 ? "+" : "") + DoubleToString(usagePct, 2) + "%";
    color clrPl = (global_total >= 0) ? C'0,200,83' : C'255,82,82';
    
    PLabel("lbl_pl_l", lx, cur+2, "P&L ABERTO", CLR_TXT_DIM, 8);
    PLabelR("lbl_pl_brl", lx + 160, cur+2, FormatBRL(global_total * fatBRL), CLR_TXT_DIM, 8);
    PLabelR("lbl_pl_usc", rx - 55, cur+1, FormatUSC(global_total, true) + " USC", clrPl, 10, true);
    PLabelR("lbl_pl_pct", rx - 2, cur+2, sPctPl, clrPl, 8);
    cur += 16;
    
    double absUsage = MathAbs(usagePct) / 100.0;
    color usageClr = (absUsage >= 0.20) ? C'255,82,82' : (absUsage >= 0.10 ? CLR_AMBER : C'0,200,83');
    PBar("pl_usage_bar", lx, cur, thm_w, 4, absUsage, C'30,38,50', usageClr);
    cur += 14;
    
    // Separador 2
    PRect("sep_pl", lx, cur, thm_w, 1, CLR_LINE_SOFT, -1, 204); cur += 10;
    
    // 4. L. HOJE
    double pct_hoje = (balance > 0) ? (g_HistLucroHoje / balance * 100.0) : 0.0;
    string sPctHoje = (pct_hoje >= 0 ? "+" : "") + DoubleToString(pct_hoje, 2) + "%";
    color clrHoje = (g_HistLucroHoje >= 0) ? C'0,200,83' : C'255,82,82';
    
    PLabel("lbl_hoje_l", lx, cur+2, "L. HOJE", CLR_TXT_DIM, 8);
    PLabelR("lbl_hoje_brl", lx + 160, cur+2, FormatBRL(g_HistLucroHoje * fatBRL), CLR_TXT_DIM, 8);
    PLabelR("lbl_hoje_usc", rx - 55, cur+1, FormatUSC(g_HistLucroHoje, true) + " USC", clrHoje, 10, true);
    PLabelR("lbl_hoje_pct", rx - 2, cur+2, sPctHoje, clrHoje, 8);
    cur += 20;
    
    // Separador 3
    PRect("sep_hoje", lx, cur, thm_w, 1, CLR_LINE_SOFT, -1, 204); cur += 10;
    
    // 5. L. GLOBAL
    double pct_hist = (balance > 0) ? (g_HistLucroGlobal / balance * 100.0) : 0.0;
    string sPctHist = (pct_hist >= 0 ? "+" : "") + DoubleToString(pct_hist, 2) + "%";
    color clrHist = (g_HistLucroGlobal >= 0) ? C'0,200,83' : C'255,82,82';
    
    PLabel("lbl_hist_l", lx, cur+2, "L. GLOBAL", CLR_TXT_DIM, 8);
    PLabelR("lbl_hist_brl", lx + 160, cur+2, FormatBRL(g_HistLucroGlobal * fatBRL), CLR_TXT_DIM, 8);
    PLabelR("lbl_hist_usc", rx - 55, cur+1, FormatUSC(g_HistLucroGlobal, true) + " USC", clrHist, 10, true);
    PLabelR("lbl_hist_pct", rx - 2, cur+2, sPctHist, clrHist, 8);
    cur += 16;
    
    // 6. L. LÍQUIDO
    double lucroLiquido = g_HistLucroGlobal + global_total;
    double pct_liq = (balance > 0) ? (lucroLiquido / balance * 100.0) : 0.0;
    string sPctLiq = (pct_liq >= 0 ? "+" : "") + DoubleToString(pct_liq, 2) + "%";
    color clrLiq = (lucroLiquido >= 0) ? C'0,200,83' : C'255,82,82';
    
    PLabel("lbl_liq_l", lx, cur+2, "L. LÍQUIDO", CLR_TXT_DIM, 8);
    PLabelR("lbl_liq_brl", lx + 160, cur+2, FormatBRL(lucroLiquido * fatBRL), CLR_TXT_DIM, 8);
    PLabelR("lbl_liq_usc", rx - 55, cur+1, FormatUSC(lucroLiquido, true) + " USC", clrLiq, 10, true);
    PLabelR("lbl_liq_pct", rx - 2, cur+2, sPctLiq, clrLiq, 8);
    cur += 20;
    
    // Separador 4 (Entre Rendimentos e Risco Flutuante)
    PRect("sep_liq", lx, cur, thm_w, 1, CLR_LINE_SOFT, -1, 204); cur += 10;

   // BUG #12: Exclusão redundante removida para evitar flicker visual.
   // LimparConteudoPainel() ja limpa os botoes de filtro na transicao de tela (g_ShowSettings).

   // DRAWDOWN GLOBAL - barra 3 zonas pre-pintadas (verde→amarelo→vermelho)
   double dd_glb_pct = (balance>0) ? MathAbs(MathMin(0.0, global_total))/balance*100.0 : 0.0;
   color dd_glb_clr = (dd_glb_pct>=40.0)?C'255,82,82':(dd_glb_pct>=20.0?CLR_AMBER:C'0,200,83');
   double maxDDAllowedPct = (balance > 0) ? (g_SoftStopAtual / balance * 100.0) : 0.0;
   string sLabelGlbDD = "DRAWDOWN GLOBAL (" + DoubleToString(maxDDAllowedPct, 0) + "%)";
   PLabel("glb_dd_l",lx,cur,sLabelGlbDD,CLR_TXT_DIM,8);
   PLabelR("glb_dd_v",rx-2,cur,DoubleToString(dd_glb_pct,2)+"%",dd_glb_clr,10,true); cur+=16;
   int gzw1 = (int)MathRound(0.40 * thm_w);
   int gzw2 = (int)MathRound(0.40 * thm_w);
   PRect("gddbar_z1",lx,             cur,gzw1,             8,C'12,60,35', -1,204); // zona verde (0-20%)
   PRect("gddbar_z2",lx+gzw1,        cur,gzw2,             8,C'60,42,0',  -1,204); // zona amarela (20-40%)
   PRect("gddbar_z3",lx+gzw1+gzw2,   cur,thm_w-gzw1-gzw2,  8,C'60,14,14', -1,204); // zona vermelha (>40%)
   int gdd_fill = (int)MathRound(MathMin(1.0, dd_glb_pct / 50.0) * thm_w);
   if(gdd_fill > 1) PRect("gddbar_fill", lx, cur, gdd_fill, 8, dd_glb_clr, -1, 206);
   else             ObjectDelete(0, PANEL_PREFIX+"gddbar_fill");
   cur+=16;
   
    if(InpAtivarCicloEquity) {
       double profitNet = g_HistLucroGlobal + global_total;
       double pctNet = (g_EquityCycleBaseBalance > 0) ? (profitNet / g_EquityCycleBaseBalance * 100.0) : 0.0;
       double currentTargetPct = InpMetaCicloEquityPct;
       
       double progressPct = (currentTargetPct > 0) ? (pctNet / currentTargetPct * 100.0) : 0.0;
       color tClr = CLR_TEAL;
       if(pctNet >= currentTargetPct * 0.8) tClr = CLR_AMBER;
       if(pctNet < 0) tClr = CLR_RED;
       
       string pipe = ShortToString(0x2502);
       string arrow = ShortToString(0x2794);
       
       int cd_sec = (int)MathMax(0, g_EquityCycleCooldownEnd - TimeCurrent());
       if(cd_sec > 0) {
          int minRestante = (cd_sec / 60) + 1;
          string sLabel1 = "CICLO EQ  " + pipe + "  COOLDOWN (" + IntegerToString(minRestante) + " min)";
          PLabel("lbl_t_status_l", lx, cur, sLabel1, CLR_AMBER, 8);
          PClear("lbl_t_status_v");
          PClear("lbl_t_prog_l");
          PClear("lbl_t_prog_v");
          cur+=16;
          
          ObjectDelete(0, PANEL_PREFIX+"eq_cycle_bar_bg");
          ObjectDelete(0, PANEL_PREFIX+"eq_cycle_bar_fill");
       } else {
          double targetVal = g_EquityCycleBaseBalance * (1.0 + currentTargetPct / 100.0);
          string sBaseVal = "", sTargetVal = "";
          if(g_TaxaBRLAtual > 0) {
             sBaseVal = "R$ " + DoubleToString(g_EquityCycleBaseBalance * fatBRL, 2);
             sTargetVal = "R$ " + DoubleToString(targetVal * fatBRL, 2);
          } else {
             sBaseVal = "$" + DoubleToString(g_EquityCycleBaseBalance, 2);
             sTargetVal = "$" + DoubleToString(targetVal, 2);
          }
          
          string sLabel1 = "BASE  " + pipe + "  " + sBaseVal;
          string sValue1 = "ALVO (+" + DoubleToString(currentTargetPct, 1) + "%): " + sTargetVal;
          
          // Linha 2: PROGRESSO │ Lucro e Barra de Progresso
          double clampedProgress = MathMin(100.0, MathMax(0.0, progressPct));
          int solidCount = (int)MathRound(clampedProgress / 10.0);
          if(solidCount < 0) solidCount = 0;
          if(solidCount > 10) solidCount = 10;
          int emptyCount = 10 - solidCount;
          
          string barStr = "[";
          for(int k=0; k<solidCount; k++) barStr += ShortToString(0x2588);
          for(int k=0; k<emptyCount; k++) barStr += ShortToString(0x2591);
          barStr += "]";
          
          string sProfitVal = "";
          if(g_TaxaBRLAtual > 0) {
             sProfitVal = "R$ " + DoubleToString(profitNet * fatBRL, 2);
          } else {
             sProfitVal = "$" + DoubleToString(profitNet, 2);
          }
          
          string sLabel2 = "LUCRO  " + pipe + "  " + (profitNet >= 0 ? "+" : "") + sProfitVal + " (" + (pctNet >= 0 ? "+" : "") + DoubleToString(pctNet, 1) + "%)";
          string sValue2 = barStr + "  " + DoubleToString(clampedProgress, 0) + "%";
          
          PLabel("lbl_t_status_l", lx, cur, sLabel1, CLR_TXT_DIM, 8);
          PLabelR("lbl_t_status_v", rx-2, cur, sValue1, CLR_TXT_PRIMARY, 8);
          cur+=14;
          
          PLabel("lbl_t_prog_l", lx, cur, sLabel2, CLR_TXT_DIM, 8);
          PLabelR("lbl_t_prog_v", rx-2, cur, sValue2, tClr, 8, true);
          cur+=16;
       }
       ObjectDelete(0, PANEL_PREFIX+"lbl_t_status");
       ObjectDelete(0, PANEL_PREFIX+"eq_cycle_bar_bg");
       ObjectDelete(0, PANEL_PREFIX+"eq_cycle_bar_fill");
    } else {
       PClear("lbl_t_status_l");
       PClear("lbl_t_status_v");
       PClear("lbl_t_prog_l");
       PClear("lbl_t_prog_v");
       ObjectDelete(0, PANEL_PREFIX+"eq_cycle_bar_bg");
       ObjectDelete(0, PANEL_PREFIX+"eq_cycle_bar_fill");
    }

   // SEÇÃO VISÃO LOCAL
   ObjectDelete(0, PANEL_PREFIX+"sep_glb_loc"); // Remove linha antiga
   cur+=10;
   PSect("sec_loc", px, cur, pw, "VISÃO LOCAL (MOEDA ATUAL)", CLR_AMBER); cur+=20;

   // CARD LOCAL (MOEDA ATUAL)
   PRect("bg_loc",px+pad-2,cur,pw-(pad*2)+4,110,C'22,26,35',CLR_LINE_SOFT,200,true); cur+=6;

   string sBrlPLoc = (g_TaxaBRLAtual>0) ? "  [R$ " + DoubleToString(lucroTotal*fatBRL, 2) + "]" : "";
   PLabel("acc_pl_l",lx,cur,"P&L LOCAL"+sBrlPLoc,CLR_TXT_LABEL,8);
   string signalPL = (lucroTotal>=0) ? "+" : "";
   PLabelR("acc_pl_v",rx-2,cur,signalPL+DoubleToString(lucroTotal,2)+" USC",lucroTotal>=0?C'0,200,83':C'255,82,82',13,true); cur+=20;
   
   double pPct=(g_SoftStopAtual>0)?MathMin(1.0,MathAbs(lucroTotal)/g_SoftStopAtual):0;
   PBar("m_pl",lx,cur,thm_w,6,pPct,C'30,38,50',lucroTotal>=0?C'0,200,83':C'255,82,82'); cur+=16;
   
   // DRAWDOWN LOCAL - barra 3 zonas pre-pintadas
   double dd_pct=(balance>0)?(dd_usd/balance*100.0):0.0;
   color dd_clr=(dd_pct>=40.0)?C'255,82,82':(dd_pct>=20.0?CLR_AMBER:C'0,200,83');
   PLabel("acc_dd_l",lx,cur,"DRAWDOWN LOCAL",CLR_TXT_DIM,8);
   PLabelR("acc_dd_v",rx-2,cur,DoubleToString(dd_pct,2)+"%",dd_clr,10,true); cur+=14;
   int lzw1 = (int)MathRound(0.40 * thm_w);
   int lzw2 = (int)MathRound(0.40 * thm_w);
   PRect("ddbar_z1",lx,             cur,lzw1,             8,C'12,60,35', -1,204);
   PRect("ddbar_z2",lx+lzw1,        cur,lzw2,             8,C'60,42,0',  -1,204);
   PRect("ddbar_z3",lx+lzw1+lzw2,   cur,thm_w-lzw1-lzw2,  8,C'60,14,14', -1,204);
   int dd_fill=(int)MathRound(MathMin(1.0,dd_pct/50.0)*thm_w);
   if(dd_fill>1) PRect("ddbar_fill",lx,cur,dd_fill,8,dd_clr,-1,206);
   else          ObjectDelete(0, PANEL_PREFIX+"ddbar_fill");
   cur+=18;
   
   // SOFTSTOP - barra 3 zonas pre-pintadas
   double pct_ss=MathMin(1.0,(g_SoftStopAtual>0?dd_usd/g_SoftStopAtual:0));
   color ss_clr=(pct_ss>=0.66)?C'255,82,82':(pct_ss>=0.33?CLR_AMBER:C'0,200,83');
   PLabel("lbl_ss_l",lx,cur,"LIMITE SOFTSTOP",CLR_TXT_DIM,8);
   PLabelR("lbl_ss_v",rx-2,cur,DoubleToString(g_SoftStopAtual,0)+" USC",CLR_TXT_PRIMARY,10,true); cur+=14;
   int szw = thm_w/3;
   PRect("thrm_z1",lx,       cur,szw,        8,C'12,60,35', -1,204);
   PRect("thrm_z2",lx+szw,  cur,szw,        8,C'60,42,0',  -1,204);
   PRect("thrm_z3",lx+szw*2,cur,thm_w-szw*2,8,C'60,14,14',-1,204);
   int ss_fill=(int)MathRound(pct_ss*thm_w);
   if(ss_fill>1) PRect("thrm_fill",lx,cur,ss_fill,8,ss_clr,-1,206);
   else          ObjectDelete(0, PANEL_PREFIX+"thrm_fill");
   cur+=18;

   // LUCRO ACUMULADO POR MOEDA
   ObjectDelete(0, PANEL_PREFIX+"sym_hist_bg"); // Garante a deleção do box antigo
   string sBrlHLoc = (g_TaxaBRLAtual>0) ? "  [R$ " + DoubleToString(g_HistLucroSymbol*fatBRL, 2) + "]" : "";
   PLabel("sym_hist_tit",lx,cur,"LUCRO LOCAL"+sBrlHLoc,CLR_TXT_LABEL,8);
   color txSym = g_HistLucroSymbol>=0 ? C'0,200,83' : C'255,82,82';
   string signalSym = (g_HistLucroSymbol>=0) ? "+" : "";
   PLabelR("sym_hist_val",rx-2,cur,signalSym+DoubleToString(g_HistLucroSymbol,2)+" USC",txSym,13,true); cur+=19;

   //=======================================================  SECAO 2: MERCADO E STATUS
   double spd=(double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   
   // Cooldown: pega o maior tempo restante entre Buy e Sell
   datetime now = TimeCurrent();
   int cd_buy_sec  = (int)MathMax(0, g_BuyCooldownEnd  - now);
   int cd_sell_sec = (int)MathMax(0, g_SellCooldownEnd - now);
   int cd_sec = (int)MathMax(cd_buy_sec, cd_sell_sec);
   string cd_str;
   color  cd_clr;
   if(!InpCooldownHabilitado || cd_sec <= 0) {
      cd_str = "LIVRE";
      cd_clr = C'0,200,83';
   } else {
      int cd_min = cd_sec / 60;
      int cd_s   = cd_sec % 60;
      cd_str = IntegerToString(cd_min)+"m "+IntegerToString(cd_s)+"s";
      cd_clr = (cd_sec > 600) ? CLR_AMBER : C'255,82,82';
   }

   // SEÇÃO STATUS DO MERCADO
   cur+=10;
   PSect("sec_mkt", px, cur, pw, "STATUS E CONDIÇÕES DO MERCADO", CLR_TEAL); cur+=20;
   PRect("bg_mkt",px+pad-2,cur,pw-(pad*2)+4,38,CLR_BG_CARD,CLR_LINE_SOFT,200,true); cur+=4;
   
   bool sos_act = (InpAtivarHedgeParcial && (g_BuyTotal>=InpNivelHedgeParcial || g_SellTotal>=InpNivelHedgeParcial)) || (InpAtivarDinBreakEven && (g_BuyTotal>=InpNivelBreakEven || g_SellTotal>=InpNivelBreakEven));
   
   // Coluna Esquerda: Seguranca
   PLabel("mkt_sos_l",lx+4,cur,"DEFESA:",CLR_TXT_LABEL,8);
   PLabel("mkt_sos_v",lx+46,cur,sos_act?"DEFESA!":"MONITORANDO",sos_act?CLR_AMBER:C'0,200,83',8,true);
   
   // Coluna Direita: Lote
   PLabel("mkt_lote_l",lx+160,cur,"Lote:",CLR_TXT_LABEL,8);
   PLabel("mkt_lote_v",lx+192,cur,DoubleToString(g_LoteBase,3),CLR_TXT_PRIMARY,8,true);
   cur+=16;

   // Coluna Esquerda: Cooldown
   PLabel("mkt_cd_l",lx+4,cur,"CD:",CLR_TXT_LABEL,8);
   PLabel("mkt_cd_v",lx+32,cur,cd_str,cd_clr,8,true);

   // Coluna Direita: Spread
   PLabel("mkt_spr_l",lx+160,cur,"Spread:",CLR_TXT_LABEL,8);
   PLabel("mkt_spr_v",lx+206,cur,IntegerToString((int)spd),spd<=InpMaxSpread?CLR_TXT_PRIMARY:C'255,82,82',8,true);
   
   // Noticia Ativa (Sinalizacao Amarela)
   if(g_NewsActive) {
      PButton("mkt_news", lx+268, cur-8, 48, 18, "NEWS", CLR_AMBER, clrBlack);
   } else {
      ObjectDelete(0, PANEL_PREFIX+"mkt_news");
   }
   
   cur+=20;

   //=======================================================  SECAO 3: CESTO COMPRA
   PSect("sec_buy", px, cur, pw, "CESTA DE COMPRA", CLR_TEAL);
   PLabelR("buy_lvl", rx-6, cur+2, g_BuyEmTrailing ? "[ TRAILING ]" : " ", CLR_PURPLE, 8, true);
   cur+=20;
   
   if(g_BuyTotal==0) {
      // --- Limpar todos os objetos do card Buy para evitar ghosts ---
      // [BUG-L2 FIX] Lista expandida com novos objetos da feature Alvo+pts+USD
      string bObjs[]={
         "bg_buy","buy_hdr","R_buy_lvl","buy_sep",
         "buy_pm_lbl","buy_pm_val","buy_vol_lbl","R_buy_vol_val",
         "buy_lucro_lbl","R_buy_lucro_val","buy_plb_bg","buy_plb_zero","buy_plb_fill",
         "buy_alvo_lbl","buy_alvo_val","buy_alvo_pts","buy_alvo_usd",
         "buy_proj","R_buy_apts","buy_rcinfo","R_buy_rcval","buy_vz","buy_sos_info",
         "sos_b_pior","sos_b_info"
      };
      for(int k=0;k<ArraySize(bObjs);k++) ObjectDelete(0,PANEL_PREFIX+bObjs[k]);
      PRect("bg_buy",px+pad-2,cur,pw-(pad*2)+4,20,CLR_BG_CARD,CLR_LINE_SOFT);
      PLabel("buy_vz",lx+pw/2-55,cur+4,"SEM POSICAO DE COMPRA",CLR_TXT_LABEL,9,true);
      cur+=26;
   } else {
      ObjectDelete(0,PANEL_PREFIX+"buy_vz");
      int bh=96; // altura do card (reduzido)
      bool isBuyLim = ((g_BuyLucro+g_BuySwap) < -g_SoftStopPorCesto);
      // [RENDER FIX] Forca delete+recriacao para garantir BACK=true no MT5
      ObjectDelete(0,PANEL_PREFIX+"bg_buy");
      PRect("bg_buy",px+pad-2,cur,pw-(pad*2)+4,bh,C'22,35,30',isBuyLim ? C'255,82,82' : C'0,200,83',200,true);

      cur+=6;

      // PM e Volume na mesma linha com posicoes fixas
      PLabel("buy_pm_lbl",lx+6,cur,"Preço Médio:",CLR_TXT_DIM,8);
      PLabel("buy_pm_val",lx+80,cur,DoubleToString(g_BuyPrecoMedio,_Digits),CLR_AMBER,9,true);
      PLabel("buy_vol_lbl",lx+2+thm_w/2,cur,"Volume:",CLR_TXT_DIM,8);
      PLabelR("buy_vol_val",rx-6,cur,DoubleToString(g_BuyVolume,3)+" L",clrWhite,9,true); cur+=17;

      // Lucro — linha completa
      double bpl=g_BuyLucro+g_BuySwap;
      PLabel("buy_lucro_lbl",lx+6,cur,"LUCRO ATUAL",CLR_TXT_DIM,8);
      string bplSig = bpl>=0?"+":"";
      PLabelR("buy_lucro_val",rx-6,cur,bplSig+DoubleToString(bpl,2)+" USC",bpl>=0?C'0,200,83':C'255,82,82',12,true); cur+=19;

      // Alvo com preco + distancia pts + valor USD (feature image)
      double buyBid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      double buyPts = (g_BuyAlvo - buyBid) / _Point;
      color buyPtsClr = (buyPts<=0)?C'0,200,83':(buyPts<100)?C'80,220,160':(buyPts<250)?CLR_AMBER:C'255,82,82';
      string buyPtsStr = (buyPts<=0) ? "PRONTO!" : (DoubleToString(MathAbs(buyPts),0)+" pts");
      string buyUSDStr = (buyPts<=0) ? "" : ("  [+"+DoubleToString(g_BuyTPEfetivo,2)+" USC]");
      PLabel("buy_alvo_lbl",lx+6,cur,"Alvo:",CLR_TXT_DIM,8);
      PLabel("buy_alvo_val",lx+40,cur,DoubleToString(g_BuyAlvo,_Digits)+" ("+buyPtsStr+")",buyPtsClr,8,true);
      PLabelR("buy_alvo_usd",rx-6,cur,buyUSDStr,C'0,200,83',9,true);
      cur+=16;

      // Barra progresso Alvo (Termometro Bi-direcional)
      double bPct = 0;
      double softStopLimit = g_SoftStopAtual > 0 ? g_SoftStopAtual : 1000.0;
      if (bpl >= 0) {
         bPct = (g_TakeProfitAtual > 0) ? MathMin(1.0, bpl / g_TakeProfitAtual) : 0;
      } else {
         bPct = -1.0 * MathMin(1.0, MathAbs(bpl) / softStopLimit);
      }
      color barFillBuyPos = CLR_TEAL;
      color barFillBuyNeg = CLR_RED;
      PBiBar("buy_plb", lx+2, cur, thm_w, 8, bPct, CLR_LINE_SOFT, barFillBuyPos, barFillBuyNeg); cur+=14;

      // Proxima recompra
      if(g_BuyDistFalt>0) {
         string rcVal=(g_BuyProxPreco>0)
            ?(DoubleToString(g_BuyProxPreco,_Digits)+" ("+DoubleToString(g_BuyDistFalt/_Point,0)+" pts)")
            :("Falta "+DoubleToString(g_BuyDistFalt/_Point,0)+" pts");
         double pxLotB = CalcNovoLote(g_BuyNivelAtual, g_BuyLoteInicial);  // [BUG #4 FIX]
         string rfInfo = "> RC [+"+DoubleToString(pxLotB,3)+"L]";
         if(g_BuyTfAlvo != "") rfInfo += " "+g_BuyTfAlvo;
         PLabel("buy_rcinfo",lx+2,cur,rfInfo+":",CLR_BLUE,8);
         PLabelR("buy_rcval",rx-2,cur,rcVal,CLR_BLUE,8,true);
      } else {
         PLabel("buy_rcinfo",lx+2,cur,"> Prox. Recompra:",CLR_BLUE,8);
         string statusStr = "LIBERADA";
         color statusClr = CLR_TEAL;
         if(isBuyLim) {
            statusStr = "[ALERTA LIMITE]";
            statusClr = CLR_RED;
         } else if(!FiltroAntiFacaConfirmado(true)) {
            statusStr = "AGUARDANDO " + StringSubstr(EnumToString(InpAntiFacaTF), 7);
            statusClr = CLR_AMBER;
         }
         PLabelR("buy_rcval",rx-2,cur,statusStr,statusClr,8,true);
      }
      cur+=17;
      cur+=7;
   }

   // Grade inferior Buy — Compras sempre na paleta Verde/Amarela para nao confundir com Venda
   bool isBuyLimGrd = ((g_BuyLucro+g_BuySwap) < -g_SoftStopPorCesto);
   color buyGradeClr = isBuyLimGrd ? C'0,255,128' : (g_BuyTotal >= InpMaxOrdens-1 ? CLR_AMBER : CLR_TEAL);
   PLabel("buy_grl",lx,cur,"GRADE:",CLR_TXT_DIM,8,true);
   PGradeBar("buy_grade",lx+46,cur,thm_w-118,10,InpMaxOrdens,g_BuyTotal,buyGradeClr,C'14,24,18');
   if(g_BuyNivelAtual >= 2) {
      string buySosTxt = g_BuySaidaZeroAtiva ? "AGD" : "S.O.S";
      color buySosBg = g_BuySaidaZeroAtiva ? CLR_AMBER : C'65,18,18';
      color buySosFg = g_BuySaidaZeroAtiva ? clrBlack : CLR_RED;
      PButton("btn_buy_sos", lx + 46 + (thm_w - 118) + 6, cur - 2, 40, 14, buySosTxt, buySosBg, buySosFg);
   } else {
      ObjectDelete(0, PANEL_PREFIX + "btn_buy_sos");
   }
   PLabelR("buy_grn",rx,cur,IntegerToString(g_BuyTotal)+"/"+IntegerToString(InpMaxOrdens),g_BuyTotal>0?CLR_BLUE:CLR_TXT_DIM,8,true); cur+=20;

   //=======================================================  SECAO 4: CESTO VENDA
   PSect("sec_sell", px, cur, pw, "CESTA DE VENDA", CLR_RED);
   PLabelR("sel_lvl", rx-6, cur+2, g_SellEmTrailing ? "[ TRAILING ]" : " ", CLR_PURPLE, 8, true);
   cur+=20;

   if(g_SellTotal==0) {
      // [BUG-L2 FIX] Lista expandida com novos objetos da feature Alvo+pts+USD
      string sObjs[]={
         "bg_sel","sel_hdr","R_sel_lvl","sel_sep",
         "sel_pm_lbl","sel_pm_val","sel_vol_lbl","R_sel_vol_val",
         "sel_lucro_lbl","R_sel_lucro_val","sel_plb_bg","sel_plb_zero","sel_plb_fill",
         "sel_alvo_lbl","sel_alvo_val","sel_alvo_pts","sel_alvo_usd",
         "sel_proj","R_sel_apts","sel_rcinfo","R_sel_rcval","sel_vz","sel_s_info"
      };
      for(int k=0;k<ArraySize(sObjs);k++) ObjectDelete(0,PANEL_PREFIX+sObjs[k]);
      PRect("bg_sel",px+pad-2,cur,pw-(pad*2)+4,20,CLR_BG_CARD,CLR_LINE_SOFT);
      PLabel("sel_vz",lx+pw/2-55,cur+4,"SEM POSICAO DE VENDA",CLR_TXT_LABEL,9,true);
      cur+=24;
   } else {
      ObjectDelete(0,PANEL_PREFIX+"sel_vz");
      int sh=96; // altura do card (reduzida)
      bool isSelLim = ((g_SellLucro+g_SellSwap) < -g_SoftStopPorCesto);
      // [RENDER FIX] Forca delete+recriacao para garantir BACK=true no MT5
      ObjectDelete(0,PANEL_PREFIX+"bg_sel");
      PRect("bg_sel",px+pad-2,cur,pw-(pad*2)+4,sh,C'40,25,25',isSelLim ? C'255,82,82' : C'0,200,83',200,true); // [v3.32 FIX]

      cur+=6;

      PLabel("sel_pm_lbl",lx+6,cur,"Preço Médio:",CLR_TXT_DIM,8);
      PLabel("sel_pm_val",lx+80,cur,DoubleToString(g_SellPrecoMedio,_Digits),CLR_AMBER,9,true);
      PLabel("sel_vol_lbl",lx+2+thm_w/2,cur,"Volume:",CLR_TXT_DIM,8);
      PLabelR("sel_vol_val",rx-6,cur,DoubleToString(g_SellVolume,3)+" L",clrWhite,9,true); cur+=17;

      double spl=g_SellLucro+g_SellSwap;
      PLabel("sel_lucro_lbl",lx+6,cur,"LUCRO ATUAL",CLR_TXT_DIM,8);
      string splSig = spl>=0?"+":"";
      PLabelR("sel_lucro_val",rx-6,cur,splSig+DoubleToString(spl,2)+" USC",spl>=0?C'0,200,83':C'255,82,82',12,true); cur+=19;

      // Alvo com preco + distancia pts + valor USD (feature image)
      double selAsk = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double selPts = (selAsk - g_SellAlvo) / _Point;
      color selPtsClr = (selPts<=0)?C'0,200,83':(selPts<100)?C'80,220,160':(selPts<250)?CLR_AMBER:C'255,82,82';
      string selPtsStr = (selPts<=0) ? "PRONTO!" : ("\x25BC"+DoubleToString(MathAbs(selPts),0)+" pts");
      string selUSDStr = (selPts<=0) ? "" : ("  [+"+DoubleToString(g_SellTPEfetivo,2)+" USC]");
      PLabel("sel_alvo_lbl",lx+6,cur,"Alvo:",CLR_TXT_DIM,8);
      PLabel("sel_alvo_val",lx+40,cur,DoubleToString(g_SellAlvo,_Digits)+" ("+selPtsStr+")",selPtsClr,8,true);
      PLabelR("sel_alvo_usd",rx-6,cur,selUSDStr,C'0,200,83',9,true);
      cur+=16;

      // Barra progresso Alvo (Termometro Bi-direcional)
      double sPct = 0;
      double softStopLimitS = g_SoftStopAtual > 0 ? g_SoftStopAtual : 1000.0;
      if (spl >= 0) {
         sPct = (g_TakeProfitAtual > 0) ? MathMin(1.0, spl / g_TakeProfitAtual) : 0;
      } else {
         sPct = -1.0 * MathMin(1.0, MathAbs(spl) / softStopLimitS);
      }
      color barFillSelPos = CLR_TEAL;
      color barFillSelNeg = CLR_RED;
      PBiBar("sel_plb", lx+2, cur, thm_w, 8, sPct, CLR_LINE_SOFT, barFillSelPos, barFillSelNeg); cur+=14;

      if(g_SellDistFalt>0) {
         string rcValS=(g_SellProxPreco>0)
            ?(DoubleToString(g_SellProxPreco,_Digits)+" ("+DoubleToString(g_SellDistFalt/_Point,0)+" pts)")
            :("Falta "+DoubleToString(g_SellDistFalt/_Point,0)+" pts");
         double pxLotS = CalcNovoLote(g_SellNivelAtual, g_SellLoteInicial);  // [BUG #4 FIX]
         string rfInfoS = "> RC [+"+DoubleToString(pxLotS,3)+"L]";
         if(g_SellTfAlvo != "") rfInfoS += " "+g_SellTfAlvo;
         PLabel("sel_rcinfo",lx+2,cur,rfInfoS+":",CLR_BLUE,8);
         PLabelR("sel_rcval",rx-2,cur,rcValS,CLR_BLUE,8,true);
      } else {
         PLabel("sel_rcinfo",lx+2,cur,"> Prox. Recompra:",CLR_BLUE,8);
         string statusStr = "LIBERADA";
         color statusClr = CLR_TEAL;
         if(isSelLim) {
            statusStr = "[ALERTA LIMITE]";
            statusClr = CLR_RED;
         } else if(!FiltroAntiFacaConfirmado(false)) {
            statusStr = "AGUARDANDO " + StringSubstr(EnumToString(InpAntiFacaTF), 7);
            statusClr = CLR_AMBER;
         }
         PLabelR("sel_rcval",rx-2,cur,statusStr,statusClr,8,true);
      }
      cur+=17;
      cur+=7;
   }

   // Grade inferior Sell — Vendas sempre na paleta Vermelha/Laranja
   bool isSelLimGrd = ((g_SellLucro+g_SellSwap) < -g_SoftStopPorCesto);
   color selGradeClr = isSelLimGrd ? CLR_RED : (g_SellTotal >= InpMaxOrdens-1 ? C'255,100,50' : C'180,60,60');
   PLabel("sel_grl",lx,cur,"GRADE:",CLR_TXT_DIM,8,true);
   PGradeBar("sel_grade",lx+46,cur,thm_w-118,10,InpMaxOrdens,g_SellTotal,selGradeClr,C'24,14,14');
   if(g_SellNivelAtual >= 2) {
      string selSosTxt = g_SellSaidaZeroAtiva ? "AGD" : "S.O.S";
      color selSosBg = g_SellSaidaZeroAtiva ? CLR_AMBER : C'65,18,18';
      color selSosFg = g_SellSaidaZeroAtiva ? clrBlack : CLR_RED;
      PButton("btn_sel_sos", lx + 46 + (thm_w - 118) + 6, cur - 2, 40, 14, selSosTxt, selSosBg, selSosFg);
   } else {
      ObjectDelete(0, PANEL_PREFIX + "btn_sel_sos");
   }
   PLabelR("sel_grn",rx,cur,IntegerToString(g_SellTotal)+"/"+IntegerToString(InpMaxOrdens),g_SellTotal>0?CLR_BLUE:CLR_TXT_DIM,8,true); cur+=18;

   //=======================================================  SECAO 6: CONTROLES
   PSect("s_ctrl",px,cur,pw,"CONTROLES",CLR_TXT_DIM); cur+=16;
   int bw=(pw-(pad*2)-4)/2;
   int bwfull=pw-(pad*2)+4;
   PButton("btn_pause",px+pad-2,cur,bwfull,24,g_BotPaused?"[>] RETOMAR":"[||] PAUSAR",
           g_BotPaused?CLR_TEAL_DIM:CLR_BG_SECTION,g_BotPaused?CLR_TEAL:CLR_TXT_PRIMARY); cur+=30;
   
   ObjectDelete(0, PANEL_PREFIX + "btn_sos_zero"); // Deleta botao sos antigo do rodapé
   
   PButton("btn_l0",px+pad-2,cur,bw,20,"LINHAS: VISIVEIS",g_LinhasModo==0?CLR_TEAL_DIM:CLR_BG_CARD,g_LinhasModo==0?CLR_TEAL:CLR_TXT_DIM);
   PButton("btn_l1",px+pad+bw+2,cur,bw,20,"LINHAS: OCULTAS",g_LinhasModo==1?CLR_RED_DIM:CLR_BG_CARD,g_LinhasModo==1?CLR_RED:CLR_TXT_DIM); cur+=22;
   PButton("btn_analise",px+pad-2,cur,bwfull,20,g_ModoAnalise?"[ ANÁLISE ATIVA ]":"[ ANÁLISE DE MERCADO (OFF) ]",g_ModoAnalise?C'15,35,75':CLR_BG_CARD,g_ModoAnalise?CLR_BLUE:CLR_TXT_DIM); cur+=28;

   //=======================================================  SECAO 7: ANALISE DE MERCADO (OPCIONAL)
   if(g_ModoAnalise) {
      string tfStr = StringSubstr(EnumToString(g_Ana_TF), 7);
      PSect("s_ana", px, cur, pw, "ANÁLISE DE MERCADO [" + tfStr + "]", CLR_BLUE); cur+=16;

      // Tendencia
      PLabel("ana_t1", lx, cur, "TENDÊNCIA", CLR_BLUE, 8, true); cur+=14;
      string adxTag = (g_Ana_ADX >= 25) ? " TRENDING" : " LATERAL";
      color  adxClr = (g_Ana_ADX >= 25) ? CLR_TEAL : CLR_TXT_LABEL;
      PRow("ana_adx", lx+4, rx, cur, "ADX (14):", DoubleToString(g_Ana_ADX,1) + adxTag, adxClr); cur+=14;
      
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      string emaTag = (g_Ana_EMA50 > g_EMA_Value) ? "\x25B2 ALTA" : "\x25BC BAIXA";
      color  emaClr = (g_Ana_EMA50 > g_EMA_Value) ? CLR_TEAL : CLR_RED;
      PRow("ana_ema", lx+4, rx, cur, "EMA Cross:", emaTag, emaClr); cur+=14;

      string d1Tag = (bid > g_Ana_EMA200_D1) ? "\x25B2 ACIMA" : "\x25BC ABAIXO";
      color  d1Clr = (bid > g_Ana_EMA200_D1) ? CLR_TEAL : CLR_RED;
      PRow("ana_d1", lx+4, rx, cur, "EMA200 D1:", d1Tag, d1Clr); cur+=20;

      // Momentum
      PLabel("ana_m1", lx, cur, "MOMENTUM", CLR_BLUE, 8, true); cur+=14;
      string rsiTag = (g_Ana_RSI > 70) ? " SOBRECOMPRA" : (g_Ana_RSI < 30) ? " SOBREVENDA" : " NEUTRO";
      color  rsiClr = (g_Ana_RSI > 70) ? CLR_RED : (g_Ana_RSI < 30) ? CLR_TEAL : CLR_TXT_LABEL;
      PRow("ana_rsi", lx+4, rx, cur, "RSI (14):", DoubleToString(g_Ana_RSI,1) + rsiTag, rsiClr); cur+=14;
      
      string macdTag = (g_Ana_MACD_Main > 0) ? "\x25B2 POSITIVO" : "\x25BC NEGATIVO";
      color  macdClr = (g_Ana_MACD_Main > 0) ? CLR_TEAL : CLR_RED;
      PRow("ana_macd", lx+4, rx, cur, "MACD:", macdTag, macdClr); cur+=14;

      string stoTag = (g_Ana_Stoch > 80) ? " EXTREMO ALTA" : (g_Ana_Stoch < 20) ? " EXTREMO BAIXA" : " NEUTRO";
      color  stoClr = (g_Ana_Stoch > 80) ? CLR_RED : (g_Ana_Stoch < 20) ? CLR_TEAL : CLR_TXT_LABEL;
      PRow("ana_stoch", lx+4, rx, cur, "Estocástico:", DoubleToString(g_Ana_Stoch,1) + stoTag, stoClr); cur+=20;

      // Volatilidade
      PLabel("ana_v1", lx, cur, "VOLATILIDADE", CLR_BLUE, 8, true); cur+=14;
      double atv_pts = (g_ATR_Value > 0) ? g_ATR_Value / _Point : 0;
      PRow("ana_atr", lx+4, rx, cur, "ATR:", DoubleToString(atv_pts,0) + " pts", CLR_TXT_PRIMARY); cur+=14;

      double bbW = (g_Ana_BB_Middle > 0) ? ((g_Ana_BB_Upper - g_Ana_BB_Lower) / g_Ana_BB_Middle * 100.0) : 0;
      string bbwTag = (bbW < 0.3) ? " SQUEEZE" : " SAUDÁVEL";
      color  bbwClr = (bbW < 0.3) ? CLR_RED : CLR_TEAL;
      PRow("ana_bbw", lx+4, rx, cur, "BB Width:", DoubleToString(bbW,2) + "%" + bbwTag, bbwClr); cur+=14;

      string bbpTag = (bid > g_Ana_BB_Upper) ? "ACIMA DA BANDA" : (bid < g_Ana_BB_Lower) ? "ABAIXO DA BANDA" : "MEIO BANDA";
      color  bbpClr = (bid > g_Ana_BB_Upper || bid < g_Ana_BB_Lower) ? CLR_AMBER : CLR_BLUE;
      PRow("ana_bbp", lx+4, rx, cur, "BB Posição:", bbpTag, bbpClr); cur+=20;

      // Mercado Macro
      PLabel("ana_mm1", lx, cur, "MERCADO", CLR_BLUE, 8, true); cur+=14;
      double spr = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      PRow("ana_spr", lx+4, rx, cur, "Spread:", DoubleToString(spr,0) + " / " + IntegerToString(InpMaxSpread) + " pts", (spr<=InpMaxSpread) ? CLR_TEAL : CLR_RED); cur+=14;
      
      string d1AdxTag = (g_Ana_ADX_D1 >= 25) ? " TRENDING" : " LATERAL";
      PRow("ana_adxd1", lx+4, rx, cur, "ADX D1:", DoubleToString(g_Ana_ADX_D1,1) + d1AdxTag, (g_Ana_ADX_D1 >= 25) ? CLR_TEAL : CLR_TXT_LABEL); cur+=14;
      // [BUG-M3 FIX] RSI D1 agora exibido no painel
      string rsiD1Tag = (g_Ana_RSI_D1 > 70) ? " SOBRECOMPRA" : (g_Ana_RSI_D1 < 30) ? " SOBREVENDA" : " NEUTRO";
      color  rsiD1Clr = (g_Ana_RSI_D1 > 70) ? CLR_RED : (g_Ana_RSI_D1 < 30) ? CLR_TEAL : CLR_TXT_LABEL;
      PRow("ana_rsid1", lx+4, rx, cur, "RSI D1:", DoubleToString(g_Ana_RSI_D1,1) + rsiD1Tag, rsiD1Clr); cur+=20;

      // Score / Status
      PLabel("ana_score_lbl", lx, cur, "SCORE: " + IntegerToString(g_Ana_Score) + "/10", CLR_TXT_PRIMARY, 8, true);
      PGradeBar("ana_score_bar", lx+65, cur, thm_w-65, 8, 10, g_Ana_Score, CLR_BLUE, C'20,30,40');
      cur+=16;

      string stTxt = (g_Ana_Score >= 8) ? "PRONTO PARA OPERAR" : (g_Ana_Score >= 5) ? "\x26A0 ATENÇÃO — AVALIE CONTEXTO" : "\x26D4 RISCO ALTO";
      color  stBg  = (g_Ana_Score >= 8) ? C'20,60,35' : (g_Ana_Score >= 5) ? C'80,60,20' : C'60,20,20';
      color  stFg  = (g_Ana_Score >= 8) ? CLR_TEAL : (g_Ana_Score >= 5) ? CLR_AMBER : CLR_RED;
      PButton("ana_status", lx, cur, thm_w, 24, stTxt, stBg, stFg);
      cur+=30;
   } else {
      // Limpar todos os elementos caso seja desligado
      string aObjs[] = {"s_ana","ana_t1","ana_adx","ana_ema","ana_d1","ana_m1","ana_rsi","ana_macd","ana_stoch",
                        "ana_v1","ana_atr","ana_bbw","ana_bbp","ana_mm1","ana_spr","ana_adxd1","ana_rsid1",  // [BUG-M3 FIX]
                        "ana_score_lbl","ana_status"};
      for(int k=0;k<ArraySize(aObjs);k++) PClear(aObjs[k]);
      ObjectDelete(0, PANEL_PREFIX+"ana_status");
      for(int k=0;k<10;k++) ObjectDelete(0, PANEL_PREFIX+"ana_score_bar_b"+IntegerToString(k));
   }

   //=======================================================  SECAO 8: LOG
   PRect("log_bg",px+pad-2,cur,pw-(pad*2)+4,g_ShowLog?68:20,CLR_BG_SECTION,CLR_LINE_SOFT);
   PButton("btn_log",rx-20,cur+2,16,16,g_ShowLog?"-":"+",CLR_BG_CARD,CLR_TXT_DIM); 
   if(g_ShowLog) {
      // [BUG-V2 FIX] Exibe 5 linhas (array tem 6, mostramos 5 para melhor contexto)
      for(int i=0;i<5;i++)
         PLabel("log_"+IntegerToString(i),px+pad+2,cur+4+(i*12),g_Log[i],(i==0)?CLR_AMBER:CLR_TXT_LABEL,7);
      cur+=74;
   } else {
      for(int i=0;i<5;i++) PClear("log_"+IntegerToString(i));  // [v3.32 FIX] Era i<4, perdia a linha 4
      PLabel("log_hidden",px+pad+2,cur+4,"[Log Oculto - Clique + para expandir]",CLR_TXT_DIM,8);
      cur+=26;
   }

   g_PanelHeight=cur-py;
   ObjectSetInteger(0,PANEL_PREFIX+"border",OBJPROP_YSIZE,g_PanelHeight+2);
   ObjectSetInteger(0,PANEL_PREFIX+"bg_main",OBJPROP_YSIZE,g_PanelHeight);

   //=======================================================  MINI PAINEIS S.O.S (FLUTUANTES)
   int sosX = px+pw+14;
   int sosHeightBuy=0, sosHeightSell=0;
   DesenharPainelSOS(true, sosX, py, sosHeightBuy);
   int sosYSell = py + (g_SOSPanelBuyAberto ? sosHeightBuy+10 : 0);
   DesenharPainelSOS(false, sosX, sosYSell, sosHeightSell);

   //=======================================================  WIDGET DE STATUS (CANTO SUPERIOR DIREITO)
   DesenharWidgetStatus();
}

// LINHAS VISUAIS NO GRAFICO
//===================================================================
void DrawVisualLine(string name, double price, color clr, string text="", int shiftBars=2) {
   string oh = PANEL_PREFIX + "Line_" + name;
   string ot = PANEL_PREFIX + "Text_" + name;
   if(price <= 0 || g_LinhasModo == 1) {
      if(ObjectFind(0, oh) >= 0) ObjectDelete(0, oh);
      if(ObjectFind(0, ot) >= 0) ObjectDelete(0, ot);
      return;
   }

   if(ObjectFind(0, oh) < 0) {
      ObjectCreate(0, oh, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, oh, OBJPROP_STYLE,      STYLE_DASH);
      ObjectSetInteger(0, oh, OBJPROP_BACK,       true);
      ObjectSetInteger(0, oh, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, oh, OBJPROP_HIDDEN,     true);
   }
   ObjectSetDouble(0,  oh, OBJPROP_PRICE, price);
   ObjectSetInteger(0, oh, OBJPROP_COLOR, clr);
   ObjectSetString(0, oh, OBJPROP_TEXT, ""); // Limpa texto nativo da linha para nao encavalar
   
   if(text != "") {
      if(ObjectFind(0, ot) < 0) {
         ObjectCreate(0, ot, OBJ_TEXT, 0, 0, price);
         ObjectSetString(0, ot, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, ot, OBJPROP_FONTSIZE, 10);
         ObjectSetInteger(0, ot, OBJPROP_BACK, false);
         ObjectSetInteger(0, ot, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, ot, OBJPROP_HIDDEN, true);
      }
      // Se for Venda, ancora pela direita (cresce pra esquerda). Compra ancora pela esquerda (cresce pra direita)
      int anchor = (StringFind(name, "S_") == 0) ? ANCHOR_RIGHT_LOWER : ANCHOR_LEFT_LOWER;
      ObjectSetInteger(0, ot, OBJPROP_ANCHOR, anchor);

      // Coloca o texto a frente do candle atual de forma escalonada para evitar sobreposicao
      datetime textTime = TimeCurrent() + (PeriodSeconds() * shiftBars); 
      ObjectSetInteger(0, ot, OBJPROP_TIME, textTime);
      ObjectSetDouble(0, ot, OBJPROP_PRICE, price);
      ObjectSetInteger(0, ot, OBJPROP_COLOR, clr); // Pinta o texto e a seta na cor referencia (TP=Verde, RC=Azul)

      if(anchor == ANCHOR_RIGHT_LOWER)
         ObjectSetString(0, ot, OBJPROP_TEXT, text + "  ");
      else
         ObjectSetString(0, ot, OBJPROP_TEXT, "  " + text);
   } else {
      ObjectDelete(0, ot);
   }
}

void DesenharLinhas() {
   string ln;
   // Linhas Cesto Compra
   if(g_BuyTotal > 0) {
      double bpl=g_BuyLucro+g_BuySwap;
      DrawVisualLine("B_BE", g_BuyPrecoMedio, CLR_AMBER);
      ln=PANEL_PREFIX+"Line_B_BE";
      if(ObjectFind(0,ln)>=0)
         ObjectSetString(0,ln,OBJPROP_TOOLTIP,
            "[+] COMPRA (PM)\n"+
            "PM: "+DoubleToString(g_BuyPrecoMedio,_Digits)+"  |  Vol: "+DoubleToString(g_BuyVolume,3)+"L  |  "+DoubleToString(bpl,2)+" USC");

      double buyPts=(g_BuyAlvo-SymbolInfoDouble(_Symbol,SYMBOL_BID))/_Point;
      string buyPtsStr = (buyPts<=0) ? "PRONTO!" : ("\x25B2"+DoubleToString(MathAbs(buyPts),0)+" pts");
      string buyUSDStr = (buyPts<=0) ? "" : ("  [+"+DoubleToString(g_BuyTPEfetivo,2)+" USC]");
      
      DrawVisualLine("B_TP", g_BuyAlvo, CLR_TEAL, "TP BUY " + buyPtsStr + buyUSDStr, 4);
      ln=PANEL_PREFIX+"Line_B_TP";
      if(ObjectFind(0,ln)>=0)
         ObjectSetString(0,ln,OBJPROP_TOOLTIP,
            "[+] COMPRA (TP)\n"+
            "Alvo: "+DoubleToString(g_BuyAlvo,_Digits)+"  |  "+buyPtsStr+buyUSDStr);

      if(g_BuyTotal < InpMaxOrdens && g_BuyProxFR > 0) {
         string distRc = DoubleToString(g_BuyDistFalt/_Point,0)+" pts";
         string numRC = "[" + IntegerToString(g_BuyTotal + 1) + "/" + IntegerToString(InpMaxOrdens) + "]";
         DrawVisualLine("B_FR", g_BuyProxFR,  CLR_BLUE, "RC BUY " + numRC + " \x25B2 " + distRc, 4);
         ln=PANEL_PREFIX+"Line_B_FR";
         if(ObjectFind(0,ln)>=0)
            ObjectSetString(0,ln,OBJPROP_TOOLTIP,
               "[+] COMPRA (Prox. RC)\n"+
               "Alvo: "+DoubleToString(g_BuyProxFR,_Digits)+"  \x25BC"+DoubleToString(g_BuyDistFalt/_Point,0)+" pts");
      } else
         DrawVisualLine("B_FR", 0, clrNONE);
   } else {
      DrawVisualLine("B_BE", 0, clrNONE);
      DrawVisualLine("B_TP", 0, clrNONE);
      DrawVisualLine("B_FR", 0, clrNONE);
   }

   // Linhas Cesto Venda
   if(g_SellTotal > 0) {
      double spl=g_SellLucro+g_SellSwap;
      DrawVisualLine("S_BE", g_SellPrecoMedio, CLR_AMBER);
      ln=PANEL_PREFIX+"Line_S_BE";
      if(ObjectFind(0,ln)>=0)
         ObjectSetString(0,ln,OBJPROP_TOOLTIP,
            "[-] VENDA (PM)\n"+
            "PM: "+DoubleToString(g_SellPrecoMedio,_Digits)+"  |  Vol: "+DoubleToString(g_SellVolume,3)+"L  |  "+DoubleToString(spl,2)+" USC");

      double selPts=(SymbolInfoDouble(_Symbol,SYMBOL_ASK)-g_SellAlvo)/_Point;
      string selPtsStr = (selPts<=0) ? "PRONTO!" : ("\x25BC"+DoubleToString(MathAbs(selPts),0)+" pts");
      string selUSDStr = (selPts<=0) ? "" : ("  [+"+DoubleToString(g_SellTPEfetivo,2)+" USC]");

      DrawVisualLine("S_TP", g_SellAlvo, CLR_TEAL, "TP SELL " + selPtsStr + selUSDStr, 3);
      ln=PANEL_PREFIX+"Line_S_TP";
      if(ObjectFind(0,ln)>=0)
         ObjectSetString(0,ln,OBJPROP_TOOLTIP,
            "[-] VENDA (TP)\n"+
            "Alvo: "+DoubleToString(g_SellAlvo,_Digits)+"  |  "+selPtsStr+selUSDStr);

      if(g_SellTotal < InpMaxOrdens && g_SellProxFR > 0) {
         string distRc = DoubleToString(g_SellDistFalt/_Point,0)+" pts";
         string numRC = "[" + IntegerToString(g_SellTotal + 1) + "/" + IntegerToString(InpMaxOrdens) + "]";
         DrawVisualLine("S_FR", g_SellProxFR,  CLR_BLUE, "RC SELL " + numRC + " \x25BC " + distRc, 3);
         ln=PANEL_PREFIX+"Line_S_FR";
         if(ObjectFind(0,ln)>=0)
            ObjectSetString(0,ln,OBJPROP_TOOLTIP,
               "[-] VENDA (Prox. RC)\n"+
               "Alvo: "+DoubleToString(g_SellProxFR,_Digits)+"  \x25B2"+DoubleToString(g_SellDistFalt/_Point,0)+" pts");
      } else
         DrawVisualLine("S_FR", 0, clrNONE);
   } else {
      DrawVisualLine("S_BE", 0, clrNONE);
      DrawVisualLine("S_TP", 0, clrNONE);
      DrawVisualLine("S_FR", 0, clrNONE);
   }
}

//===================================================================
// MODO ANÁLISE DE MERCADO — FUNÇÕES AUXILIARES
//===================================================================
void IniciarHandlesAnalise() {
   g_Ana_TF = ChartPeriod(0);  // TF visivel no MT5 agora
   // Libera handles anteriores antes de recriar
   if(g_AnaHandleADX    !=INVALID_HANDLE) { IndicatorRelease(g_AnaHandleADX);    g_AnaHandleADX    =INVALID_HANDLE; }
   if(g_AnaHandleRSI    !=INVALID_HANDLE) { IndicatorRelease(g_AnaHandleRSI);    g_AnaHandleRSI    =INVALID_HANDLE; }
   if(g_AnaHandleMACD   !=INVALID_HANDLE) { IndicatorRelease(g_AnaHandleMACD);   g_AnaHandleMACD   =INVALID_HANDLE; }
   if(g_AnaHandleStoch  !=INVALID_HANDLE) { IndicatorRelease(g_AnaHandleStoch);  g_AnaHandleStoch  =INVALID_HANDLE; }
   if(g_AnaHandleEMA50  !=INVALID_HANDLE) { IndicatorRelease(g_AnaHandleEMA50);  g_AnaHandleEMA50  =INVALID_HANDLE; }
   if(g_AnaHandleBB     !=INVALID_HANDLE) { IndicatorRelease(g_AnaHandleBB);     g_AnaHandleBB     =INVALID_HANDLE; }
   if(g_AnaHandleADX_D1 !=INVALID_HANDLE) { IndicatorRelease(g_AnaHandleADX_D1); g_AnaHandleADX_D1 =INVALID_HANDLE; }
   if(g_AnaHandleRSI_D1 !=INVALID_HANDLE) { IndicatorRelease(g_AnaHandleRSI_D1); g_AnaHandleRSI_D1 =INVALID_HANDLE; }
   if(g_AnaHandleEMA200D1!=INVALID_HANDLE){ IndicatorRelease(g_AnaHandleEMA200D1);g_AnaHandleEMA200D1=INVALID_HANDLE; }
   // Cria novos no TF atual do grafico
   g_AnaHandleADX    = iADX(_Symbol, g_Ana_TF, 14);
   g_AnaHandleRSI    = iRSI(_Symbol, g_Ana_TF, 14, PRICE_CLOSE);
   g_AnaHandleMACD   = iMACD(_Symbol, g_Ana_TF, 12, 26, 9, PRICE_CLOSE);
   g_AnaHandleStoch  = iStochastic(_Symbol, g_Ana_TF, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   g_AnaHandleEMA50  = iMA(_Symbol, g_Ana_TF, 50, 0, MODE_EMA, PRICE_CLOSE);
   g_AnaHandleBB     = iBands(_Symbol, g_Ana_TF, 20, 0, 2.0, PRICE_CLOSE);
   // Multi-TF: D1
   g_AnaHandleADX_D1  = iADX(_Symbol, PERIOD_D1, 14);
   g_AnaHandleRSI_D1  = iRSI(_Symbol, PERIOD_D1, 14, PRICE_CLOSE);
   g_AnaHandleEMA200D1= iMA(_Symbol, PERIOD_D1, 200, 0, MODE_EMA, PRICE_CLOSE);
   string tfStr = StringSubstr(EnumToString(g_Ana_TF), 7);
   AddLog("[ANALISE] Modo Analise ATIVADO. TF: " + tfStr + " | Aguarde indicadores carregarem...");
}

void AtualizarSensoresAnalise() {
   double buf[]; ArraySetAsSeries(buf, true);
   // ADX local
   if(g_AnaHandleADX!=INVALID_HANDLE && CopyBuffer(g_AnaHandleADX,0,0,1,buf)>0) g_Ana_ADX=buf[0];
   // RSI local
   if(g_AnaHandleRSI!=INVALID_HANDLE && CopyBuffer(g_AnaHandleRSI,0,0,1,buf)>0) g_Ana_RSI=buf[0];
   // MACD Main e Signal
   if(g_AnaHandleMACD!=INVALID_HANDLE) {
      if(CopyBuffer(g_AnaHandleMACD,0,0,1,buf)>0) g_Ana_MACD_Main=buf[0];
      if(CopyBuffer(g_AnaHandleMACD,1,0,1,buf)>0) g_Ana_MACD_Signal=buf[0];
   }
   // Estocastico %K
   if(g_AnaHandleStoch!=INVALID_HANDLE && CopyBuffer(g_AnaHandleStoch,0,0,1,buf)>0) g_Ana_Stoch=buf[0];
   // EMA50 local
   if(g_AnaHandleEMA50!=INVALID_HANDLE && CopyBuffer(g_AnaHandleEMA50,0,0,1,buf)>0) g_Ana_EMA50=buf[0];
   // Bollinger Bands: Upper=0 Middle=1 Lower=2
   if(g_AnaHandleBB!=INVALID_HANDLE) {
      if(CopyBuffer(g_AnaHandleBB,1,0,1,buf)>0) g_Ana_BB_Middle=buf[0];
      if(CopyBuffer(g_AnaHandleBB,0,0,1,buf)>0) g_Ana_BB_Upper=buf[0];
      if(CopyBuffer(g_AnaHandleBB,2,0,1,buf)>0) g_Ana_BB_Lower=buf[0];
   }
   // ADX D1
   if(g_AnaHandleADX_D1!=INVALID_HANDLE && CopyBuffer(g_AnaHandleADX_D1,0,0,1,buf)>0) g_Ana_ADX_D1=buf[0];
   // RSI D1
   if(g_AnaHandleRSI_D1!=INVALID_HANDLE && CopyBuffer(g_AnaHandleRSI_D1,0,0,1,buf)>0) g_Ana_RSI_D1=buf[0];
   // EMA200 D1
   if(g_AnaHandleEMA200D1!=INVALID_HANDLE && CopyBuffer(g_AnaHandleEMA200D1,0,0,1,buf)>0) g_Ana_EMA200_D1=buf[0];

   // === CALCULO DO SCORE (0-10) ===
   int score = 0;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spr = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double atr_ref_pts = InpDynamicAtrRef;  // referencia ATR em pontos
   double atv_pts = (g_ATR_Value > 0) ? g_ATR_Value / _Point : 0;

   // ADX: tendencia ou lateral (+2)
   if(g_Ana_ADX >= 25)      score += 2;  // mercado trending
   else if(g_Ana_ADX < 20)  score += 1;  // mercado ranging (hedge favorece)

   // RSI neutro (+2), extremo (+1)
   if(g_Ana_RSI > 30 && g_Ana_RSI < 70) score += 2;
   else                                  score += 1;  // extremo: cuidado mas pode operar

   // [BUG-M4 FIX] MACD: +1 apenas se Main e Signal apontam na mesma direcao (cruzamento limpo)
   // Antes: sempre +1 pois MACD nunca e exatamente 0
   if((g_Ana_MACD_Main > 0 && g_Ana_MACD_Signal > 0) ||
      (g_Ana_MACD_Main < 0 && g_Ana_MACD_Signal < 0)) score += 1;

   // BB nao em squeeze: BB_Width > 0.3% do middle (+2)
   if(g_Ana_BB_Middle > 0) {
      double bbW = (g_Ana_BB_Upper - g_Ana_BB_Lower) / g_Ana_BB_Middle * 100.0;
      if(bbW > 0.3) score += 2;
      else          score += 0;  // squeeze: volatilidade muito baixa
   }

   // Spread saudavel (+2)
   if(spr <= InpMaxSpread * 0.7) score += 2;
   else if(spr <= InpMaxSpread)  score += 1;

   // ATR saudavel: >= 50% da referencia (+1)
   if(atr_ref_pts > 0 && atv_pts >= atr_ref_pts * 0.5) score += 1;

   g_Ana_Score = score;  // 0-10
}

void LimparLinhasAnalise() {
   // Remove todos objetos com prefixo PANEL_PREFIX + AN_
   for(int i=ObjectsTotal(0,0,-1)-1; i>=0; i--) {
      string nm = ObjectName(0, i, 0, -1);
      if(StringFind(nm, PANEL_PREFIX+"AN_") == 0) ObjectDelete(0, nm);
   }
   ChartRedraw(0);
}

void LimparIndicadoresAnalise() {
   // Remove os indicadores (EMAs e Bands) do grafico com seguranca
   int indTotal = ChartIndicatorsTotal(0, 0);
   for(int i = indTotal - 1; i >= 0; i--) {
       string indName = ChartIndicatorName(0, 0, i);
       if(StringFind(indName, "MA(50)") >= 0 || 
          StringFind(indName, "MA(200)") >= 0 || 
          StringFind(indName, "Bands(20,") >= 0) {
           ChartIndicatorDelete(0, 0, indName);
       }
   }
}

void AnaHLine(string id, double price, color clr, ENUM_LINE_STYLE sty, int width, string tooltip) {
   if(price <= 0) return;
   string nm = PANEL_PREFIX + "AN_" + id;
   if(ObjectFind(0, nm) < 0) ObjectCreate(0, nm, OBJ_HLINE, 0, 0, price);
   ObjectSetDouble(0, nm, OBJPROP_PRICE, price);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, nm, OBJPROP_STYLE, sty);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, nm, OBJPROP_BACK, true);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetString(0, nm, OBJPROP_TOOLTIP, tooltip);
   
   // Textos flutuantes removidos para limpar o grafico. A identificacao agora e feita pela Legenda no canto da tela.
}

void AnaLevelArrow(string id, double price, bool isResistance, color clr, int time_shift_candles=0) {
   if(price <= 0) return;
   string arrNm = PANEL_PREFIX + "AN_ARR_" + id;
   int safe_shift = time_shift_candles;
   if(safe_shift >= Bars(_Symbol, PERIOD_CURRENT)) safe_shift = 0;
   datetime time = iTime(_Symbol, PERIOD_CURRENT, safe_shift);
   if(ObjectFind(0, arrNm) < 0) ObjectCreate(0, arrNm, OBJ_ARROW, 0, time, price);
   ObjectSetInteger(0, arrNm, OBJPROP_TIME, time);
   ObjectSetDouble(0, arrNm, OBJPROP_PRICE, price);
   ObjectSetInteger(0, arrNm, OBJPROP_ARROWCODE, isResistance ? 234 : 233); // 234=Seta Baixo, 233=Seta Cima
   ObjectSetInteger(0, arrNm, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, arrNm, OBJPROP_WIDTH, 2);
}

void DesenharLinhasAnalise() {
   if(!g_ModoAnalise) { LimparLinhasAnalise(); return; }
   double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atrVal  = g_ATR_Value;

   // As EMAs e Bollinger Bands agora sao curvas reais plotadas no grafico (via OnChartEvent)

   // --- SISTEMA DE LEGENDA DINAMICA ---
   string leg_text[15];
   color  leg_color[15];
   int    leg_count = 0;
   
   leg_text[leg_count] = "--- ELEMENTOS ATIVOS NA TELA ---"; leg_color[leg_count] = clrGray; leg_count++;
   leg_text[leg_count] = "Canal Macro"; leg_color[leg_count] = C'40,100,160'; leg_count++;
   leg_text[leg_count] = "Canal Micro"; leg_color[leg_count] = clrOrange; leg_count++;

   // Projecao ATR +1 e -1 (pontos esperados de movimento)
   if(atrVal > 0) {
      AnaHLine("ATR_UP", bid + atrVal, C'30,160,80', STYLE_DOT, 1, "Projecao ATR +1x");
      leg_text[leg_count] = "Alvo ATR +1 [" + DoubleToString(bid + atrVal, _Digits) + "]"; 
      leg_color[leg_count] = C'30,160,80'; leg_count++;
      
      AnaHLine("ATR_DN", bid - atrVal, C'180,50,50', STYLE_DOT, 1, "Projecao ATR -1x");
      leg_text[leg_count] = "Alvo ATR -1 [" + DoubleToString(bid - atrVal, _Digits) + "]"; 
      leg_color[leg_count] = C'180,50,50'; leg_count++;
   }

   // FILTRO DE PROXIMIDADE INTELIGENTE: So desenha se estiver dentro de 3.0x o ATR (foco no que importa na sessao)
   // GUARD: se atrVal for 0 (indicador nao carregou ainda), usa 50 pips como fallback para nao esconder tudo
   double max_dist = (atrVal > 0) ? atrVal * 3.0 : 0.0050;
   
   if(g_FR_H4_Sup > 0 && MathAbs(g_FR_H4_Sup - bid) <= max_dist) {
      bool isRes = (g_FR_H4_Sup > bid);
      string lbl = (isRes ? "Resistência" : "Suporte") + " H4 (Fundo)";
      AnaHLine("FR_SUP", g_FR_H4_Sup, C'120,80,220', STYLE_SOLID, 1, lbl);
      AnaLevelArrow("ARR_SUP_H4", g_FR_H4_Sup, isRes, C'120,80,220', 2);
      
      leg_text[leg_count] = lbl + " [" + DoubleToString(g_FR_H4_Sup, _Digits) + "]";
      leg_color[leg_count] = C'120,80,220'; leg_count++;
   }
   if(g_FR_H4_Res > 0 && MathAbs(g_FR_H4_Res - bid) <= max_dist) {
      bool isRes = (g_FR_H4_Res > bid);
      string lbl = (isRes ? "Resistência" : "Suporte") + " H4 (Topo)";
      AnaHLine("FR_RES", g_FR_H4_Res, C'220,160,0', STYLE_SOLID, 1, lbl);
      AnaLevelArrow("ARR_RES_H4", g_FR_H4_Res, isRes, C'220,160,0', 2);
      
      leg_text[leg_count] = lbl + " [" + DoubleToString(g_FR_H4_Res, _Digits) + "]";
      leg_color[leg_count] = C'220,160,0'; leg_count++;
   }
   if(g_FR_D1_Sup > 0 && MathAbs(g_FR_D1_Sup - bid) <= max_dist) {
      bool isRes = (g_FR_D1_Sup > bid);
      string lbl = (isRes ? "Resistência" : "Suporte") + " D1 (Fundo)";
      AnaHLine("FR_SUP_D1", g_FR_D1_Sup, C'80,50,180', STYLE_SOLID, 1, lbl);
      AnaLevelArrow("ARR_SUP_D1", g_FR_D1_Sup, isRes, C'80,50,180', 22);
      
      if(leg_count < 15) { leg_text[leg_count] = lbl + " [" + DoubleToString(g_FR_D1_Sup, _Digits) + "]"; leg_color[leg_count] = C'80,50,180'; leg_count++; }
   }
   if(g_FR_D1_Res > 0 && MathAbs(g_FR_D1_Res - bid) <= max_dist) {
      bool isRes = (g_FR_D1_Res > bid);
      string lbl = (isRes ? "Resistência" : "Suporte") + " D1 (Topo)";
      AnaHLine("FR_RES_D1", g_FR_D1_Res, C'180,130,0', STYLE_SOLID, 1, lbl);
      AnaLevelArrow("ARR_RES_D1", g_FR_D1_Res, isRes, C'180,130,0', 22);
      
      if(leg_count < 15) { leg_text[leg_count] = lbl + " [" + DoubleToString(g_FR_D1_Res, _Digits) + "]"; leg_color[leg_count] = C'180,130,0'; leg_count++; }
   }

   // === MARCACOES VISUAIS DIRETAS NO GRAFICO (CANAIS E SETAS) ===
   
   // 1. Canal de Regressao Linear MACRO (Longo Prazo)
   string regNmMacro = PANEL_PREFIX + "AN_TrendChannelMacro";
   int bars_macro = 150; // Quantidade de candles para tras
   if(Bars(_Symbol, PERIOD_CURRENT) > bars_macro) {
      datetime t_start = iTime(_Symbol, PERIOD_CURRENT, bars_macro);
      datetime t_end   = iTime(_Symbol, PERIOD_CURRENT, 0);
      if(ObjectFind(0, regNmMacro) < 0) {
         ObjectCreate(0, regNmMacro, OBJ_REGRESSION, 0, t_start, 0, t_end, 0);
      } else {
         ObjectSetInteger(0, regNmMacro, OBJPROP_TIME, 0, t_start);
         ObjectSetInteger(0, regNmMacro, OBJPROP_TIME, 1, t_end);
      }
      ObjectSetInteger(0, regNmMacro, OBJPROP_COLOR, C'40,100,160'); // Azul discreto
      ObjectSetInteger(0, regNmMacro, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, regNmMacro, OBJPROP_RAY_RIGHT, false); // CORRIGIDO: false para nao vazar alem do eixo direito
      ObjectSetInteger(0, regNmMacro, OBJPROP_BACK, true);
      ObjectSetInteger(0, regNmMacro, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, regNmMacro, OBJPROP_TOOLTIP, "Canal Macro (150 velas)");
   }

   // 1.5 Canal de Regressao Linear MICRO (Curto Prazo - Movimento Recente)
   string regNmMicro = PANEL_PREFIX + "AN_TrendChannelMicro";
   int bars_micro = 45; // Captura a pernada atual
   if(Bars(_Symbol, PERIOD_CURRENT) > bars_micro) {
      datetime t_start = iTime(_Symbol, PERIOD_CURRENT, bars_micro);
      datetime t_end   = iTime(_Symbol, PERIOD_CURRENT, 0);
      if(ObjectFind(0, regNmMicro) < 0) {
         ObjectCreate(0, regNmMicro, OBJ_REGRESSION, 0, t_start, 0, t_end, 0);
      } else {
         ObjectSetInteger(0, regNmMicro, OBJPROP_TIME, 0, t_start);
         ObjectSetInteger(0, regNmMicro, OBJPROP_TIME, 1, t_end);
      }
      ObjectSetInteger(0, regNmMicro, OBJPROP_COLOR, clrOrange); // Cor quente para destacar o curto prazo
      ObjectSetInteger(0, regNmMicro, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, regNmMicro, OBJPROP_STYLE, STYLE_DASH); // Tracejado para diferenciar do Macro
      ObjectSetInteger(0, regNmMicro, OBJPROP_RAY_RIGHT, false); // Nao estendemos ao infinito para nao poluir
      ObjectSetInteger(0, regNmMicro, OBJPROP_BACK, true);
      ObjectSetInteger(0, regNmMicro, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, regNmMicro, OBJPROP_TOOLTIP, "Canal Micro (Pernada Atual - 45 velas)");
   }

   // 2. Diagnostico - INCLINACAO INDEPENDENTE de cada canal
   // Macro: Tendencia das primeiras 105 velas (candle[150] -> candle[46])
   // Micro: Tendencia das ultimas 45 velas   (candle[45] -> candle[0])
   // Dessa forma os dois sao TOTALMENTE independentes e divergencias geram o amarelo correto.
   // GUARD: garante que ha velas suficientes para os calculos de inclinacao
   // BUG #8 FIX: Usa MathMax(bars_macro, bars_micro) + 1 para ser resiliente a mudancas futuras das constantes.
   int totalBars    = Bars(_Symbol, PERIOD_CURRENT);
   int minBarsNeed  = MathMax(bars_macro, bars_micro) + 1;
   if(totalBars < minBarsNeed) {
      DesenharLegendaAnalise(leg_count, leg_text, leg_color, "Aguardando dados...", clrGray);
      return;
   }
   
   double closeMacroStart = iClose(_Symbol, PERIOD_CURRENT, 150);
   double closeMacroEnd   = iClose(_Symbol, PERIOD_CURRENT, 46); // fim da zona macro (antes da micro comecar)
   double closeMicroStart = iClose(_Symbol, PERIOD_CURRENT, 45);
   
   bool isMacroUp = (closeMacroStart > 0 && closeMacroEnd   > closeMacroStart);
   bool isMicroUp = (closeMicroStart > 0 && bid             > closeMicroStart);
   
   string diagnostic = "";
   color  diagClr = clrWhite;
   
   if(isMacroUp && isMicroUp) {
       diagnostic = "FORÇA TOTAL (Macro e Micro: ALTA)";
       diagClr = clrLimeGreen;
   } else if(!isMacroUp && !isMicroUp) {
       diagnostic = "FORÇA TOTAL (Macro e Micro: BAIXA)";
       diagClr = clrRed;
   } else if(isMacroUp && !isMicroUp) {
       diagnostic = "CORREÇÃO (Micro: Baixa | Macro: Alta)";
       diagClr = clrGold;
   } else if(!isMacroUp && isMicroUp) {
       diagnostic = "REPIQUE (Micro: Alta | Macro: Baixa)";
       diagClr = clrGold;
   }
   
   DesenharLegendaAnalise(leg_count, leg_text, leg_color, diagnostic, diagClr);
}

void DesenharLegendaAnalise(int count, string &texts[], color &clrs[], string diag_text="", color diag_color=clrNONE) {
   // Remove legados antigos para garantir limpeza
   for(int i=0; i<15; i++) {
      string nm = PANEL_PREFIX + "AN_LEG_" + IntegerToString(i);
      ObjectDelete(0, nm);
   }
   ObjectDelete(0, PANEL_PREFIX + "AN_LEG_DIAG_BTN"); // Limpa o botao caso exista
   
   for(int i=0; i<count; i++) {
      string nm = PANEL_PREFIX + "AN_LEG_" + IntegerToString(i);
      ObjectCreate(0, nm, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, nm, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, 20 + (i * 14)); // Espacamento mais suave
      ObjectSetString(0, nm, OBJPROP_TEXT, texts[i]);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, clrs[i]);
      ObjectSetString(0, nm, OBJPROP_FONT, "Calibri"); // Fonte discreta e elegante
      ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, nm, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0, nm, OBJPROP_BACK, false);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   }
   
   if(diag_text != "") {
      string btnNm = PANEL_PREFIX + "AN_LEG_DIAG_BTN";
      if(ObjectFind(0, btnNm) < 0) ObjectCreate(0, btnNm, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, btnNm, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, btnNm, OBJPROP_XDISTANCE, 230); // Largura (220) + margem direita (10)
      ObjectSetInteger(0, btnNm, OBJPROP_YDISTANCE, 20 + (count * 14) + 10); 
      ObjectSetInteger(0, btnNm, OBJPROP_XSIZE, 220); // Botao mais largo para caber a info completa
      ObjectSetInteger(0, btnNm, OBJPROP_YSIZE, 20);
      ObjectSetString(0, btnNm, OBJPROP_TEXT, diag_text);
      ObjectSetInteger(0, btnNm, OBJPROP_BGCOLOR, diag_color);
      // Texto preto para fundos claros/fortes, branco para fundos escuros
      bool isBrightBg = (diag_color == clrGold || diag_color == clrYellow || 
                         diag_color == clrLimeGreen || diag_color == clrLime ||
                         diag_color == clrAqua || diag_color == clrWhite);
      ObjectSetInteger(0, btnNm, OBJPROP_COLOR, isBrightBg ? clrBlack : clrWhite);
      ObjectSetString(0, btnNm, OBJPROP_FONT, "Calibri");
      ObjectSetInteger(0, btnNm, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, btnNm, OBJPROP_STATE, false);
      ObjectSetInteger(0, btnNm, OBJPROP_SELECTABLE, false);
      g_AnaliseLegendHeight = 20 + (count * 14) + 10 + 20 + 10;
   } else {
      g_AnaliseLegendHeight = (count > 0) ? (20 + (count * 14) + 10) : 0;
   }
}

//===================================================================
// INTEGRACAO WEB — Envia estado do robo para o Dashboard Orion
//===================================================================
datetime g_WebUltimoEnvio = 0;

string ExtractJsonString(string block, string key) {
   string search = "\"" + key + "\":\"";
   int p = StringFind(block, search);
   if(p < 0) return "";
   p += StringLen(search);
   int endP = StringFind(block, "\"", p);
   if(endP < 0) return "";
   return StringSubstr(block, p, endP - p);
}

long ExtractJsonInteger(string block, string key) {
   string search = "\"" + key + "\":";
   int p = StringFind(block, search);
   if(p < 0) return 0;
   p += StringLen(search);
   int endP = p;
   while(endP < StringLen(block)) {
      ushort c = StringGetCharacter(block, endP);
      if(c >= '0' && c <= '9') endP++;
      else break;
   }
   if(endP > p) {
      return StringToInteger(StringSubstr(block, p, endP - p));
   }
   return 0;
}

int ObterNivelPosicao(string comment, string typeStr) {
   string prefix = (typeStr == "BUY") ? "OH_B" : "OH_S";
   if(StringSubstr(comment, 0, 4) == prefix) {
      return (int)StringToInteger(StringSubstr(comment, 4));
   }
   return 1; // Fallback para nivel 1
}

void ProcessarComandosServidor(string resp) {
   int startPos = 0;
   while(true) {
      int pos = StringFind(resp, "{\"id\":", startPos);
      if(pos < 0) break;
      
      int endPos = StringFind(resp, "}", pos);
      if(endPos < 0) break;
      
      string block = StringSubstr(resp, pos, endPos - pos + 1);
      startPos = endPos + 1; // Move past this block
      
      long cmdId = ExtractJsonInteger(block, "id");
      if(cmdId <= 0) continue;
      
      string command = ExtractJsonString(block, "command");
      string symbol = ExtractJsonString(block, "symbol");
      
      bool applicable = false;
      if(command == "PANIC_GLOBAL" || command == "PAUSE" || command == "RESUME" || command == "RESET_STATS") {
         applicable = true;
      } else if(command == "PANIC_LOCAL" && symbol == _Symbol) {
         applicable = true;
      }
      
      if(!applicable) continue;
      
      // Executa o comando correspondente
      if(command == "PANIC_GLOBAL") {
         AddLog("[WEB] COMANDO REMOTO: PANICO GLOBAL recebido!");
         FecharTudo();
      } else if(command == "PANIC_LOCAL") {
         AddLog("[WEB] COMANDO REMOTO: PANICO LOCAL para " + _Symbol + " recebido!");
         FecharLocal();
         g_BotPaused = true;
      } else if(command == "PAUSE") {
         if(!g_BotPaused) {
            g_BotPaused = true;
            GlobalVariableSet("OrionHedge_Global_BotPaused", 1.0);
            AddLog("[WEB] COMANDO REMOTO: PAUSAR recebido.");
         }
      } else if(command == "RESUME") {
         if(g_BotPaused) {
            g_BotPaused = false;
            GlobalVariableSet("OrionHedge_Global_BotPaused", 0.0);
            AddLog("[WEB] COMANDO REMOTO: RETOMAR recebido.");
         }
      } else if(command == "RESET_STATS") {
         AddLog("[WEB] COMANDO REMOTO: RESET_STATS recebido.");
         g_InicioHistorico = TimeCurrent();
         g_InicioHistoricoSymbol = g_InicioHistorico;
         GlobalVariableSet("OrionHedge_Global_ResetTime", (double)g_InicioHistorico);
         GlobalVariableSet("OrionHedge_ResetTime_" + _Symbol, (double)g_InicioHistoricoSymbol);
         GuardarResetTime("global", g_InicioHistorico);
         GuardarResetTime(_Symbol, g_InicioHistoricoSymbol);
         
         g_EquityCycleBaseBalance = AccountInfoDouble(ACCOUNT_BALANCE);
         GlobalVariableSet("OrionHedge_Global_EqBase", g_EquityCycleBaseBalance);
         GlobalVariableSet("OrionHedge_Global_DDReached10", 0.0);
         GlobalVariableSet("OrionHedge_Global_DDReached20", 0.0);
         GlobalVariableSet("OrionHedge_Global_TrailingActive", 0.0);
         GlobalVariableSet("OrionHedge_Global_PeakProfit", 0.0);
         
         g_DealsCountCache = -1; // Forca recalculacao imediata
      }
      
      // Adiciona o ID do comando executado para confirmacao
      bool dup = false;
      for(int j = 0; j < g_ExecCmdCount; j++) {
         if(g_ExecCmdIds[j] == (int)cmdId) { dup = true; break; }
      }
      if(!dup) {
         ArrayResize(g_ExecCmdIds, g_ExecCmdCount + 1);
         g_ExecCmdIds[g_ExecCmdCount] = (int)cmdId;
         g_ExecCmdCount++;
      }
   }
}

void EnviarDadosWeb() {
   if(!InpWebAtiva) return;
   if(TimeLocal() - g_WebUltimoEnvio < InpWebIntervalo) return;
   g_WebUltimoEnvio = TimeLocal();

   double bal    = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq     = AccountInfoDouble(ACCOUNT_EQUITY);
   long   acc    = AccountInfoInteger(ACCOUNT_LOGIN);
   
   // BUG #10: Calcular PNL global consolidado de todas as moedas operadas pelo Orion
   double global_profit = 0, global_swap = 0;
   for(int i = 0; i < PositionsTotal(); i++) {
      ulong tck = PositionGetTicket(i);
      if(tck > 0) {
         long mag = PositionGetInteger(POSITION_MAGIC);
         if(mag >= InpMagicNumberBase && mag <= InpMagicNumberBase + 999999) {
            global_swap   += PositionGetDouble(POSITION_SWAP);
            global_profit += PositionGetDouble(POSITION_PROFIT);
         }
      }
   }
   double global_total = global_profit + global_swap;
   double ddPct  = (bal > 0) ? (MathAbs(MathMin(0.0, global_total)) / bal * 100.0) : 0.0;
   string status = g_BotPaused ? "PAUSED" : "RUNNING";

   // Construir JSON de posicoes abertas
   string tradesJson = "";
   int cnt = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      ulong tk = PositionGetTicket(i);
      if(!PositionSelectByTicket(tk)) continue;
      long mag = PositionGetInteger(POSITION_MAGIC);
      if(mag != g_MagicBuy && mag != g_MagicSell) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      double prof = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      double vol  = PositionGetDouble(POSITION_VOLUME);
      double ep   = PositionGetDouble(POSITION_PRICE_OPEN);
      double curPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double tp   = (dir == "BUY") ? g_BuyAlvo : g_SellAlvo;
      double sl   = (dir == "BUY") ? g_BuyProxPreco : g_SellProxPreco;
      
      // BUG #15: POSITION_IDENTIFIER substituído pelo nível real da grade a partir do comentário
      string comment = PositionGetString(POSITION_COMMENT);
      int level = ObterNivelPosicao(comment, dir);
      
      bool isSos = (dir == "BUY") ? g_BuySaidaZeroAtiva : g_SellSaidaZeroAtiva;
      if(cnt > 0) tradesJson += ",";
      tradesJson += "{\"ticket\":\"" + IntegerToString(tk) + "\",\"symbol\":\"" + _Symbol + "\",\"type\":\"" + dir + "\",\"volume\":" + DoubleToString(vol,2)
                 + ",\"entryPrice\":" + DoubleToString(ep,5) + ",\"currentPrice\":" + DoubleToString(curPrice,5) + ",\"currentProfit\":" + DoubleToString(prof,2)
                 + ",\"tp\":" + DoubleToString(tp,5) + ",\"sl\":" + DoubleToString(sl,5) + ",\"grade\":" + IntegerToString(level)
                 + ",\"magicNumber\":" + IntegerToString((int)mag) + ",\"sosScheduled\":" + (isSos ? "true" : "false") + "}";
      cnt++;
   }

   // Construir historico dos ultimos 30 dias para o grafico
   string histJson = "";
   int histCnt = 0;
   
   struct SDailyPerf {
      string dateStr;
      double profit;
      double gain;
      double loss;
      double balance;
      bool hasDeals;
      datetime date;
   };
   SDailyPerf dailyData[30];
   datetime nowTime = TimeCurrent();
   datetime timeLimit = TimeLocal() - (30 * 24 * 60 * 60);
   
   // Inicializar array de 30 dias (do mais antigo ao mais recente)
   for(int k = 0; k < 30; k++) {
      datetime dayTime = nowTime - (29 - k) * 86400;
      MqlDateTime md;
      TimeToStruct(dayTime, md);
      datetime startOfDay = NormalizarDia(dayTime);
      
      string dStr = StringFormat("%04d-%02d-%02d", md.year, md.mon, md.day);
      
      dailyData[k].date = startOfDay;
      dailyData[k].dateStr = dStr;
      dailyData[k].profit = 0.0;
      dailyData[k].gain = 0.0;
      dailyData[k].loss = 0.0;
      dailyData[k].balance = 0.0;
      dailyData[k].hasDeals = false;
   }
   
   // Query de historico de 30 dias
   if(HistorySelect(timeLimit, TimeCurrent())) {
      int dealsTotal = HistoryDealsTotal();
      for(int i = 0; i < dealsTotal; i++) {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0) {
            long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
            if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT) {
               long mag = HistoryDealGetInteger(ticket, DEAL_MAGIC);
               datetime dt = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
               
               bool isOrionDeal = false;
               if(dt >= g_InicioHistorico) {
                  isOrionDeal = true;
               } else if(mag >= InpMagicNumberBase && mag <= InpMagicNumberBase + 999999) {
                  isOrionDeal = true;
               }
               
               if(isOrionDeal) {
                  double prof = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                  double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
                  double comm = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
                  double totalDealProfit = prof + swap + comm;
                  
                  datetime dealDay = NormalizarDia(dt);
                  for(int k = 0; k < 30; k++) {
                     if(dailyData[k].date == dealDay) {
                        dailyData[k].profit += totalDealProfit;
                        if(totalDealProfit >= 0) {
                           dailyData[k].gain += totalDealProfit;
                        } else {
                           dailyData[k].loss += totalDealProfit;
                        }
                        dailyData[k].hasDeals = true;
                        break;
                     }
                  }
               }
            }
         }
      }
   }

   // BUG #3: Calcular saldo inicial do período de 30 dias subtraindo os lucros das transações no período
   double totalProfitInWindow = 0.0;
   if(HistorySelect(timeLimit, TimeCurrent())) {
      int dealsTotal = HistoryDealsTotal();
      for(int i = 0; i < dealsTotal; i++) {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0) {
            long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
            if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT) {
               long mag = HistoryDealGetInteger(ticket, DEAL_MAGIC);
               datetime dt = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
               
               bool isOrionDeal = false;
               if(dt >= g_InicioHistorico) {
                  isOrionDeal = true;
               } else if(mag >= InpMagicNumberBase && mag <= InpMagicNumberBase + 999999) {
                  isOrionDeal = true;
               }
               
               if(isOrionDeal) {
                  double prof = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                  double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
                  double comm = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
                  totalProfitInWindow += prof + swap + comm;
               }
            }
         }
      }
   }
   
   double runningBal = bal - totalProfitInWindow;
   
   // Loop progressivo (cronológico) para aplicar o lucro e obter o saldo ao fim de cada dia
   if(HistorySelect(timeLimit, TimeCurrent())) {
      int dealsTotal = HistoryDealsTotal();
      for(int i = 0; i < dealsTotal; i++) {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0) {
            long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
            if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT) {
               long mag = HistoryDealGetInteger(ticket, DEAL_MAGIC);
               datetime dt = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
               
               bool isOrionDeal = false;
               if(dt >= g_InicioHistorico) {
                  isOrionDeal = true;
               } else if(mag >= InpMagicNumberBase && mag <= InpMagicNumberBase + 999999) {
                  isOrionDeal = true;
               }
               
               if(isOrionDeal) {
                  double prof = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                  double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
                  double comm = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
                  double totalDealProfit = prof + swap + comm;
                  
                  runningBal += totalDealProfit;
                  
                  datetime dealDay = NormalizarDia(dt);
                  for(int k = 0; k < 30; k++) {
                     if(dailyData[k].date == dealDay) {
                        dailyData[k].balance = runningBal; // Armazena o saldo mais recente do dia
                        break;
                     }
                  }
               }
            }
         }
      }
   }
   
   double lastKnownBalance = bal - totalProfitInWindow; // Caso não haja operações nos primeiros dias, começa do saldo inicial
   for(int k = 0; k < 30; k++) {
      if(dailyData[k].balance > 0.0) {
         lastKnownBalance = dailyData[k].balance;
      } else {
         dailyData[k].balance = lastKnownBalance;
      }
      
      if(histCnt > 0) histJson += ",";
      histJson += "{\"date\":\"" + dailyData[k].dateStr + "\",\"profit\":" + DoubleToString(dailyData[k].profit,2) + ",\"gain\":" + DoubleToString(dailyData[k].gain,2) + ",\"loss\":" + DoubleToString(dailyData[k].loss,2) + ",\"balance\":" + DoubleToString(dailyData[k].balance,2) + "}";
      histCnt++;
   }

   // Construir payload JSON completo
   string body = "{";
   body += "\"token\":\"" + InpWebApiKey + "\",";
   body += "\"account\":\"" + IntegerToString(acc) + "\",";
   body += "\"balance\":" + DoubleToString(bal, 2) + ",";
   body += "\"equity\":" + DoubleToString(eq, 2) + ",";
   body += "\"softStopLimit\":" + DoubleToString(g_SoftStopAtual, 2) + ",";
   body += "\"loteBase\":" + DoubleToString(g_LoteBase, 3) + ",";
   body += "\"takeProfitLimit\":" + DoubleToString(g_TakeProfitAtual, 2) + ",";
   // BUG #7: brlRate compensando o fator centavo (multiplicando por 100 se for conta padrão)
   double brlRateToSend = g_TaxaBRLAtual;
   string accCurr = AccountInfoString(ACCOUNT_CURRENCY);
   if(StringFind(accCurr, "USC") < 0 && StringFind(accCurr, "Cent") < 0 && StringFind(accCurr, "c") < 0) {
      brlRateToSend = g_TaxaBRLAtual * 100.0;
   }
   body += "\"brlRate\":" + DoubleToString(brlRateToSend, 4) + ",";
   body += "\"dailyProfit\":" + DoubleToString(g_HistLucroHoje, 2) + ",";
   body += "\"floatingPl\":" + DoubleToString(global_total, 2) + ",";
   body += "\"totalProfit\":" + DoubleToString(g_HistLucroGlobal, 2) + ",";
   body += "\"maxDrawdown\":" + DoubleToString(ddPct, 2) + ",";
   body += "\"status\":\"" + status + "\",";
   body += "\"symbol\":\"" + _Symbol + "\",";
   body += "\"newsActive\":" + (g_NewsActive ? "true" : "false") + ",";
   body += "\"newsFrozen\":" + (g_NewsFrozen ? "true" : "false") + ",";
   
   string newsClean = g_NewsName;
   StringReplace(newsClean, "\"", "\\\"");
   StringReplace(newsClean, "\n", " ");
   StringReplace(newsClean, "\r", "");
   StringReplace(newsClean, "\t", " ");
   body += "\"newsName\":\"" + newsClean + "\",";
   body += "\"trailingActive\":" + (g_TrailingActive ? "true" : "false") + ",";
   body += "\"trailingPeak\":" + DoubleToString(g_PeakProfit, 2) + ",";
   body += "\"ddReached10\":" + (g_DD_Reached10 ? "true" : "false") + ",";
   body += "\"ddReached20\":" + (g_DD_Reached20 ? "true" : "false") + ",";
   body += "\"buySosScheduled\":" + (g_BuySaidaZeroAtiva ? "true" : "false") + ",";
   body += "\"sellSosScheduled\":" + (g_SellSaidaZeroAtiva ? "true" : "false") + ",";
   
   double currentTargetPct = InpMetaCicloEquityPct;
   body += "\"equityCycleBase\":" + DoubleToString(g_EquityCycleBaseBalance, 2) + ",";
   body += "\"equityCycleTargetPct\":" + DoubleToString(currentTargetPct, 2) + ",";
   body += "\"trades\":[" + tradesJson + "],";
   body += "\"history\":[" + histJson + "]";
   
   // Append executed command confirmations
   string execCmdsJson = "";
   for(int k = 0; k < g_ExecCmdCount; k++) {
      if(k > 0) execCmdsJson += ",";
      execCmdsJson += IntegerToString(g_ExecCmdIds[k]);
   }
   body += ",\"executedCommands\":[" + execCmdsJson + "]";
   body += "}";

   char data[], result[];
   string headers = "Content-Type: application/json\r\nX-Api-Key: " + InpWebApiKey;
   int bodyLen = StringToCharArray(body, data, 0, -1, CP_UTF8);
   if(bodyLen > 1) {
      ArrayResize(data, bodyLen - 1);
   }

   string result_headers;
   int res = WebRequest("POST", InpWebUrl, headers, 5000, data, result, result_headers);
   if(res == -1) {
      static datetime logWebErr = 0;
      if(TimeLocal() - logWebErr > 60) {
         logWebErr = TimeLocal();
         int err = _LastError;
         AddLog("[WEB] Erro ao enviar dados (MQL5 Error " + IntegerToString(err) + "). Verifique a URL e permissoes WebRequest.");
      }
      return;
   }

   if(res < 200 || res >= 300) {
      static datetime logHttpErr = 0;
      if(TimeLocal() - logHttpErr > 60) {
         logHttpErr = TimeLocal();
         string respErr = CharArrayToString(result);
         AddLog("[WEB] Erro HTTP do servidor: " + IntegerToString(res) + ". Resposta: " + respErr);
      }
      return;
   }

   // Limpa comandos executados confirmados com sucesso!
   g_ExecCmdCount = 0;
   ArrayFree(g_ExecCmdIds);

   // Processar resposta: verifica e executa comandos aplicaveis com token
   if(ArraySize(result) > 2) {
      string resp = CharArrayToString(result);
      ProcessarComandosServidor(resp);
   }
}

//===================================================================
// TIMER
//===================================================================
void OnTimer() {
   // [v3.40 Senior Sync] Sincronizar variáveis globais do Ciclo de Equity entre todos os gráficos
   if(GlobalVariableCheck("OrionHedge_Global_EqBase")) {
      double savedBase = GlobalVariableGet("OrionHedge_Global_EqBase");
      if(savedBase > 0) g_EquityCycleBaseBalance = savedBase;
   }
   if(GlobalVariableCheck("OrionHedge_Global_TrailingActive")) {
      g_TrailingActive = (GlobalVariableGet("OrionHedge_Global_TrailingActive") > 0.5);
   }
   if(GlobalVariableCheck("OrionHedge_Global_PeakProfit")) {
      g_PeakProfit = GlobalVariableGet("OrionHedge_Global_PeakProfit");
   }
   if(GlobalVariableCheck("OrionHedge_Global_DDReached10")) {
      g_DD_Reached10 = (GlobalVariableGet("OrionHedge_Global_DDReached10") > 0.5);
   }
   if(GlobalVariableCheck("OrionHedge_Global_DDReached20")) {
      g_DD_Reached20 = (GlobalVariableGet("OrionHedge_Global_DDReached20") > 0.5);
   }

   // [v3.40] Atualizar taxa BRL dinâmica a cada 60 segundos
   static datetime lastBRLUpdate = 0;
   if(TimeCurrent() - lastBRLUpdate >= 60) {
      g_TaxaBRLAtual = ObterTaxaBRLDinamica();
      lastBRLUpdate = TimeCurrent();
   }
 
   // Atualizar cestos para garantir dados frescos no timer (mesmo sem ticks)
   AtualizarCestoBuy();
   AtualizarCestoSell();
   // Executar monitoramento S.O.S em baixa liquidez/sem ticks
   ProcessarAgendamentoSOS();

   // Sincronizar pause global (somente ativação forçada via Pânico)
   if(GlobalVariableCheck("OrionHedge_Global_BotPaused")) {
      if(GlobalVariableGet("OrionHedge_Global_BotPaused") > 0.5) {
         if(!g_BotPaused) {
            g_BotPaused = true;
            AddLog("Pausa Global detectada. Robo pausado.");
         }
      }
   }

    // Sincronizar data de reset global
    if(GlobalVariableCheck("OrionHedge_Global_ResetTime")) {
       datetime globReset = (datetime)GlobalVariableGet("OrionHedge_Global_ResetTime");
       
       bool aceitarSinc = false;
       if(globReset < g_InicioHistorico && globReset > 0) {
          // O valor global e anterior ao nosso (contem mais historico). Aceitamos para expandir o historico!
          aceitarSinc = true;
       } else if(globReset > g_InicioHistorico) {
          // O valor global e mais recente. So aceitamos se nao for o fallback de meia-noite (inicioDia),
          // o que indica que foi um reset manual ou ciclo de equity e nao uma falha de reboot.
          datetime inicioDia = NormalizarDia(TimeCurrent());
          if(globReset != inicioDia) {
             aceitarSinc = true;
          }
       }
       
       if(aceitarSinc) {
          g_InicioHistorico = globReset;
          g_InicioHistoricoSymbol = MathMax(g_InicioHistoricoSymbol, globReset);
          GlobalVariableSet("OrionHedge_ResetTime_" + _Symbol, (double)g_InicioHistoricoSymbol);
          GuardarResetTime("global", g_InicioHistorico);
          GuardarResetTime(_Symbol, g_InicioHistoricoSymbol);
          g_DealsCountCache = -1; // Forca recalcular
          AddLog("Reset/Sincronização Global detectada. Data ajustada para: " + TimeToString(g_InicioHistorico, TIME_DATE|TIME_MINUTES));
       }
    }

   // ===== SINCRONIZAR FILTRO GLOBAL COMPARTILHADO [v3.31] =====
   // Sincroniza modo + data inicio + data fim para garantir range identico em TODOS os pares
   if(GlobalVariableCheck("OrionHedge_Global_FiltroHistorico")) {
      int globHist = (int)GlobalVariableGet("OrionHedge_Global_FiltroHistorico");
      if(globHist != g_FiltroHistorico) {
         g_FiltroHistorico = globHist;
         g_DealsCountCache = -1; // Forca recalcular
      }
   }
   if(GlobalVariableCheck("OrionHedge_Global_FiltroDataIni")) {
      datetime globDataIni = (datetime)GlobalVariableGet("OrionHedge_Global_FiltroDataIni");
      if(globDataIni != g_FiltroDataIni) {
         g_FiltroDataIni = globDataIni;
         g_DealsCountCache = -1; // Forca recalcular
      }
   }
   // [v3.31 NOVO] Sincroniza data fim do filtro entre todos os pares
   if(GlobalVariableCheck("OrionHedge_Global_FiltroDataFim")) {
      datetime globDataFim = (datetime)GlobalVariableGet("OrionHedge_Global_FiltroDataFim");
      if(globDataFim != g_FiltroDataFim) {
         g_FiltroDataFim = globDataFim;
         g_DealsCountCache = -1; // Forca recalcular
      }
   }

   AtualizarLoteBase();
   AtualizarHistoricoGlobal();
   DesenharPainel();
   VerificarCicloEquity();
   DesenharLinhas();
   // Modo Analise: detecta mudanca de TF e atualiza tudo
   if(g_ModoAnalise) {
      ENUM_TIMEFRAMES tfAtual = ChartPeriod(0);
      if(tfAtual != g_Ana_TF) { // TF mudou! Limpa e reinicia os handles
         LimparLinhasAnalise();
         IniciarHandlesAnalise();
         AddLog("[ANALISE] TF mudou para " + EnumToString(tfAtual) + ". Analise reiniciada.");
      }
      AtualizarSensoresAnalise();
      DesenharLinhasAnalise();
   }
   
   // Enviar resumo PUSH a partir das 17:00 diariamente (horario local)
   // Usamos variavel global do terminal para evitar spam de multiplos graficos e manter controle entre restarts
   if(InpPushAtivo) {
      datetime agora = TimeLocal();
      MqlDateTime mdt;
      TimeToStruct(agora, mdt);
      if(mdt.hour >= 17) {
         datetime hoje = NormalizarDia(agora);
         string gvName = "OrionHedge_LastPushDate_Global";
         datetime lastSent = GlobalVariableCheck(gvName) ? (datetime)GlobalVariableGet(gvName) : 0;
         if(lastSent != hoje) {
            GlobalVariableSet(gvName, (double)hoje);
            EnviarResumoPush();
         }
      }
   }
   
   // === INTEGRACAO WEB: Enviar estado para o Dashboard Orion Hedge ===
   EnviarDadosWeb();

   ChartRedraw(0);
    if(g_PanicoAguardando&&(TimeCurrent()-g_PanicoTimestamp>3)){
       g_PanicoAguardando=false; AddLog("Panico global cancelado.");
    }
    if(g_PanicoLocalAguardando&&(TimeCurrent()-g_PanicoLocalTimestamp>3)){
       g_PanicoLocalAguardando=false; AddLog("Panico local cancelado.");
    }
 }

bool TemPosicoesGlobais() {
   for(int i = 0; i < PositionsTotal(); i++) {
      ulong tck = PositionGetTicket(i);
      if(tck > 0) {
         long mag = PositionGetInteger(POSITION_MAGIC);
         if(mag >= InpMagicNumberBase && mag <= InpMagicNumberBase + 999999) {
            return true;
         }
      }
   }
   return false;
}

bool TemPosicoesLocais() {
   for(int i = 0; i < PositionsTotal(); i++) {
      ulong tck = PositionGetTicket(i);
      if(tck > 0) {
         long mag = PositionGetInteger(POSITION_MAGIC);
         if((mag == g_MagicBuy || mag == g_MagicSell) && PositionGetString(POSITION_SYMBOL) == _Symbol) {
            return true;
         }
      }
   }
   return false;
}

void FecharCesto(bool isBuy) {
   int targetMagic = isBuy ? g_MagicBuy : g_MagicSell;
   ulong tickets[];
   int total = PositionsTotal();
   ArrayResize(tickets, total);
   int count = 0;
   
   for(int i = 0; i < total; i++) {
      ulong t = PositionGetTicket(i);
      if(t > 0) {
         if(PositionSelectByTicket(t)) {
            if(PositionGetInteger(POSITION_MAGIC) == targetMagic && PositionGetString(POSITION_SYMBOL) == _Symbol) {
               tickets[count] = t;
               count++;
            }
         }
      }
   }
   
   ArrayResize(tickets, count);
   for(int i = 0; i < count; i++) {
      trade.PositionClose(tickets[i]);
   }
   
   // [BUG-M3 FIX] Reset do tempo da barra para permitir novas recompras no mesmo candle
   if(isBuy) g_BuyLastBarTime = 0;
   else      g_SellLastBarTime = 0;
}

//===================================================================
// FECHAR TUDO (PANICO)
//===================================================================
void FecharTudo() {
   // Loop de retentativas para garantir o fechamento sob slippage/requotes
   for(int retry = 0; retry < 5; retry++) {
      ulong tickets[];
      int total = PositionsTotal();
      ArrayResize(tickets, total);
      int count = 0;
      
      for(int i = 0; i < total; i++) {
         ulong t = PositionGetTicket(i);
         if(t > 0) {
            if(PositionSelectByTicket(t)) {
               int mag = (int)PositionGetInteger(POSITION_MAGIC);
               if(mag >= InpMagicNumberBase && mag <= InpMagicNumberBase + 999999) {
                  tickets[count] = t;
                  count++;
               }
            }
         }
      }
      
      if(count == 0) break; // Todas as posicoes fechadas com sucesso!
      
      for(int i = 0; i < count; i++) {
         trade.PositionClose(tickets[i]);
      }
      
      if(retry < 4) Sleep(200); // Aguarda 200ms para processamento do servidor
   }
   
   g_PanicoAguardando=false;
   g_AguardandoBuy=false; g_ConfirmBuy=0;
   g_AguardandoSell=false; g_ConfirmSell=0;
   g_BuyEmTrailing  = false;  g_BuyLucroMaximo  = 0;
   g_SellEmTrailing = false;  g_SellLucroMaximo = 0;
   
   g_DD_Reached10        = false;
   g_DD_Reached20        = false;
   g_TrailingActive      = false;
   g_PeakProfit          = 0.0;
   g_EquityCycleBaseBalance = -1.0;
   g_EquityCycleCooldownEnd = 0;
   
   // [v3.40 Senior Sync] Reset global de base e DD no panico global
   GlobalVariableSet("OrionHedge_Global_EqBase", -1.0);
   GlobalVariableSet("OrionHedge_Global_DDReached10", 0.0);
   GlobalVariableSet("OrionHedge_Global_DDReached20", 0.0);
   GlobalVariableSet("OrionHedge_Global_TrailingActive", 0.0);
   GlobalVariableSet("OrionHedge_Global_PeakProfit", 0.0);
   
   // Resets para evitar origens stale e logs enganosos de drawdown apos panico global
   g_BuyZoneOrigin       = 0;
   g_SellZoneOrigin      = 0;
   g_BuyLoteInicial      = 0;
   g_SellLoteInicial     = 0;
   g_BuyNivelAtual       = 0;   // [BUG #4 FIX]
   g_SellNivelAtual      = 0;   // [BUG #4 FIX]
   g_DD_FaseAtual        = 0;
   g_SS_FaseAtual        = 0;
   
   // [FIX DADOS ANTIGOS] Zera contadores de lucro imediatamente (painel mostra 0 na hora)
   g_HistLucroGlobal   = 0;
   g_HistLucroSymbol   = 0;
   g_HistLucroHoje     = 0;
   g_HistSimbolosCount = 0;
   ArrayFree(g_HistSimbolos);
   
   // Definir data de reset global e local
   g_InicioHistorico = TimeCurrent();
   g_InicioHistoricoSymbol = g_InicioHistorico;
   GlobalVariableSet("OrionHedge_Global_ResetTime", (double)g_InicioHistorico);
   GlobalVariableSet("OrionHedge_ResetTime_" + _Symbol, (double)g_InicioHistoricoSymbol);
   GuardarResetTime("global", g_InicioHistorico);
   GuardarResetTime(_Symbol, g_InicioHistoricoSymbol);
   
   // Ativar pausa global no terminal
   GlobalVariableSet("OrionHedge_Global_BotPaused", 1.0);
   g_BotPaused = true;
   
   g_DealsCountCache = -1;
   AddLog("PANICO GLOBAL: Cestos ZERADOS e EAs PAUSADOS! Estatisticas resetadas ao ZERO.");
}

void FecharLocal() {
   // Loop de retentativas para garantir o fechamento sob slippage/requotes
   for(int retry = 0; retry < 5; retry++) {
      ulong tickets[];
      int total = PositionsTotal();
      ArrayResize(tickets, total);
      int count = 0;
      
      for(int i = 0; i < total; i++) {
         ulong t = PositionGetTicket(i);
         if(t > 0) {
            if(PositionSelectByTicket(t)) {
               int mag = (int)PositionGetInteger(POSITION_MAGIC);
               if((mag == g_MagicBuy || mag == g_MagicSell) && PositionGetString(POSITION_SYMBOL) == _Symbol) {
                  tickets[count] = t;
                  count++;
               }
            }
         }
      }
      
      if(count == 0) break; // Todas as posicoes locais fechadas com sucesso!
      
      for(int i = 0; i < count; i++) {
         trade.PositionClose(tickets[i]);
      }
      
      if(retry < 4) Sleep(200); // Aguarda 200ms para processamento do servidor
   }

   g_PanicoLocalAguardando=false;
   g_AguardandoBuy=false; g_ConfirmBuy=0;
   g_AguardandoSell=false; g_ConfirmSell=0;
   g_BuyEmTrailing  = false;  g_BuyLucroMaximo  = 0;
   g_SellEmTrailing = false;  g_SellLucroMaximo = 0;
   
   g_DD_Reached10        = false;
   g_DD_Reached20        = false;
   g_TrailingActive      = false;
   g_PeakProfit          = 0.0;
   g_EquityCycleBaseBalance = -1.0;
      g_EquityCycleCooldownEnd = 0;
   
   // Resets para evitar origens stale e logs enganosos de drawdown apos panico local
   g_BuyZoneOrigin       = 0;
   g_SellZoneOrigin      = 0;
   g_BuyLoteInicial      = 0;
   g_SellLoteInicial     = 0;
   g_BuyNivelAtual       = 0;   // [BUG #4 FIX]
   g_SellNivelAtual      = 0;   // [BUG #4 FIX]
   g_DD_FaseAtual        = 0;
   g_SS_FaseAtual        = 0;
   
   // Definir data de reset local
   g_InicioHistoricoSymbol = TimeCurrent();
   GlobalVariableSet("OrionHedge_ResetTime_" + _Symbol, (double)g_InicioHistoricoSymbol);
   GuardarResetTime(_Symbol, g_InicioHistoricoSymbol);
   
   // Pausar apenas este robô localmente
   g_BotPaused = true;
   
   g_DealsCountCache = -1;
   AddLog("PANICO LOCAL: Cestos deste par ZERADOS e pausados.");
}

//===================================================================
// AUXILIAR: OBTER DADOS DA ULTIMA RECOMPRA ATIVA
//===================================================================
bool ObterDadosUltimaRecompra(bool &isBuyRescue, int &level, ulong &ticket, double &loss, double &lucroOposto, int &magicOposto) {
   isBuyRescue = true;
   level = 0;
   ticket = 0;
   loss = 0.0;
   lucroOposto = 0.0;
   magicOposto = 0;

   int buyLvl = g_BuyNivelAtual;
   int sellLvl = g_SellNivelAtual;

   if(buyLvl <= 1 && sellLvl <= 1) return false;

   if(buyLvl > sellLvl) {
      isBuyRescue = true;
      level = buyLvl;
   } else if(sellLvl > buyLvl) {
      isBuyRescue = false;
      level = sellLvl;
   } else {
      double buyLoss = g_BuyLucro + g_BuySwap;
      double sellLoss = g_SellLucro + g_SellSwap;
      if(buyLoss < sellLoss) {
         isBuyRescue = true;
         level = buyLvl;
      } else {
         isBuyRescue = false;
         level = sellLvl;
      }
   }

   int magicPerdedor = isBuyRescue ? g_MagicBuy : g_MagicSell;
   magicOposto = isBuyRescue ? g_MagicSell : g_MagicBuy;
   string targetComm = (isBuyRescue ? "OH_B" : "OH_S") + IntegerToString(level);

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(t > 0 && PositionSelectByTicket(t)) {
         if(PositionGetInteger(POSITION_MAGIC) == magicPerdedor && PositionGetString(POSITION_SYMBOL) == _Symbol) {
            if(PositionGetString(POSITION_COMMENT) == targetComm) {
               ticket = t;
               loss = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
               break;
            }
         }
      }
   }

   if(ticket == 0) return false;

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(t > 0 && PositionSelectByTicket(t)) {
         if(PositionGetInteger(POSITION_MAGIC) == magicOposto && PositionGetString(POSITION_SYMBOL) == _Symbol) {
            lucroOposto += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         }
      }
   }

   return true;
}

//===================================================================
// AUXILIAR: OBTER DADOS DA RECOMPRA ATIVA POR DIREÇÃO
//===================================================================
bool ObterDadosRecompraDirecao(bool isBuyRescue, int &level, ulong &ticket, double &loss, double &lucroOposto, int &magicOposto) {
   level = isBuyRescue ? g_BuyNivelAtual : g_SellNivelAtual;
   ticket = 0;
   loss = 0.0;
   lucroOposto = 0.0;
   magicOposto = isBuyRescue ? g_MagicSell : g_MagicBuy;

   if(level <= 1) return false;

   int magicPerdedor = isBuyRescue ? g_MagicBuy : g_MagicSell;
   string targetComm = (isBuyRescue ? "OH_B" : "OH_S") + IntegerToString(level);

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(t > 0 && PositionSelectByTicket(t)) {
         if(PositionGetInteger(POSITION_MAGIC) == magicPerdedor && PositionGetString(POSITION_SYMBOL) == _Symbol) {
            if(PositionGetString(POSITION_COMMENT) == targetComm) {
               ticket = t;
               loss = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
               break;
            }
         }
      }
   }

   // Se não achar pelo comentário exato, tenta achar o ticket da última ordem aberta neste cesto
   if(ticket == 0) {
      datetime maxTime = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong t = PositionGetTicket(i);
         if(t > 0 && PositionSelectByTicket(t)) {
            if(PositionGetInteger(POSITION_MAGIC) == magicPerdedor && PositionGetString(POSITION_SYMBOL) == _Symbol) {
               datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
               if(posTime > maxTime) {
                  maxTime = posTime;
                  ticket = t;
                  loss = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
               }
            }
         }
      }
   }

   if(ticket == 0) return false;

   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong t = PositionGetTicket(i);
      if(t > 0 && PositionSelectByTicket(t)) {
         if(PositionGetInteger(POSITION_MAGIC) == magicOposto && PositionGetString(POSITION_SYMBOL) == _Symbol) {
            lucroOposto += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         }
      }
   }

   return true;
}

//===================================================================
// SOS: CALCULAR PRECO ALVO (GATILHO) NO CESTO OPOSTO
//===================================================================
bool CalcularAlvoSOS(bool isBuyRescue, double lucroOposto, double necessario, double &precoAlvo, double &precoAtual, double &distPts) {
   double oppVolume = isBuyRescue ? g_SellVolume : g_BuyVolume;
   double tickV = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickS = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   precoAtual = isBuyRescue ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(oppVolume <= 0 || tickV <= 0 || tickS <= 0) {
      precoAlvo = 0; distPts = 0;
      return false;
   }

   double falta = necessario - lucroOposto;
   if(falta <= 0) {
      precoAlvo = precoAtual;
      distPts = 0;
      return true;
   }

   double deltaPreco = (falta / (oppVolume * tickV)) * tickS;
   precoAlvo = isBuyRescue ? (precoAtual - deltaPreco) : (precoAtual + deltaPreco);
   distPts = MathAbs(precoAlvo - precoAtual) / _Point;
   return true;
}

//===================================================================
// SOS MANUAL: EXECUTAR FECHAMENTO IMEDIATO NO ZERO A ZERO
//===================================================================
void ExecutarFechamentoImediatoSOS(bool isBuyRescue, ulong ticket, int level, int magicOposto, double loss, double lucroOposto) {
   string dirPerdedora = isBuyRescue ? "COMPRA" : "VENDA";
   AddLog("[S.O.S] Executando fechamento imediato da Recompra " + dirPerdedora + " N" + IntegerToString(level) + " (" + DoubleToString(loss, 2) + " USC) abatendo no cesto oposto (" + DoubleToString(lucroOposto, 2) + " USC).");

   if(trade.PositionClose(ticket)) {
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong t = PositionGetTicket(i);
         if(t > 0 && PositionSelectByTicket(t)) {
            if(PositionGetInteger(POSITION_MAGIC) == magicOposto && PositionGetString(POSITION_SYMBOL) == _Symbol) {
               trade.PositionClose(t);
            }
         }
      }
      if(isBuyRescue) {
         g_BuyZoneOrigin = 0; g_BuyEmTrailing = false;
         SetBuySaidaZeroAtiva(false);
      } else {
         g_SellZoneOrigin = 0; g_SellEmTrailing = false;
         SetSellSaidaZeroAtiva(false);
      }
   } else {
      AddLog("[S.O.S IMEDIATO] Erro ao fechar posição de resgate " + dirPerdedora + " N" + IntegerToString(level) + ". Abortando fechamento do cesto oposto.");
   }
}

//===================================================================
// SOS: ABRIR/FECHAR O MINI PAINEL (toggle ao clicar no botao S.O.S da grade)
//===================================================================
void AbrirFecharPainelSOS(bool isBuyRescue) {
   if(isBuyRescue) {
      g_SOSPanelBuyAberto = !g_SOSPanelBuyAberto;
      g_SOSForceBuyAguardando = false;
   } else {
      g_SOSPanelSellAberto = !g_SOSPanelSellAberto;
      g_SOSForceSellAguardando = false;
   }
}

//===================================================================
// HELPER PARA LINHAS COM CONVERSÃO BRL NO MINI PAINEL S.O.S
//===================================================================
void PRowSOS(string id, int lx, int rx, int y, string lbl, double valUSC, color cv, bool isPronto = false) {
   double valBRL = isPronto ? 0.0 : UscToBrl(valUSC);
   string brlStr = "  [" + FormatBRL(valBRL) + "]";
   PLabel(id+"_l", lx, y, lbl + brlStr, CLR_TXT_LABEL, 8);
   
   if (isPronto) {
      PLabelR(id+"_v", rx, y, "PRONTO!", cv, 8);
   } else {
      string sign = (valUSC > 0.005) ? "+" : "";
      string valStr = sign + DoubleToString(valUSC, 2) + " USC";
      PLabelR(id+"_v", rx, y, valStr, cv, 8);
   }
}

//===================================================================
// HELPER PARA LINHAS SIMPLES (TEXTO) NO MINI PAINEL S.O.S
//===================================================================
void PRow8(string id, int lx, int rx, int y, string lbl, string val, color cv) {
   PLabel(id+"_l", lx, y, lbl, CLR_TXT_LABEL, 8);
   PLabelR(id+"_v", rx, y, val, cv, 8);
}

//===================================================================
// MINI PAINEL S.O.S — CALCULO DE RESGATE ZERO A ZERO (FLUTUANTE)
//===================================================================
void DesenharPainelSOS(bool isBuyRescue, int x, int y, int &outHeight) {
   string pfx = isBuyRescue ? "sb_" : "ss_";
   bool aberto = isBuyRescue ? g_SOSPanelBuyAberto : g_SOSPanelSellAberto;

   if(!aberto) {
      LimparPainelSOS(pfx);
      outHeight = 0;
      return;
   }

   int level; ulong ticket; double loss; double lucroOposto; int magicOposto;
   if(!ObterDadosRecompraDirecao(isBuyRescue, level, ticket, loss, lucroOposto, magicOposto)) {
      if(isBuyRescue) g_SOSPanelBuyAberto = false; else g_SOSPanelSellAberto = false;
      LimparPainelSOS(pfx);
      outHeight = 0;
      return;
   }

   string dirPerdedora = isBuyRescue ? "COMPRA" : "VENDA";
   string dirVencedora = isBuyRescue ? "VENDA" : "COMPRA";
   bool isScheduled = isBuyRescue ? g_BuySaidaZeroAtiva : g_SellSaidaZeroAtiva;
   color dirClr = isBuyRescue ? CLR_TEAL : CLR_RED;

   double absLoss = MathAbs(loss);
   double buffer = MathMax(1.00, absLoss * 0.10);
   double necessario = absLoss + buffer;
   double falta = necessario - lucroOposto;
   bool pronto = (falta <= 0);

   double precoAlvo=0, precoAtual=0, distPts=0;
   bool calcOk = CalcularAlvoSOS(isBuyRescue, lucroOposto, necessario, precoAlvo, precoAtual, distPts);

   double volRecompra = 0;
   if(PositionSelectByTicket(ticket)) volRecompra = PositionGetDouble(POSITION_VOLUME);

   int pw2=260, pad2=10;
   int lx2=x+pad2+4, rx2=x+pw2-pad2;
   int cur=y;
   int prevHeight = isBuyRescue ? g_SOSPanelBuyHeight : g_SOSPanelSellHeight;

   PRect(pfx+"border", x-1, cur-1, pw2+2, prevHeight+2, CLR_LINE_HARD, CLR_LINE_HARD, 198);
   PRect(pfx+"bg",      x,   cur,   pw2,   prevHeight,   CLR_BG_BASE, -1, 199);

   //=================================================== HEADER
   PRect(pfx+"hdr_bg",  x, cur, pw2, 32, CLR_BG_HEADER, -1, 200);
   PRect(pfx+"hdr_top", x, cur, pw2, 2, isScheduled?CLR_AMBER:CLR_RED, -1, 201); cur+=2;
   PLabel(pfx+"hdr_title", x+pad2, cur+6, "S.O.S — "+dirPerdedora+" N"+IntegerToString(level), CLR_TXT_PRIMARY, 9, true);
   string statusTxt = isScheduled ? "AGENDADO - MONITORANDO" : (pronto ? "PRONTO PARA FECHAR" : "AGUARDANDO LUCRO");
   color statusClr = isScheduled ? CLR_AMBER : (pronto ? CLR_TEAL : CLR_RED);
   PLabel(pfx+"hdr_status", x+pad2, cur+19, statusTxt, statusClr, 7, true);
   PButton(pfx+"btn_x", x+pw2-22, cur+5, 18, 18, "X", CLR_BG_CARD, CLR_TXT_LABEL);
   cur+=32+6;

   //=================================================== CALCULO DO RESGATE
   PSect(pfx+"sec_calc", x, cur, pw2, "CALCULO DO RESGATE", dirClr); cur+=16;
   ObjectDelete(0, PANEL_PREFIX+pfx+"r_buffer_l");
   ObjectDelete(0, PANEL_PREFIX+"R_"+pfx+"r_buffer_v");
   PRowSOS(pfx+"r_perda", lx2, rx2, cur, "Prejuízo Real:", -absLoss, C'255,82,82'); cur+=14;
   PRowSOS(pfx+"r_oposto", lx2, rx2, cur, "Lucro das Grades:", lucroOposto, lucroOposto>=0?C'0,200,83':C'255,82,82'); cur+=14;
   PRowSOS(pfx+"r_necessario", lx2, rx2, cur, "Meta p/ Fechar:", necessario, CLR_TXT_PRIMARY); cur+=14;
   PRowSOS(pfx+"r_falta", lx2, rx2, cur, "Falta p/ Resgate:", pronto?0.0:falta, pronto?CLR_TEAL:CLR_AMBER, pronto); cur+=18;

   //=================================================== ALVO DE PRECO
   PSect(pfx+"sec_alvo", x, cur, pw2, "ALVO DE PRECO (GATILHO)", CLR_BLUE); cur+=16;
   ObjectDelete(0, PANEL_PREFIX+pfx+"r_atual_l");
   ObjectDelete(0, PANEL_PREFIX+"R_"+pfx+"r_atual_v");
   ObjectDelete(0, PANEL_PREFIX+pfx+"r_alvo_l");
   ObjectDelete(0, PANEL_PREFIX+"R_"+pfx+"r_alvo_v");
   ObjectDelete(0, PANEL_PREFIX+pfx+"r_dist_l");
   ObjectDelete(0, PANEL_PREFIX+"R_"+pfx+"r_dist_v");
   ObjectDelete(0, PANEL_PREFIX+pfx+"bar_prox_bg");
   ObjectDelete(0, PANEL_PREFIX+pfx+"bar_prox_fill");
   ObjectDelete(0, PANEL_PREFIX+pfx+"r_semcalc");
   if(calcOk) {
      PRow8(pfx+"r_atual", lx2, rx2, cur, "Preco Atual:", DoubleToString(precoAtual,_Digits), CLR_TXT_PRIMARY); cur+=14;
      string alvoStr = pronto ? "ATINGIDO!" : DoubleToString(precoAlvo,_Digits);
      PRow8(pfx+"r_alvo", lx2, rx2, cur, "Alvo (Gatilho):", alvoStr, pronto?CLR_TEAL:CLR_BLUE); cur+=14;
      string distStr = pronto ? "0 pts" : (DoubleToString(distPts,0)+" pts");
      PRow8(pfx+"r_dist", lx2, rx2, cur, "Distancia:", distStr, pronto?CLR_TEAL:CLR_TXT_LABEL); cur+=12;
      double pctProx = pronto ? 1.0 : MathMax(0.0, MathMin(1.0, 1.0 - (falta/necessario)));
      PBar(pfx+"bar_prox", lx2, cur, pw2-(pad2*2)-8, 8, pctProx, CLR_LINE_SOFT, pronto?CLR_TEAL:CLR_AMBER); cur+=16;
   } else {
      PLabel(pfx+"r_semcalc", lx2, cur, "Calculo indisponivel (volume/tick invalido)", CLR_TXT_DIM, 8); cur+=16;
   }
   PRow8(pfx+"r_vol", lx2, rx2, cur, "Volume Recompra:", DoubleToString(volRecompra,3)+" L", CLR_TXT_LABEL); cur+=18;

   //=================================================== BOTOES DE ACAO
   int bw2 = pw2-(pad2*2)+4;
   ObjectDelete(0, PANEL_PREFIX+pfx+"btn_cancelar");
   ObjectDelete(0, PANEL_PREFIX+pfx+"btn_fechar_agora");
   ObjectDelete(0, PANEL_PREFIX+pfx+"btn_agendar");
   ObjectDelete(0, PANEL_PREFIX+pfx+"btn_forcar_zeragem");

   if(isScheduled) {
      PButton(pfx+"btn_cancelar", x+pad2-2, cur, bw2, 22, "CANCELAR AGENDAMENTO", CLR_RED_DIM, CLR_RED); cur+=26;
   } else if(pronto) {
      PButton(pfx+"btn_fechar_agora", x+pad2-2, cur, bw2, 24, "FECHAR AGORA (ZERO A ZERO)", CLR_TEAL_DIM, CLR_TEAL); cur+=28;
      PButton(pfx+"btn_agendar", x+pad2-2, cur, bw2, 20, "AGENDAR MESMO ASSIM", CLR_BG_CARD, CLR_AMBER); cur+=24;
   } else {
      PButton(pfx+"btn_agendar", x+pad2-2, cur, bw2, 24, "AGENDAR RESGATE AUTOMATICO", CLR_BG_CARD, CLR_AMBER); cur+=28;
   }

   if(!pronto) {
      bool forceAguardando = isBuyRescue ? g_SOSForceBuyAguardando : g_SOSForceSellAguardando;
      datetime forceTime = isBuyRescue ? g_SOSForceBuyTimestamp : g_SOSForceSellTimestamp;
      
      if(forceAguardando && TimeCurrent() - forceTime > 3) {
         if(isBuyRescue) g_SOSForceBuyAguardando = false; else g_SOSForceSellAguardando = false;
         forceAguardando = false;
      }
      
      if(forceAguardando) {
         PButton(pfx+"btn_forcar_zeragem", x+pad2-2, cur, bw2, 24, "⚠️ CONFIRMAR ZERAGEM EM 3s?", CLR_RED, CLR_TXT_PRIMARY); cur+=28;
      } else {
         double totalLossUSC = -absLoss + lucroOposto;
         double totalLossBRL = UscToBrl(totalLossUSC);
         string btnText = "FORÇAR ZERAGEM  [" + FormatBRL(totalLossBRL) + "]";
         PButton(pfx+"btn_forcar_zeragem", x+pad2-2, cur, bw2, 22, btnText, CLR_RED_DIM, CLR_RED); cur+=26;
      }
   }
   cur+=4;

   int finalHeight = cur-y;
   if(isBuyRescue) g_SOSPanelBuyHeight = finalHeight; else g_SOSPanelSellHeight = finalHeight;
   ObjectSetInteger(0, PANEL_PREFIX+pfx+"border", OBJPROP_YSIZE, finalHeight+2);
   ObjectSetInteger(0, PANEL_PREFIX+pfx+"bg",     OBJPROP_YSIZE, finalHeight);
   outHeight = finalHeight;
}

//===================================================================
// CLICK EVENTS
//===================================================================
void OnChartEvent(const int id,const long &lp,const double &dp,const string &sp) {
   if(id==CHARTEVENT_OBJECT_CLICK) {
      // Botão S.O.S na grade — abre/fecha o mini painel de cálculo
      if(sp == PANEL_PREFIX + "btn_buy_sos") {
         AbrirFecharPainelSOS(true);
         DesenharPainel(); ChartRedraw(0);
         return;
      }
      if(sp == PANEL_PREFIX + "btn_sel_sos") {
         AbrirFecharPainelSOS(false);
         DesenharPainel(); ChartRedraw(0);
         return;
      }

      // Mini painel S.O.S — fechar (X)
      if(sp == PANEL_PREFIX + "sb_btn_x") { g_SOSPanelBuyAberto=false; DesenharPainel(); ChartRedraw(0); return; }
      if(sp == PANEL_PREFIX + "ss_btn_x") { g_SOSPanelSellAberto=false; DesenharPainel(); ChartRedraw(0); return; }

      // Mini painel S.O.S — cancelar agendamento
      if(sp == PANEL_PREFIX + "sb_btn_cancelar") {
         SetBuySaidaZeroAtiva(false);
         AddLog("[S.O.S] Agendamento cancelado manualmente para COMPRA");
         DesenharPainel(); ChartRedraw(0);
         return;
      }
      if(sp == PANEL_PREFIX + "ss_btn_cancelar") {
         SetSellSaidaZeroAtiva(false);
         AddLog("[S.O.S] Agendamento cancelado manualmente para VENDA");
         DesenharPainel(); ChartRedraw(0);
         return;
      }

      // Mini painel S.O.S — agendar resgate automático
      if(sp == PANEL_PREFIX + "sb_btn_agendar") {
         SetBuySaidaZeroAtiva(true);
         AddLog("[S.O.S] Agendamento ATIVADO para COMPRA");
         g_SOSPanelBuyAberto=false;
         DesenharPainel(); ChartRedraw(0);
         return;
      }
      if(sp == PANEL_PREFIX + "ss_btn_agendar") {
         SetSellSaidaZeroAtiva(true);
         AddLog("[S.O.S] Agendamento ATIVADO para VENDA");
         g_SOSPanelSellAberto=false;
         DesenharPainel(); ChartRedraw(0);
         return;
      }

      // Mini painel S.O.S — fechar agora (zero a zero imediato)
      if(sp == PANEL_PREFIX + "sb_btn_fechar_agora") {
         int level; ulong ticket; double loss; double lucroOposto; int magicOposto;
         if(ObterDadosRecompraDirecao(true, level, ticket, loss, lucroOposto, magicOposto))
            ExecutarFechamentoImediatoSOS(true, ticket, level, magicOposto, loss, lucroOposto);
         g_SOSPanelBuyAberto=false;
         DesenharPainel(); ChartRedraw(0);
         return;
      }
      if(sp == PANEL_PREFIX + "ss_btn_fechar_agora") {
         int level; ulong ticket; double loss; double lucroOposto; int magicOposto;
         if(ObterDadosRecompraDirecao(false, level, ticket, loss, lucroOposto, magicOposto))
            ExecutarFechamentoImediatoSOS(false, ticket, level, magicOposto, loss, lucroOposto);
         g_SOSPanelSellAberto=false;
         DesenharPainel(); ChartRedraw(0);
         return;
      }
      // Mini painel S.O.S — forçar zeragem
      if(sp == PANEL_PREFIX + "sb_btn_forcar_zeragem") {
         if(!g_SOSForceBuyAguardando) {
            g_SOSForceBuyAguardando = true;
            g_SOSForceBuyTimestamp = TimeCurrent();
            AddLog("[S.O.S] Clique novamente em 3s para confirmar a ZERAGEM com prejuízo!");
         } else if(TimeCurrent() - g_SOSForceBuyTimestamp <= 3) {
            g_SOSForceBuyAguardando = false;
            int level; ulong ticket; double loss; double lucroOposto; int magicOposto;
            if(ObterDadosRecompraDirecao(true, level, ticket, loss, lucroOposto, magicOposto))
               ExecutarFechamentoImediatoSOS(true, ticket, level, magicOposto, loss, lucroOposto);
            g_SOSPanelBuyAberto = false;
         } else {
            g_SOSForceBuyAguardando = false;
            AddLog("[S.O.S] Confirmação expirou. Zeragem cancelada.");
         }
         DesenharPainel(); ChartRedraw(0);
         return;
      }
      if(sp == PANEL_PREFIX + "ss_btn_forcar_zeragem") {
         if(!g_SOSForceSellAguardando) {
            g_SOSForceSellAguardando = true;
            g_SOSForceSellTimestamp = TimeCurrent();
            AddLog("[S.O.S] Clique novamente em 3s para confirmar a ZERAGEM com prejuízo!");
         } else if(TimeCurrent() - g_SOSForceSellTimestamp <= 3) {
            g_SOSForceSellAguardando = false;
            int level; ulong ticket; double loss; double lucroOposto; int magicOposto;
            if(ObterDadosRecompraDirecao(false, level, ticket, loss, lucroOposto, magicOposto))
               ExecutarFechamentoImediatoSOS(false, ticket, level, magicOposto, loss, lucroOposto);
            g_SOSPanelSellAberto = false;
         } else {
            g_SOSForceSellAguardando = false;
            AddLog("[S.O.S] Confirmação expirou. Zeragem cancelada.");
         }
         DesenharPainel(); ChartRedraw(0);
         return;
      }
      // Bloquear seletor de filtros se o Trailing de Patrimonio estiver ativo
      bool trailingAtivo = false;
      if(trailingAtivo && StringFind(sp, PANEL_PREFIX+"btn_flt_") == 0) {
         AddLog("[TRAILING] Filtro de data bloqueado enquanto o Trailing de Patrimonio estiver ativo!");
         ObjectSetInteger(0, sp, OBJPROP_STATE, false);
         DesenharPainel(); ChartRedraw(0);
         return;
      }

      if(StringFind(sp, PANEL_PREFIX+"btn_rep_") == 0) {
         if(sp==PANEL_PREFIX+"btn_rep_sdm") {
            g_RepDataIni = NormalizarDia(g_RepDataIni - 86400);
         }
         else if(sp==PANEL_PREFIX+"btn_rep_sdp") {
            if(g_RepDataIni+86400 < g_RepDataFim) g_RepDataIni = NormalizarDia(g_RepDataIni + 86400);
         }
         else if(sp==PANEL_PREFIX+"btn_rep_smm") {
            MqlDateTime md; TimeToStruct(g_RepDataIni,md);
            if(md.mon > 1) md.mon--; else { md.mon=12; md.year--; }
            g_RepDataIni=NormalizarDia(StructToTime(md));
         }
         else if(sp==PANEL_PREFIX+"btn_rep_smp") {
            MqlDateTime md; TimeToStruct(g_RepDataIni,md);
            if(md.mon < 12) md.mon++; else { md.mon=1; md.year++; }
            datetime newDt=NormalizarDia(StructToTime(md));
            if(newDt < g_RepDataFim) g_RepDataIni=newDt;
         }
         else if(sp==PANEL_PREFIX+"btn_rep_sym") {
            MqlDateTime md; TimeToStruct(g_RepDataIni,md);
            md.year--;
            g_RepDataIni=NormalizarDia(StructToTime(md));
         }
         else if(sp==PANEL_PREFIX+"btn_rep_syp") {
            MqlDateTime md; TimeToStruct(g_RepDataIni,md);
            md.year++;
            datetime newDt=NormalizarDia(StructToTime(md));
            if(newDt < g_RepDataFim) g_RepDataIni=newDt;
         }
         else if(sp==PANEL_PREFIX+"btn_rep_edm") {
            if(g_RepDataFim-86400 > g_RepDataIni) g_RepDataFim = NormalizarDia(g_RepDataFim - 86400);
         }
         else if(sp==PANEL_PREFIX+"btn_rep_edp") {
            if(g_RepDataFim+86400 <= TimeCurrent()) g_RepDataFim = NormalizarDia(g_RepDataFim + 86400);
         }
         else if(sp==PANEL_PREFIX+"btn_rep_emm") {
            MqlDateTime md; TimeToStruct(g_RepDataFim,md);
            if(md.mon > 1) md.mon--; else { md.mon=12; md.year--; }
            datetime newDt=NormalizarDia(StructToTime(md));
            if(newDt > g_RepDataIni) g_RepDataFim=newDt;
         }
         else if(sp==PANEL_PREFIX+"btn_rep_emp") {
            MqlDateTime md; TimeToStruct(g_RepDataFim,md);
            if(md.mon < 12) md.mon++; else { md.mon=1; md.year++; }
            datetime newDt=NormalizarDia(StructToTime(md));
            if(newDt <= TimeCurrent()) g_RepDataFim=newDt;
         }
         else if(sp==PANEL_PREFIX+"btn_rep_eym") {
            MqlDateTime md; TimeToStruct(g_RepDataFim,md);
            md.year--;
            datetime newDt=NormalizarDia(StructToTime(md));
            if(newDt > g_RepDataIni) g_RepDataFim=newDt;
         }
         else if(sp==PANEL_PREFIX+"btn_rep_eyp") {
            MqlDateTime md; TimeToStruct(g_RepDataFim,md);
            md.year++;
            datetime newDt=NormalizarDia(StructToTime(md));
            if(newDt <= TimeCurrent()) g_RepDataFim=newDt;
         }
         else if(sp==PANEL_PREFIX+"btn_rep_gen") {
            GerarRelatorioHTML();
         }
         else if(sp==PANEL_PREFIX+"btn_rep_push") {
            EnviarResumoPush();
         }
         DesenharPainel(); ChartRedraw(0);
         return;
      }

      if(sp==PANEL_PREFIX+"btn_pause") {
         g_BotPaused=!g_BotPaused;
         if(!g_BotPaused) {
            // Limpa a pausa global no terminal
            GlobalVariableSet("OrionHedge_Global_BotPaused", 0.0);
            
            // Se retomar e não houver posições abertas na moeda, reseta estatísticas locais
            if(g_BuyTotal == 0 && g_SellTotal == 0) {
               g_InicioHistoricoSymbol = TimeCurrent();
               GlobalVariableSet("OrionHedge_ResetTime_" + _Symbol, (double)g_InicioHistoricoSymbol);
               GuardarResetTime(_Symbol, g_InicioHistoricoSymbol);
               g_DealsCountCache = -1; // Força recalcular
               AddLog("Retomando sem posições: Estatísticas Locais resetadas.");
            }
            
            // Se retomar e não houver posições abertas no EA todo, reseta estatísticas globais
            if(!TemPosicoesGlobais()) {
               g_InicioHistorico = TimeCurrent();
               GlobalVariableSet("OrionHedge_Global_ResetTime", (double)g_InicioHistorico);
               GlobalVariableSet("OrionHedge_ResetTime_" + _Symbol, (double)g_InicioHistoricoSymbol);
               GuardarResetTime("global", g_InicioHistorico);
               GuardarResetTime(_Symbol, g_InicioHistoricoSymbol);
               g_DealsCountCache = -1; // Força recalcular
               AddLog("Retomando sem posições: Estatísticas Globais resetadas.");
            }

            g_DD_Reached10        = false;
            g_DD_Reached20        = false;
            g_TrailingActive      = false;
            g_PeakProfit          = 0.0;
         }
         AddLog(g_BotPaused?"Robo PAUSADO.":"Robo RETOMADO.");
      }
      else if(sp==PANEL_PREFIX+"btn_cfg") {
         g_ShowSettings=!g_ShowSettings;
         g_MinimizedCleaned=false;
         LimparConteudoPainel();
      }
      else if(sp==PANEL_PREFIX+"btn_log") {
         g_ShowLog=!g_ShowLog;
         PClear("log_hidden");
         LimparConteudoPainel();
      }
      else if(sp==PANEL_PREFIX+"btn_flt_0") { g_FiltroHistorico=0; g_DealsCountCache=-1; AtualizarHistoricoGlobal(); }
      else if(sp==PANEL_PREFIX+"btn_flt_1") { g_FiltroHistorico=1; g_DealsCountCache=-1; AtualizarHistoricoGlobal(); }
      else if(sp==PANEL_PREFIX+"btn_flt_2") { g_FiltroHistorico=2; g_DealsCountCache=-1; AtualizarHistoricoGlobal(); }
      else if(sp==PANEL_PREFIX+"btn_flt_3") { g_FiltroHistorico=3; g_DealsCountCache=-1; AtualizarHistoricoGlobal(); }
      else if(sp==PANEL_PREFIX+"btn_flt_4") {
         g_FiltroHistorico=4;
         MqlDateTime md; TimeToStruct(TimeCurrent(),md);
         md.hour=0; md.min=0; md.sec=0;
         g_FiltroDataIni = StructToTime(md);
         g_DealsCountCache=-1; AtualizarHistoricoGlobal();
      }
      // Navegacao DIA no seletor CUST
      else if(sp==PANEL_PREFIX+"btn_flt_dm") {
         g_FiltroDataIni -= 86400; // recua 1 dia
         g_DealsCountCache=-1; AtualizarHistoricoGlobal();
      }
      else if(sp==PANEL_PREFIX+"btn_flt_dp") {
         if(g_FiltroDataIni+86400 < TimeCurrent()) g_FiltroDataIni += 86400; // avanca 1 dia
         g_DealsCountCache=-1; AtualizarHistoricoGlobal();
      }
      // Navegacao MES no seletor CUST
      else if(sp==PANEL_PREFIX+"btn_flt_mm") {
         MqlDateTime md; TimeToStruct(g_FiltroDataIni,md);
         if(md.mon > 1) md.mon--; else { md.mon=12; md.year--; }
         g_FiltroDataIni=StructToTime(md); g_DealsCountCache=-1; AtualizarHistoricoGlobal();
      }
      else if(sp==PANEL_PREFIX+"btn_flt_mp") {
         MqlDateTime md; TimeToStruct(g_FiltroDataIni,md);
         if(md.mon < 12) md.mon++; else { md.mon=1; md.year++; }
         datetime newDt=StructToTime(md);
         if(newDt < TimeCurrent()) { g_FiltroDataIni=newDt; g_DealsCountCache=-1; AtualizarHistoricoGlobal(); }
      }
      // Navegacao ANO no seletor CUST
      else if(sp==PANEL_PREFIX+"btn_flt_ym") {
         MqlDateTime md; TimeToStruct(g_FiltroDataIni,md);
         md.year--;
         g_FiltroDataIni=StructToTime(md); g_DealsCountCache=-1; AtualizarHistoricoGlobal();
      }
      else if(sp==PANEL_PREFIX+"btn_flt_yp") {
         MqlDateTime md; TimeToStruct(g_FiltroDataIni,md);
         md.year++;
         datetime newDt=StructToTime(md);
         if(newDt < TimeCurrent()) { g_FiltroDataIni=newDt; g_DealsCountCache=-1; AtualizarHistoricoGlobal(); }
      }
      else if(sp==PANEL_PREFIX+"btn_min") { g_Minimized=!g_Minimized; g_MinimizedCleaned=false; }
      else if(sp==PANEL_PREFIX+"btn_l0") { g_LinhasModo=0; DesenharLinhas(); }
      else if(sp==PANEL_PREFIX+"btn_l1") { g_LinhasModo=1; DesenharLinhas(); }
      else if(sp==PANEL_PREFIX+"btn_analise") {
         g_ModoAnalise = !g_ModoAnalise;
         if(g_ModoAnalise) {
             IniciarHandlesAnalise();
             // Adiciona as curvas reais dos indicadores ao grafico (Canais e EMAs)
             ChartIndicatorAdd(0, 0, g_AnaHandleEMA50);
             ChartIndicatorAdd(0, 0, handleEMA); // EMA 200
             // Removido: ChartIndicatorAdd(0, 0, g_AnaHandleBB); para limpar a poluicao visual
             g_PreAnaliseLinhasModo = g_LinhasModo;  // [BUG-M2 FIX] Salva preferencia do usuario
             g_LinhasModo = 1; // oculta linhas trading durante analise
             LimparLinhasAnalise(); // limpa resíduos de TF anterior
             DesenharLinhasAnalise();
         } else {
             LimparIndicadoresAnalise();
             LimparLinhasAnalise();
             g_LinhasModo = g_PreAnaliseLinhasModo; // [BUG-M2 FIX] Restaura preferencia do usuario
             g_AnaliseLegendHeight = 0;
             AddLog("[ANALISE] Modo Analise DESATIVADO.");
         }
         LimparConteudoPainel(); // limpa sobreposicao imediatamente
      }
      else if(sp==PANEL_PREFIX+"btn_panic_loc") {
         if(!g_PanicoLocalAguardando){g_PanicoLocalAguardando=true; g_PanicoLocalTimestamp=TimeCurrent(); AddLog("! Clique novamente em 3s para ZERAR LOCAL.");}
         else if(TimeCurrent()-g_PanicoLocalTimestamp<=3) FecharLocal();
         else {g_PanicoLocalAguardando=false; AddLog("Panico local cancelado.");}
      }
      else if(sp==PANEL_PREFIX+"btn_panic_glb") {
         if(!g_PanicoAguardando){g_PanicoAguardando=true; g_PanicoTimestamp=TimeCurrent(); AddLog("! Clique novamente em 3s para PANICO GLOBAL.");}
         else if(TimeCurrent()-g_PanicoTimestamp<=3) FecharTudo();
         else {g_PanicoAguardando=false; AddLog("Panico global cancelado.");}
      }

      if(StringFind(sp, PANEL_PREFIX+"btn_flt_") == 0) {
         PublishGlobalFilterParams();
      }
      ObjectSetInteger(0,sp,OBJPROP_STATE,false);
      DesenharPainel(); ChartRedraw(0);
   }
}

void EnviarResumoPush() {
   // Coleta de dados
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double open_profit = 0, open_swap = 0;
   
   // Estrutura para contar recompras por moeda
   struct SSymbolCount {
      string symbol;
      int buyCount;
      int sellCount;
   };
   SSymbolCount syms[];
   int symsCount = 0;
   
   for(int i = 0; i < PositionsTotal(); i++) {
      ulong tck = PositionGetTicket(i);
      if(tck > 0) {
         long mag = PositionGetInteger(POSITION_MAGIC);
         if(mag >= InpMagicNumberBase && mag <= InpMagicNumberBase + 999999) {
            open_swap   += PositionGetDouble(POSITION_SWAP);
            open_profit += PositionGetDouble(POSITION_PROFIT);
            
            string sym = PositionGetString(POSITION_SYMBOL);
            long type = PositionGetInteger(POSITION_TYPE);
            
            bool found = false;
            for(int j = 0; j < symsCount; j++) {
               if(syms[j].symbol == sym) {
                  if(type == POSITION_TYPE_BUY) syms[j].buyCount++;
                  if(type == POSITION_TYPE_SELL) syms[j].sellCount++;
                  found = true;
                  break;
               }
            }
            if(!found) {
               ArrayResize(syms, symsCount + 1);
               syms[symsCount].symbol = sym;
               syms[symsCount].buyCount = (type == POSITION_TYPE_BUY) ? 1 : 0;
               syms[symsCount].sellCount = (type == POSITION_TYPE_SELL) ? 1 : 0;
               symsCount++;
            }
         }
      }
   }
   
   double pnl_global = open_profit + open_swap;
   double pct_pnl = (balance > 0) ? (pnl_global / balance * 100.0) : 0.0;
   
   // Lucro de hoje sincronizado com o painel gráfico
   double lucroHoje = g_HistLucroHoje;
   double pctHoje = (balance > 0) ? (lucroHoje / balance * 100.0) : 0.0;
   
   // Lucro Global Acumulado sincronizado com o painel gráfico
   double lucroGlobalTotal = g_HistLucroGlobal;
   double pctGlobalTotal = (balance > 0) ? (lucroGlobalTotal / balance * 100.0) : 0.0;
   
   // Variação percentual do Patrimônio Líquido (Equity) sobre o Saldo
   double pct_patrimonio = (balance > 0) ? ((equity - balance) / balance * 100.0) : 0.0;
   double drawdown = (balance > 0) ? (MathAbs(pnl_global) / balance * 100.0) : 0.0;
   
   string statusDD = "Verde";
   if(g_DD_FaseAtual == 1) statusDD = "Amarelo";
   if(g_DD_FaseAtual == 2) statusDD = "Vermelho";
   
   // Formatar mensagem direta (MT5 push tem limite de 256 caracteres!)
   string msg = "ORION HEDGE (" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + ")\n\n";
   msg += "Saldo: " + DoubleToString(balance, 1) + " (R$" + DoubleToString(UscToBrl(balance), 1) + ")\n";
   msg += "L. Global: " + ((lucroGlobalTotal>=0)?"+":"") + DoubleToString(lucroGlobalTotal, 1) + " (R$" + DoubleToString(UscToBrl(lucroGlobalTotal), 1) + " / " + ((pctGlobalTotal>=0)?"+":"") + DoubleToString(pctGlobalTotal, 2) + "%)\n";
   msg += "P. Liquido: " + DoubleToString(equity, 1) + " (R$" + DoubleToString(UscToBrl(equity), 1) + " / " + ((pct_patrimonio>=0)?"+":"") + DoubleToString(pct_patrimonio, 2) + "%)\n";
   msg += "P. Flutuante: " + ((pnl_global>=0)?"+":"") + DoubleToString(pnl_global, 1) + " (R$" + DoubleToString(UscToBrl(pnl_global), 1) + " / " + ((pct_pnl>=0)?"+":"") + DoubleToString(pct_pnl, 2) + "%)\n";
   msg += "Draw: " + DoubleToString(drawdown, 1) + "% (" + statusDD + ")\n";
   msg += "Hoje: " + ((lucroHoje>=0)?"+":"") + DoubleToString(lucroHoje, 1) + " (R$" + DoubleToString(UscToBrl(lucroHoje), 1) + " / " + ((pctHoje>=0)?"+":"") + DoubleToString(pctHoje, 2) + "%)\n\n";
   
   msg += "Baskets:\n";
   if(symsCount == 0) {
      msg += "Nenhum ativo aberto.";
   } else {
      for(int i = 0; i < symsCount; i++) {
         string shortSym = syms[i].symbol;
         if(StringSubstr(shortSym, StringLen(shortSym)-1) == "c") {
            shortSym = StringSubstr(shortSym, 0, StringLen(shortSym)-1);
         }
         msg += shortSym + ":" + IntegerToString(syms[i].buyCount) + "C/" + IntegerToString(syms[i].sellCount) + "V\n";
      }
   }
   
   ResetLastError();
   bool res = SendNotification(msg);
   
   if(res) {
      AddLog("Notificacao Push enviada para o seu celular!");
   } else {
      AddLog("Erro ao enviar Push. Codigo: " + IntegerToString(_LastError));
      Print("MQL5 SendNotification Error: ", _LastError);
   }
}

//+------------------------------------------------------------------+
//  FIM — Orion_Hedge.mq5
//  MODO HEDGE: 2 Cestos Simultaneos — USE SO EM DEMO/TESTADOR
//+------------------------------------------------------------------+

