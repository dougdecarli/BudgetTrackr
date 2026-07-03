//
//  FinanceAppTests.swift
//  FinanceAppTests
//
//  Created by Douglas de Carli Immig on 01/06/26.
//

import Testing
import Foundation
@testable import FinanceApp

struct FinanceAppTests {

    // A representative slice of a Nubank statement in PDFKit's single-line
    // layout: the cardholder summary (no leading date, must be ignored), a plain
    // purchase, an installment, a NuPay charge with no card mask, an
    // international charge whose amount lands after conversion lines (one of which
    // also contains "R$"), the two IOF fee lines that net to zero, and the
    // trailing payments section that parsing must stop at.
    private static let sampleStatement = """
    TRANSAÇÕES DE 02 JUN A 02 JUL
    Douglas C Immig R$ 5.287,83
    02 JUN •••• 0108 Casa da Bebida - Parcela 3/3 R$ 122,74
    02 JUN •••• 0108 99food *99food R$ 22,90
    02 JUN Decolar C - NuPay - Parcela 10/12 R$ 1.049,01
    06 JUN IOF de volta de Anthropic* Claude Sub −R$ 4,00
    07 JUN •••• 0108 Anthropic* Claude Sub
    BRL 110.00 = USD 21.57
    Conversão: BRL 5.30 = USD 1 = R$ 5,30
    R$ 114,40
    07 JUN IOF de "Anthropic* Claude Sub" R$ 4,00
    Pagamentos e Financiamentos -R$ 7.345,29
    05 JUN Pagamento em 05 JUN −R$ 7.345,29
    """

    private func parseSample() -> ParsedInvoice {
        let periodEnd = DateComponents(calendar: .init(identifier: .gregorian), year: 2026, month: 7, day: 2).date!
        return NubankInvoiceParser.parse(text: Self.sampleStatement, periodEnd: periodEnd)
    }

    @Test func parsesOnlyRealTransactionsAndStopsAtPayments() {
        let result = parseSample()
        // 4 purchases + 2 fees; the cardholder summary and payments are excluded.
        #expect(result.transactions.count == 6)
        #expect(result.transactions.filter { !$0.isFee }.count == 4)
        #expect(result.transactions.filter { $0.isFee }.count == 2)
    }

    @Test func totalReconciles() {
        // 122.74 + 22.90 + 1049.01 − 4.00 + 114.40 + 4.00 = 1309.05
        #expect(parseSample().total == Decimal(string: "1309.05"))
    }

    @Test func parsesNuPayChargeWithoutCardMask() {
        let decolar = parseSample().transactions.first { $0.rawDescription.contains("Decolar") }
        #expect(decolar?.amount == Decimal(string: "1049.01"))
        #expect(decolar?.installmentCurrent == 10)
        #expect(decolar?.installmentTotal == 12)
    }

    @Test func ignoresInternationalConversionLineAsAmount() {
        let anthropic = parseSample().transactions.first { $0.rawDescription.contains("Claude") && !$0.isFee }
        // Must be the real R$ 114,40, not the R$ 5,30 from the conversion line.
        #expect(anthropic?.amount == Decimal(string: "114.40"))
    }

    @Test func parsesInstallment() {
        let casa = parseSample().transactions.first { $0.rawDescription == "Casa da Bebida" }
        #expect(casa?.installmentCurrent == 3)
        #expect(casa?.installmentTotal == 3)
    }

    @Test func creditAdjustmentIsFlaggedAsNonPurchase() {
        let statement = """
        TRANSAÇÕES DE 02 JUN A 02 JUL
        02 JUN •••• 0108 99food *99food R$ 22,90
        05 JUN Ajuste a crédito −R$ 75,04
        Pagamentos e Financiamentos -R$ 7.345,29
        """
        let periodEnd = DateComponents(calendar: .init(identifier: .gregorian), year: 2026, month: 7, day: 2).date!
        let result = NubankInvoiceParser.parse(text: statement, periodEnd: periodEnd)
        let adjustment = result.transactions.first { $0.rawDescription.localizedCaseInsensitiveContains("Ajuste") }
        #expect(adjustment?.isFee == true)
        // Still counts toward the total, but is not a categorizable purchase.
        #expect(result.transactions.filter { !$0.isFee }.count == 1)
        #expect(result.total == Decimal(string: "-52.14"))
    }

