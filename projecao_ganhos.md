# Orion Hedge — Projeção de Ganhos, Retorno e Risco

Este documento contém a tabela comparativa de projeção de ganhos, a análise de risco e as recomendações de segurança atualizadas para o robô **Orion Hedge**.

* **Saldo Base de Cálculo:** `72.614,87 USC` (~$726,15 USD)
* **Cotação Base BRL/USD:** `R$ 5,20`
* **Capital Inicial Estimado:** `56.257,00 USC` (R$ 2.925,36)
* **Período Analisado:** 14/04/2026 a 01/06/2026 (48 dias)

---

## 📈 1. Desempenho Real (Histórico com Freio 0.94)

Com base no histórico fechado de **16.357,87 USC** de lucro e no flutuante atual de **-4.390,55 USC** (Drawdown de **6,05%**), temos a projeção mensal anterior (calculada para 30 dias):

| Métrica (com Freio 0.94) | Desempenho Real (48 dias) | Média Diária | Projeção Mensal (30 dias) | Projeção Mensal (BRL) |
| :--- | :---: | :---: | :---: | :---: |
| **Retorno Bruto (Lucro Fechado)** | +29,07% (+16.357,87 USC) | 0,6056% | **18,17% / mês** (10.223,67 USC) | **R$ 531,63** |
| **Retorno Líquido (Patrimônio)** | +21,27% (+11.967,32 USC) | 0,4431% | **13,29% / mês** (7.479,58 USC) | **R$ 388,94** |

---

## 🔄 2. Projeção Após a Alteração: Freio 0.94 vs Freio 0.92

Ao alterar o freio (`InpLotDeceleration`) de `0.94` para `0.92`, a semente base de `0.015` calculará lotes menores devido à maior desaceleração no juros compostos. Isso reduz a exposição financeira e a meta de lucros:

### 📊 Comparação de Parâmetros Operacionais (Saldo: 72.614 USC)

| Parâmetro / Métrica | Configuração Atual (Freio 0.94) | Nova Configuração (Freio 0.92) | Impacto / Diferença |
| :--- | :---: | :---: | :--- |
| **Lote Base Inicial** | **0,84 Lotes** | **0,77 Lotes** | 📉 **-8,33%** de volume inicial |
| **Alvo TakeProfit (Cesto)** | 126,00 USC | 115,50 USC | 📉 Alvos mais curtos (gira mais rápido) |
| **Freio Drawdown (SoftStop)**| 33.600,00 USC | 30.800,00 USC | 🛡️ **-2.800,00 USC** em risco absoluto |
| **Volume Acumulado (N6)** | 17,46 Lotes | 16,01 Lotes | 📉 **-1,45 Lotes** de exposição no teto |
| **Custo por Pip no N6** | 174,60 USC / pip | 160,10 USC / pip | 🛡️ Flutuação mais suave no sufoco |
| **Margem Sobrevivência (N6)**| **192 pips** | **192 pips** | Margem em pips igual (stop reduziu proporcional) |

### 🎯 Nova Meta de Lucro Mensal (Projeção com Freio 0.92)

Como a exposição diminuiu em **8,33%**, a meta de lucro mensal é ajustada proporcionalmente:

*   **Meta de Lucro Bruto (Ciclos Fechados):** **`16,66%` ao mês** (`9.371,70 USC` / **R$ 487,33 BRL**).
*   **Meta de Lucro Líquido (Patrimônio Realista):** **`12,18%` ao mês** (`6.856,28 USC` / **R$ 356,53 BRL**).

---

## 📊 3. Projeção de Juros Compostos (12 Meses - Base Freio 0.92)

Projeção de crescimento da conta com compounding automático com o novo freio ajustado:

*   **Saldo Inicial:** 72.615 USC (**R$ 3.775,97**)

