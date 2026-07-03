import SwiftUI

/// A one-time, first-launch tutorial presented as a swipeable carousel. Explains
/// the core concepts — income, expenses (recurring / one-off / card invoice) and
/// categories — mirroring the real dashboard vocabulary. Purely presentational:
/// the caller decides what to do when it finishes (mark onboarding complete on
/// first launch, or simply dismiss when re-opened from Ajustes).
struct OnboardingView: View {
    /// Called when the user reaches the end ("Começar") or taps "Pular".
    let onFinish: () -> Void

    @State private var selection = 0

    private let pages = OnboardingPage.all

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Pular", action: onFinish)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .opacity(isLastPage ? 0 : 1)
            .accessibilityHidden(isLastPage)

            TabView(selection: $selection) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(action: advance) {
                Text(isLastPage ? "Começar" : "Próximo")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var isLastPage: Bool { selection == pages.count - 1 }

    private func advance() {
        if isLastPage {
            onFinish()
        } else {
            withAnimation { selection += 1 }
        }
    }
}

/// A single slide's content — an SF Symbol illustration, a title and a short body.
private struct OnboardingPage {
    let icon: String
    let tint: Color
    let title: LocalizedStringKey
    let body: LocalizedStringKey

    static let all: [OnboardingPage] = [
        OnboardingPage(
            icon: "calendar",
            tint: Theme.card,
            title: "Suas finanças, mês a mês",
            body: "Organize renda e gastos de forma simples, um mês de cada vez."
        ),
        OnboardingPage(
            icon: "arrow.down.left.circle.fill",
            tint: Theme.income,
            title: "Comece pela sua renda",
            body: "Cadastre suas fontes de renda — salário, benefícios e outros — para saber quanto entra a cada mês."
        ),
        OnboardingPage(
            icon: "arrow.up.right.circle.fill",
            tint: Theme.spending,
            title: "Acompanhe seus gastos",
            body: "Registre despesas recorrentes (fixas), avulsas (pontuais) e a fatura do cartão, tudo separado por mês."
        ),
        OnboardingPage(
            icon: "tag.fill",
            tint: Theme.oneOff,
            title: "Tudo por categoria",
            body: "O app já vem com categorias como Moradia, Alimentação e Transporte. Ajuste ou crie as suas em Ajustes."
        ),
        OnboardingPage(
            icon: "chart.pie.fill",
            tint: Theme.recurring,
            title: "Pronto para começar",
            body: "Use a barra de adição rápida para lançar valores e acompanhe o resumo do mês no gráfico."
        ),
    ]
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.tint.opacity(0.15))
                    .frame(width: 140, height: 140)
                Image(systemName: page.icon)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(page.tint)
            }
            .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