    @Test func ignoresDatedInvoicePaymentLines() {
        let statement = """
        TRANSAÇÕES DE 03 MAI A 02 JUN
        03 MAI Pagamento em 03 MAI −R$ 3.048,29
        04 MAI •••• 0108 Mercado Central R$ 125,40
        05 MAI •••• 0108 Farmacia Boa R$ 45,00
        """
        let periodEnd = DateComponents(calendar: .init(identifier: .gregorian), year: 2026, month: 6, day: 2).date!
        let result = NubankInvoiceParser.parse(text: statement, periodEnd: periodEnd)

        #expect(result.transactions.count == 2)
        #expect(result.transactions.allSatisfy { !$0.rawDescription.localizedCaseInsensitiveContains("Pagamento") })
        #expect(result.total == Decimal(string: "170.40"))
    }

    @Test func flagsFeesAndSigns() {
        let fees = parseSample().transactions.filter { $0.isFee }
        #expect(fees.contains { $0.amount == Decimal(string: "4.00") })
        #expect(fees.contains { $0.amount == Decimal(string: "-4.00") })
    }

    @Test func amountParsingAnchorsToWholeLine() {
        #expect(NubankInvoiceParser.parseAmount("R$ 1.234,56") == Decimal(string: "1234.56"))
        #expect(NubankInvoiceParser.parseAmount("−R$ 4,00") == Decimal(string: "-4.00"))
        #expect(NubankInvoiceParser.parseAmount("Conversão: BRL 5.30 = USD 1 = R$ 5,30") == nil)
        #expect(NubankInvoiceParser.parseAmount("BRL 110.00 = USD 21.57") == nil)
    }