| Mês | Cenário 6% (Super Conservador) | Cenário 8% (Conservador - Real) | Cenário 12% (Equilibrado) | Cenário 16% (Meta Alvo 0.92) |
| :---: | :--- | :--- | :--- | :--- |
| **00** | 72.615 USC (**R$ 3.775,97**) | 72.615 USC (**R$ 3.775,97**) | 72.615 USC (**R$ 3.775,97**) | 72.615 USC (**R$ 3.775,97**) |
| **01** | 76.972 USC (**R$ 4.002,54**) | 78.424 USC (**R$ 4.078,05**) | 81.329 USC (**R$ 4.229,09**) | 84.233 USC (**R$ 4.380,13**) |
| **02** | 81.590 USC (**R$ 4.242,70**) | 84.698 USC (**R$ 4.404,30**) | 91.088 USC (**R$ 4.736,58**) | 97.711 USC (**R$ 5.080,95**) |
| **03** | 86.486 USC (**R$ 4.497,26**) | 91.474 USC (**R$ 4.756,64**) | 102.019 USC (**R$ 5.304,97**) | 113.344 USC (**R$ 5.893,90**) |
| **04** | 91.675 USC (**R$ 4.767,10**) | 98.792 USC (**R$ 5.137,17**) | 114.261 USC (**R$ 5.941,57**) | 131.480 USC (**R$ 6.836,93**) |
| **05** | 97.175 USC (**R$ 5.053,12**) | 106.695 USC (**R$ 5.548,14**) | 127.972 USC (**R$ 6.654,56**) | 152.516 USC (**R$ 7.930,84**) |
| **06** | 103.006 USC (**R$ 5.356,31**) | 115.231 USC (**R$ 5.991,99**) | 143.329 USC (**R$ 7.453,11**) | 176.919 USC (**R$ 9.199,78**) |
| **07** | 109.186 USC (**R$ 5.677,69**) | 124.449 USC (**R$ 6.471,35**) | 160.528 USC (**R$ 8.347,48**) | 205.226 USC (**R$ 10.671,74**) |
| **08** | 115.738 USC (**R$ 6.018,35**) | 134.405 USC (**R$ 6.989,06**) | 179.792 USC (**R$ 9.349,18**) | 238.062 USC (**R$ 12.379,22**) |
| **09** | 122.682 USC (**R$ 6.379,45**) | 145.157 USC (**R$ 7.548,19**) | 201.367 USC (**R$ 10.471,08**) | 276.152 USC (**R$ 14.359,90**) |
| **10** | 130.043 USC (**R$ 6.762,22**) | 156.770 USC (**R$ 8.152,04**) | 225.531 USC (**R$ 11.727,61**) | 320.336 USC (**R$ 16.657,49**) |
| **11** | 137.845 USC (**R$ 7.167,96**) | 169.312 USC (**R$ 8.804,21**) | 252.595 USC (**R$ 13.134,92**) | 371.590 USC (**R$ 19.322,69**) |
| **12** | **146.116 USC (R$ 7.598,04)**| **182.857 USC (R$ 9.508,54)**| **282.906 USC (R$ 14.711,11)**| **431.045 USC (R$ 22.414,32)**|

---

## 🛠️ 4. O que pode ser melhorado para Reduzir o Risco em Pips?

Para que o robô aguente **mais pips** contrários (aumentando a margem de sobrevivência de 192 pips para 250+ pips no N6), sugerimos:

1.  **Reduzir a Semente Base (`InpLotInitial`):** Mudar de `0.015` para **`0.010`**. Isso reduz todos os lotes em 33% e aumenta a margem de sobrevivência em pips em **50%**.
2.  **Reduzir o Multiplicador da Grade (`InpLotMultiplier`):** Mudar de `1.50` para **`1.35`** ou **`1.40`**. Diminui o volume do N6 de 16,01 para **11,11 Lotes**, diminuindo o custo por pip contrários.
3.  **Aumentar o Espaçamento de Grade (`InpDist_Base`):** Mudar de `1.2` para **`1.5`** ou **`1.8`**. Faz o robô espaçar mais as ordens, impedindo que atinja o N6 tão facilmente.

---

*Aviso: Operações no mercado Forex envolvem alto risco. As sugestões acima visam blindar a conta contra quebras repentinas, equilibrando a excelente rentabilidade obtida com a sobrevivência a longo prazo do capital.*