    @Test func merchantKeyNormalizes() {
        #expect(NubankInvoiceParser.merchantKey(from: "Ifd*Emporio das Massas")
            == NubankInvoiceParser.merchantKey(from: "ifd*emporio das massas"))
    }

    // MARK: - Itaú

    // Domestic charges (two-line, with the flipped page-break variant), the
    // payment line that must be skipped, an international charge whose R$ amount
    // is on the date line plus its IOF repasse, and the future-installments
    // section that must be excluded.
    private static let itauStatement = """
    Total desta fatura 350,00
    Pagamentos efetuados
    DATA VALOR EM R$
    Lançamentos: compras e saques
    DATA ESTABELECIMENTO VALOR EM R$
    06/02 Pagamento via conta -8.236,91
    Total dos pagamentos -8.236,91
    Lançamentos: compras e saques
    DOUGLAS DE CARLI IMMIG
    DATA ESTABELECIMENTO VALOR EM R$
    13/02 PadariaMonteCarloTRAMAN 54,50
    supermercado TRAMANDAI
    15/02 IFD*CASA DI PAOLO RESTC 106,38
    restaurante CANOAS
    24/02 Uber UBER *TRIP HELP.US transporte SAO PAULO
    9,97
    27/11 COTTON ON DO B 04/05 46,78
    vestuário Sao Paulo
    Lançamentos no cartão 217,63
    Lançamentos internacionais
    DATA ESTABELECIMENTO US$ R$
    01/11 OPENAI *CHATGPT SUBSCRS 128,38
    20,00 USD 20,00
    Dólar de Conversão R$ 5,70
    Total transações inter. em R$ Repasse de IOF em R$ Total lançamentos inter. em R$ 128,38
    3,99
    132,37
    Total dos lançamentos atuais 350,00
    Compras parceladas - próximas faturas
    DATA ESTABELECIMENTO VALOR EM R$
    06/06 Nestle Brasil 10/10 28,79
    """

    private func parseItau() -> ParsedInvoice {
        let periodEnd = DateComponents(calendar: .init(identifier: .gregorian), year: 2026, month: 3, day: 2).date!
        return ItauInvoiceParser.parse(text: Self.itauStatement, periodEnd: periodEnd)
    }

    @Test func itauReconcilesToStatedTotalAndExcludesPaymentsAndFutureInstallments() {
        let result = parseItau()
        // 4 domestic purchases + 1 international + 1 IOF fee. Payment and the
        // "próximas faturas" installment are excluded.
        #expect(result.transactions.count == 6)
        #expect(result.total == Decimal(string: "350.00"))
        let summed = result.transactions.reduce(Decimal(0)) { $0 + $1.amount }
        #expect(summed == Decimal(string: "350.00"))
    }

    @Test func itauParsesInstallmentAndUsesSegmentAsSuggestedCategory() {
        let cotton = parseItau().transactions.first { $0.rawDescription.contains("COTTON") }
        #expect(cotton?.installmentCurrent == 4)
        #expect(cotton?.installmentTotal == 5)
        #expect(cotton?.suggestedCategoryName == "Vestuário")

        let padaria = parseItau().transactions.first { $0.rawDescription.contains("Padaria") }
        #expect(padaria?.suggestedCategoryName == "Mercado")
    }

    @Test func itauHandlesFlippedPageBreakLayout() {
        // "24/02 Uber … transporte SAO PAULO" with the amount on the next line.
        let uber = parseItau().transactions.first { $0.rawDescription.contains("Uber") }
        #expect(uber?.amount == Decimal(string: "9.97"))
        #expect(uber?.suggestedCategoryName == "Transporte")
    }

    @Test func itauInternationalCarriesRealAmountAndIOF() {
        let openai = parseItau().transactions.first { $0.rawDescription.contains("OPENAI") }
        #expect(openai?.amount == Decimal(string: "128.38"))
        let iof = parseItau().transactions.first { $0.isFee }
        #expect(iof?.amount == Decimal(string: "3.99"))
    }

    @Test func detectsBankFromText() {
        #expect(InvoiceParsing.detectBank(in: "... Banco Itaú S.A. ...") == .itau)
        #expect(InvoiceParsing.detectBank(in: "... Nu Pagamentos S.A. ...") == .nubank)
        #expect(InvoiceParsing.detectBank(in: "... cartão SANTANDER UNIQUE VISA ...") == .santander)
    }

    // MARK: - Santander

    // Two cards, the previous-invoice payment (excluded), a refund credit, a
    // zero-value annuity line (skipped), and an installment in the "Parcela"
    // column. Reconciles to purchases − credits.
    private static let santanderStatement = """
    Detalhamento da Fatura
    DANIELA CARLI IMMIG - 4258 XXXX XXXX 1895
    Pagamento e Demais Créditos
    Compra Data Descrição Parcela R$ US$
    08/06 DEB AUTOM DE FATURA EM C/ -2.015,68
    Despesas
    Compra Data Descrição Parcela R$ US$
    07/06 IFD*IFOOD 7,95
    3 10/06 MAXI BELEZA 84,99
    29/06 ANUIDADE DIFERENCIADA 0,00
    VALOR TOTAL 92,94 0,00
    @ DANIELA CARLI IMM - 4258 XXXX XXXX 0439
    Pagamento e Demais Créditos
    Compra Data Descrição Parcela R$ US$
    10/05 SHEIN *SHEINCOM -5,62
    Parcelamentos
    Compra Data Descrição Parcela R$ US$
    27/04 AIRBNB PAGAM*AIRB 02/04 580,35
    Despesas
    Compra Data Descrição Parcela R$ US$
    06/06 99* 2,00
    07/06 APPLE COM/BILL 66,90
    VALOR TOTAL 649,25 0,00
    Resumo da Fatura
    """

    private func parseSantander() -> ParsedInvoice {
        let periodEnd = DateComponents(calendar: .init(identifier: .gregorian), year: 2026, month: 7, day: 6).date!
        return SantanderInvoiceParser.parse(text: Self.santanderStatement, periodEnd: periodEnd)
    }

    @Test func santanderReconcilesExcludingPaymentAndZeroLines() {
        let result = parseSantander()
        // 5 purchases + 1 refund fee; payment and the R$0,00 annuity are excluded.
        #expect(result.transactions.count == 6)
        #expect(result.transactions.filter { !$0.isFee }.count == 5)
        #expect(result.transactions.filter { $0.isFee }.count == 1)
        // 7.95 + 84.99 + 580.35 + 2.00 + 66.90 − 5.62 = 736.57
        #expect(result.total == Decimal(string: "736.57"))
        #expect(!result.transactions.contains { $0.rawDescription.contains("DEB AUTOM") })
    }

    @Test func santanderParsesParcelaColumnAndRefund() {
        let airbnb = parseSantander().transactions.first { $0.rawDescription.contains("AIRBNB") }
        #expect(airbnb?.amount == Decimal(string: "580.35"))
        #expect(airbnb?.installmentCurrent == 2)
        #expect(airbnb?.installmentTotal == 4)

        let shein = parseSantander().transactions.first { $0.rawDescription.contains("SHEIN") }
        #expect(shein?.isFee == true)
        #expect(shein?.amount == Decimal(string: "-5.62"))
    }

    @Test func seedCategorizationMapsCommonMerchants() {
        #expect(MerchantCategorizer.seedCategoryName(forKey: "ifd*emporio das massas") == "Alimentação")
        #expect(MerchantCategorizer.seedCategoryName(forKey: "zaffari park canoas") == "Mercado")
        #expect(MerchantCategorizer.seedCategoryName(forKey: "uber uber *trip help.u") == "Transporte")
    }

    @Test func seedCategorizationCoversMerchantsFromRealInvoices() {
        // Generalizing keywords learned from real statements.
        #expect(MerchantCategorizer.seedCategoryName(forKey: "casa di paolo restaura") == "Alimentação")
        #expect(MerchantCategorizer.seedCategoryName(forKey: "the best acai canoas") == "Alimentação")
        #expect(MerchantCategorizer.seedCategoryName(forKey: "restaurant yaaxkin") == "Alimentação")
        #expect(MerchantCategorizer.seedCategoryName(forKey: "unisuper inconfidencia") == "Mercado")
        #expect(MerchantCategorizer.seedCategoryName(forKey: "estapar reserva 2141q3") == "Transporte")
        #expect(MerchantCategorizer.seedCategoryName(forKey: "abastec*abastece ai") == "Transporte")
        #expect(MerchantCategorizer.seedCategoryName(forKey: "whattodoincancun.com") == "Lazer")
        #expect(MerchantCategorizer.seedCategoryName(forKey: "applecombill") == "Contas")
        // "amazon prime" (subscription) must win over the generic "amazon" rule.
        #expect(MerchantCategorizer.seedCategoryName(forKey: "amazon prime canais") == "Contas")
        #expect(MerchantCategorizer.seedCategoryName(forKey: "amazon marketplace cc") == "Compras")
        // Clothing maps to Vestuário (a non-default category — the app only
        // applies it when such a category exists).
        #expect(MerchantCategorizer.seedCategoryName(forKey: "mlp *netshoes-nike") == "Vestuário")
    }

    @Test func seedCategorizationCoversMerchantsFromGabrielaInvoices() {
        // "Incacervejasy" — Nubank truncates the merchant name, so the keyword is
        // the "cervej" root, not the full word "cervejaria".
        #expect(MerchantCategorizer.seedCategoryName(forKey: "incacervejasy") == "Alimentação")
        #expect(MerchantCategorizer.seedCategoryName(forKey: "rj gastronomia e even") == "Alimentação")
        #expect(MerchantCategorizer.seedCategoryName(forKey: "cacau show") == "Alimentação")
        #expect(MerchantCategorizer.seedCategoryName(forKey: "doca bar festas") == "Alimentação")
        #expect(MerchantCategorizer.seedCategoryName(forKey: "raia438") == "Saúde")
        #expect(MerchantCategorizer.seedCategoryName(forKey: "otb park canoas") == "Transporte")
        #expect(MerchantCategorizer.seedCategoryName(forKey: "estreito da chosen") == "Vestuário")
        #expect(MerchantCategorizer.seedCategoryName(forKey: "bazar zhou") == "Compras")
        #expect(MerchantCategorizer.seedCategoryName(forKey: "bella acessorios e pre") == "Compras")
        // Personal/company names with no generalizable signal stay uncategorized
        // — they become MerchantRules once the user categorizes them once.
        #expect(MerchantCategorizer.seedCategoryName(forKey: "pauloheinzecialtd") == nil)
        #expect(MerchantCategorizer.seedCategoryName(forKey: "jim.com* 36881584 riz") == nil)
    }
}
