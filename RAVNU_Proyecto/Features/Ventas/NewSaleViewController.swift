import UIKit
import SwiftUI

struct OpcionCliente {
    let id: String
    let name: String
    let status: String
    let debt: Double
    let limit: Double
}

struct OpcionProductoVenta {
    let id: String
    let name: String
    let pricePerUnit: Double
    let unit: String
    let availableStock: Double
    let warehouseName: String
}

struct BorradorNuevaVenta {
    let clientIndex: Int
    let productIndex: Int
    let quantity: Int
    let paymentType: String
    let installments: Int
    let firstDueDate: Date
}

final class NuevaVentaViewController: UIViewController {

    private let clients: [OpcionCliente]
    private let products: [OpcionProductoVenta]
    private let onCancel: () -> Void
    private let onSave: (BorradorNuevaVenta) -> Void

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let headerView = UIView()
    private let separatorView = UIView()

    private let titleLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let clientDropdown: DropdownButton
    private let productDropdown: DropdownButton
    private let quantityField = LabeledNumberField(sectionTitle: "CANTIDAD", subtitle: "litros")
    private let stockInsightCard = StockInsightCardView()
    private let totalContainer = UIView()
    private let totalLabel = UILabel()
    private let paymentToggle = PaymentToggleControl()
    private let creditSectionCard = CreditSectionView()
    private let impactSectionCard = SaleImpactCardView()
    private let saveButton = UIButton(type: .system)
    private var hostingController: UIHostingController<FormularioNuevaVentaView>?

    private var selectedClientIndex: Int {
        didSet { updateClientUI() }
    }
    private var selectedProductIndex: Int {
        didSet { updateProductUI() }
    }
    private var quantity: Int = 40 {
        didSet { recalculateTotal() }
    }
    private var paymentType: String = "credit" {
        didSet { updatePaymentTypeUI(animated: true) }
    }
    private var installments: Int = 3 {
        didSet {
            installments = min(max(installments, 1), 12)
            recalculateTotal()
        }
    }
    private var firstDueDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date() {
        didSet { updateCreditSection() }
    }

    private var selectedClient: OpcionCliente { clients[selectedClientIndex] }
    private var selectedProduct: OpcionProductoVenta { products[selectedProductIndex] }
    private var total: Double { Double(quantity) * selectedProduct.pricePerUnit }
    private var perInstallment: Double { total / Double(max(installments, 1)) }
    private var usedPercent: Float {
        guard selectedClient.limit > 0 else { return 0 }
        return Float(selectedClient.debt / selectedClient.limit)
    }

    init(
        clients: [OpcionCliente],
        products: [OpcionProductoVenta],
        initialClientIndex: Int,
        initialProductIndex: Int,
        onCancel: @escaping () -> Void,
        onSave: @escaping (BorradorNuevaVenta) -> Void
    ) {
        self.clients = clients
        self.products = products
        self.selectedClientIndex = min(max(initialClientIndex, 0), max(clients.count - 1, 0))
        self.selectedProductIndex = min(max(initialProductIndex, 0), max(products.count - 1, 0))
        self.onCancel = onCancel
        self.onSave = onSave
        self.clientDropdown = DropdownButton(sectionTitle: "CLIENTE", iconName: "person.fill")
        self.productDropdown = DropdownButton(sectionTitle: "PRODUCTO", iconName: "drop.fill")
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .appBackground
        hostingController = embedHostedView(crearVistaRaiz(), backgroundColor: .clear)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func crearVistaRaiz() -> FormularioNuevaVentaView {
        FormularioNuevaVentaView(
            clients: clients,
            products: products,
            initialClientIndex: selectedClientIndex,
            initialProductIndex: selectedProductIndex,
            initialQuantity: quantity,
            initialPaymentType: paymentType,
            initialInstallments: installments,
            initialDueDate: firstDueDate,
            onCancel: onCancel,
            onSave: onSave
        )
    }

    private func setupScrollView() {
        [scrollView, contentView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 57),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func setupHeader() {
        [headerView, titleLabel, cancelButton, separatorView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        view.addSubview(headerView)
        view.addSubview(separatorView)
        headerView.backgroundColor = .appBackground
        separatorView.backgroundColor = .separator

        titleLabel.text = "Nueva Venta"
        titleLabel.font = .sfRounded(size: 18, weight: .semibold)
        titleLabel.textColor = .label

        cancelButton.setTitle("Cancelar", for: .normal)
        cancelButton.setTitleColor(.appBlue, for: .normal)
        cancelButton.setTitleColor(.appBlue.withAlphaComponent(0.6), for: .highlighted)
        cancelButton.titleLabel?.font = .sfRounded(size: 16, weight: .regular)

        headerView.addSubview(titleLabel)
        headerView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 56),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            cancelButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            cancelButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            separatorView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            separatorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func setupForm() {
        [clientDropdown, productDropdown, stockInsightCard, quantityField, totalContainer, paymentToggle, creditSectionCard, impactSectionCard, saveButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        totalContainer.backgroundColor = .appCard
        totalContainer.layer.cornerRadius = 16
        totalContainer.applyCardShadow()

        totalLabel.translatesAutoresizingMaskIntoConstraints = false
        totalLabel.font = .sfRounded(size: 26, weight: .bold)
        totalLabel.textColor = .appBlue
        totalLabel.textAlignment = .center
        totalContainer.addSubview(totalLabel)

        saveButton.backgroundColor = .appBlue
        saveButton.layer.cornerRadius = 14
        saveButton.setTitle("Guardar Venta", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = .sfRounded(size: 17, weight: .semibold)
        saveButton.layer.shadowColor = UIColor.appBlue.cgColor
        saveButton.layer.shadowOpacity = 0.35
        saveButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        saveButton.layer.shadowRadius = 10

        NSLayoutConstraint.activate([
            clientDropdown.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            clientDropdown.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            clientDropdown.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            productDropdown.topAnchor.constraint(equalTo: clientDropdown.bottomAnchor, constant: 16),
            productDropdown.leadingAnchor.constraint(equalTo: clientDropdown.leadingAnchor),
            productDropdown.trailingAnchor.constraint(equalTo: clientDropdown.trailingAnchor),

            stockInsightCard.topAnchor.constraint(equalTo: productDropdown.bottomAnchor, constant: 14),
            stockInsightCard.leadingAnchor.constraint(equalTo: clientDropdown.leadingAnchor),
            stockInsightCard.trailingAnchor.constraint(equalTo: clientDropdown.trailingAnchor),

            quantityField.topAnchor.constraint(equalTo: stockInsightCard.bottomAnchor, constant: 16),
            quantityField.leadingAnchor.constraint(equalTo: clientDropdown.leadingAnchor),
            quantityField.trailingAnchor.constraint(equalTo: clientDropdown.trailingAnchor),

            totalContainer.topAnchor.constraint(equalTo: quantityField.bottomAnchor, constant: 16),
            totalContainer.leadingAnchor.constraint(equalTo: clientDropdown.leadingAnchor),
            totalContainer.trailingAnchor.constraint(equalTo: clientDropdown.trailingAnchor),

            totalLabel.topAnchor.constraint(equalTo: totalContainer.topAnchor, constant: 22),
            totalLabel.leadingAnchor.constraint(equalTo: totalContainer.leadingAnchor, constant: 16),
            totalLabel.trailingAnchor.constraint(equalTo: totalContainer.trailingAnchor, constant: -16),
            totalLabel.bottomAnchor.constraint(equalTo: totalContainer.bottomAnchor, constant: -22),

            paymentToggle.topAnchor.constraint(equalTo: totalContainer.bottomAnchor, constant: 16),
            paymentToggle.leadingAnchor.constraint(equalTo: clientDropdown.leadingAnchor),
            paymentToggle.trailingAnchor.constraint(equalTo: clientDropdown.trailingAnchor),
            paymentToggle.heightAnchor.constraint(equalToConstant: 44),

            creditSectionCard.topAnchor.constraint(equalTo: paymentToggle.bottomAnchor, constant: 16),
            creditSectionCard.leadingAnchor.constraint(equalTo: clientDropdown.leadingAnchor),
            creditSectionCard.trailingAnchor.constraint(equalTo: clientDropdown.trailingAnchor),

            impactSectionCard.topAnchor.constraint(equalTo: creditSectionCard.bottomAnchor, constant: 16),
            impactSectionCard.leadingAnchor.constraint(equalTo: clientDropdown.leadingAnchor),
            impactSectionCard.trailingAnchor.constraint(equalTo: clientDropdown.trailingAnchor),

            saveButton.topAnchor.constraint(equalTo: impactSectionCard.bottomAnchor, constant: 20),
            saveButton.leadingAnchor.constraint(equalTo: clientDropdown.leadingAnchor),
            saveButton.trailingAnchor.constraint(equalTo: clientDropdown.trailingAnchor),
            saveButton.heightAnchor.constraint(equalToConstant: 52),
            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
    }

    private func bindActions() {
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveSaleTapped), for: .touchUpInside)

        clientDropdown.onTap = { [weak self] in self?.presentOpcionClientes() }
        productDropdown.onTap = { [weak self] in self?.presentProductOptions() }
        quantityField.onValueChanged = { [weak self] value in self?.quantity = value }
        paymentToggle.onToggle = { [weak self] type in self?.paymentType = type }

        creditSectionCard.onInstallmentsChanged = { [weak self] value in self?.installments = value }
        creditSectionCard.onDueDateTapped = { [weak self] in self?.presentDueDatePicker() }
    }

    private func refreshAll() {
        quantityField.value = quantity
        paymentToggle.setSelected(type: paymentType)
        updateClientUI()
        updateProductUI()
        updatePaymentTypeUI(animated: false)
        recalculateTotal()
    }

    private func updateClientUI() {
        let client = selectedClient
        clientDropdown.configure(mainText: client.name, subtitle: nil)
        updateCreditSection()
    }

    private func updateProductUI() {
        let product = selectedProduct
        productDropdown.configure(mainText: product.name, subtitle: "\(formatCurrency(product.pricePerUnit)) por \(localizedUnit(product.unit))")
        quantityField.maxValue = max(Int(product.availableStock.rounded(.down)), 1)
        recalculateTotal()
    }

    private func updatePaymentTypeUI(animated: Bool) {
        paymentToggle.setSelected(type: paymentType)
        let shouldShow = paymentType == "credit"
        let updates = {
            self.creditSectionCard.isHidden = !shouldShow
            self.creditSectionCard.alpha = shouldShow ? 1 : 0
            self.view.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.3, animations: updates)
        } else {
            updates()
        }
    }

    private func updateCreditSection() {
        creditSectionCard.update(
            installments: installments,
            perInstallmentText: formatCurrency(perInstallment),
            dueDateText: dueDateFormatter.string(from: firstDueDate),
            statusText: localizedStatus(selectedClient.status),
            status: selectedClient.status,
            clientName: selectedClient.name,
            creditUsageText: "\(formatCurrency(selectedClient.debt)) usados de \(formatCurrency(selectedClient.limit)) límite",
            progress: max(0, min(1, CGFloat(usedPercent)))
        )
    }

    private func recalculateTotal() {
        let remainingStock = max(selectedProduct.availableStock - Double(quantity), 0)
        totalLabel.text = "Total: \(formatCurrency(total))"
        stockInsightCard.update(
            availableText: "\(formatNumber(selectedProduct.availableStock))\(compactUnit(selectedProduct.unit)) disponibles",
            warehouseText: selectedProduct.warehouseName,
            remainingText: "Restante: \(formatNumber(remainingStock))\(compactUnit(selectedProduct.unit))"
        )
        impactSectionCard.update(
            quantityText: "Almacén -\(quantity)\(compactUnit(selectedProduct.unit))",
            treasuryText: "Tesorería +\(formatCurrencyCompact(total))",
            receivableText: "Cobros +deuda",
            showsReceivable: paymentType == "credit"
        )
        updateCreditSection()
    }

    private func localizedUnit(_ unit: String) -> String {
        switch unit.lowercased() {
        case "liter", "litro", "l":
            return "litro"
        case "bal":
            return "balón"
        default:
            return unit
        }
    }

    private func compactUnit(_ unit: String) -> String {
        switch unit.lowercased() {
        case "liter", "litro", "l":
            return "L"
        case "bal":
            return " bal"
        default:
            return " \(unit)"
        }
    }

    private func presentOpcionClientes() {
        let alert = UIAlertController(title: "Cliente", message: "Selecciona un cliente", preferredStyle: .actionSheet)
        for (index, client) in clients.enumerated() {
            alert.addAction(UIAlertAction(title: client.name, style: .default) { [weak self] _ in
                self?.selectedClientIndex = index
            })
        }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        present(alert, animated: true)
    }

    private func presentProductOptions() {
        let alert = UIAlertController(title: "Producto", message: "Selecciona un producto", preferredStyle: .actionSheet)
        for (index, product) in products.enumerated() {
            let title = "\(product.name) · \(formatCurrency(product.pricePerUnit))"
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.selectedProductIndex = index
            })
        }
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        present(alert, animated: true)
    }

    private func presentDueDatePicker() {
        let pickerVC = DatePickerSheetViewController(selectedDate: firstDueDate) { [weak self] date in
            self?.firstDueDate = date
        }
        if let sheet = pickerVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        present(pickerVC, animated: true)
    }

    @objc private func saveSaleTapped() {
        guard quantity > 0 else { return }
        let draft = BorradorNuevaVenta(
            clientIndex: selectedClientIndex,
            productIndex: selectedProductIndex,
            quantity: quantity,
            paymentType: paymentType,
            installments: installments,
            firstDueDate: firstDueDate
        )
        onSave(draft)
    }

    @objc private func cancelTapped() {
        onCancel()
    }

    @objc private func endEditingTap() {
        view.endEditing(true)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        scrollView.contentInset.bottom = frame.height + 20
        scrollView.verticalScrollIndicatorInsets.bottom = frame.height + 20
    }

    @objc private func keyboardWillHide() {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }

    private func registerKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    private func formatCurrency(_ value: Double) -> String {
        "S/ \(String(format: "%.2f", value))"
    }

    private func formatCurrencyCompact(_ value: Double) -> String {
        "S/\(String(format: "%.0f", value))"
    }

    private func formatNumber(_ value: Double) -> String {
        if value == value.rounded() {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    private func localizedStatus(_ status: String) -> String {
        switch status {
        case "activo": return "Activo"
        case "enRiesgo": return "En riesgo"
        case "vencido": return "Vencido"
        case "blocked": return "Bloqueado"
        default: return status.capitalized
        }
    }

    private lazy var dueDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PE")
        formatter.dateFormat = "dd MMM, yyyy"
        return formatter
    }()
}

private struct FormularioNuevaVentaView: View {
    let clients: [OpcionCliente]
    let products: [OpcionProductoVenta]
    let initialClientIndex: Int?
    let initialProductIndex: Int?
    let initialQuantity: Int
    let initialPaymentType: String
    let initialInstallments: Int
    let initialDueDate: Date
    let onCancel: () -> Void
    let onSave: (BorradorNuevaVenta) -> Void

    @State private var selectedClientIndex: Int
    @State private var selectedProductIndex: Int
    @State private var quantity: Int
    @State private var paymentType: String
    @State private var installments: Int
    @State private var dueDate: Date

    init(
        clients: [OpcionCliente],
        products: [OpcionProductoVenta],
        initialClientIndex: Int?,
        initialProductIndex: Int?,
        initialQuantity: Int,
        initialPaymentType: String,
        initialInstallments: Int,
        initialDueDate: Date,
        onCancel: @escaping () -> Void,
        onSave: @escaping (BorradorNuevaVenta) -> Void
    ) {
        self.clients = clients
        self.products = products
        self.initialClientIndex = initialClientIndex
        self.initialProductIndex = initialProductIndex
        self.initialQuantity = initialQuantity
        self.initialPaymentType = initialPaymentType
        self.initialInstallments = initialInstallments
        self.initialDueDate = initialDueDate
        self.onCancel = onCancel
        self.onSave = onSave

        _selectedClientIndex = State(initialValue: min(max(initialClientIndex ?? 0, 0), max(clients.count - 1, 0)))
        _selectedProductIndex = State(initialValue: min(max(initialProductIndex ?? 0, 0), max(products.count - 1, 0)))
        _quantity = State(initialValue: max(initialQuantity, 1))
        _paymentType = State(initialValue: initialPaymentType)
        _installments = State(initialValue: min(max(initialInstallments, 1), 12))
        _dueDate = State(initialValue: initialDueDate)
    }

    private var selectedClient: OpcionCliente? {
        guard clients.indices.contains(selectedClientIndex) else { return nil }
        return clients[selectedClientIndex]
    }

    private var selectedProduct: OpcionProductoVenta? {
        guard products.indices.contains(selectedProductIndex) else { return nil }
        return products[selectedProductIndex]
    }

    private var total: Double {
        Double(quantity) * (selectedProduct?.pricePerUnit ?? 0)
    }

    private var perInstallment: Double {
        total / Double(max(installments, 1))
    }

    private var maxQuantity: Int {
        max(Int((selectedProduct?.availableStock ?? 1).rounded(.down)), 1)
    }

    var body: some View {
        NavigationStack {
            Group {
                if clients.isEmpty || products.isEmpty {
                    estadoVacio
                } else {
                    contenidoFormulario
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar", action: onCancel)
                }
                ToolbarItem(placement: .principal) {
                    Text("Nueva Venta")
                        .font(.system(size: 18, weight: .semibold))
                }
            }
        }
    }

    private var contenidoFormulario: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                tarjeta {
                    VStack(alignment: .leading, spacing: 12) {
                        tituloSeccion("Cliente")
                        Picker("Cliente", selection: $selectedClientIndex) {
                            ForEach(Array(clients.enumerated()), id: \.offset) { index, client in
                                Text(client.name).tag(index)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.blue)

                        if let client = selectedClient {
                            Text("\(estadoLocalizado(client.status)) · Deuda \(moneda(client.debt)) / Límite \(moneda(client.limit))")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                tarjeta {
                    VStack(alignment: .leading, spacing: 12) {
                        tituloSeccion("Producto")
                        Picker("Producto", selection: $selectedProductIndex) {
                            ForEach(Array(products.enumerated()), id: \.offset) { index, product in
                                Text("\(product.name) · \(moneda(product.pricePerUnit))").tag(index)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.blue)

                        if let product = selectedProduct {
                            Text("\(numero(product.availableStock))\(unidadCompacta(product.unit)) disponibles · \(product.warehouseName)")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                tarjeta {
                    VStack(alignment: .leading, spacing: 12) {
                        tituloSeccion("Cantidad")
                        Stepper(value: $quantity, in: 1...maxQuantity) {
                            HStack {
                                Text("\(quantity) \(unidadLocalizada(selectedProduct?.unit ?? "L"))")
                                    .font(.system(size: 18, weight: .semibold))
                                Spacer()
                                Text("Máx. \(maxQuantity)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                tarjeta {
                    VStack(alignment: .leading, spacing: 12) {
                        tituloSeccion("Pago")
                        Picker("Tipo de pago", selection: $paymentType) {
                            Text("Contado").tag("cash")
                            Text("Crédito").tag("credit")
                        }
                        .pickerStyle(.segmented)

                        if paymentType == "credit" {
                            Stepper(value: $installments, in: 1...12) {
                                HStack {
                                    Text("Cuotas")
                                    Spacer()
                                    Text("\(installments)")
                                        .font(.system(size: 16, weight: .bold))
                                }
                            }

                            DatePicker(
                                "Primer vencimiento",
                                selection: $dueDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)

                            Text("Por cuota: \(moneda(perInstallment))")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                tarjeta {
                    VStack(alignment: .leading, spacing: 10) {
                        tituloSeccion("Impacto")
                        filaImpacto("Total", moneda(total), accent: .blue)
                        filaImpacto("Almacén", "-\(quantity)\(unidadCompacta(selectedProduct?.unit ?? "L"))", accent: .red)
                        filaImpacto("Tesorería", paymentType == "cash" ? "+\(moneda(total))" : "Pendiente", accent: .green)
                        if paymentType == "credit" {
                            filaImpacto("Cobros", "Se generarán cuotas", accent: .orange)
                        }
                    }
                }

                Button {
                    onSave(
                        BorradorNuevaVenta(
                            clientIndex: selectedClientIndex,
                            productIndex: selectedProductIndex,
                            quantity: quantity,
                            paymentType: paymentType,
                            installments: installments,
                            firstDueDate: dueDate
                        )
                    )
                } label: {
                    Text("Guardar Venta")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
    }

    private var estadoVacio: some View {
        VStack(spacing: 12) {
            Text("No hay datos suficientes para registrar la venta.")
                .font(.system(size: 18, weight: .semibold))
            Text("Debes tener al menos un cliente y un producto registrados.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private func tarjeta<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func tituloSeccion(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.secondary)
    }

    private func filaImpacto(_ title: String, _ value: String, accent: Color) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)
        }
    }

    private func estadoLocalizado(_ status: String) -> String {
        switch status.lowercased() {
        case "activo", "active":
            return "Activo"
        case "enriesgo", "atrisk":
            return "En riesgo"
        case "vencido", "overdue":
            return "Vencido"
        case "blocked", "bloqueado":
            return "Bloqueado"
        default:
            return status.capitalized
        }
    }

    private func unidadLocalizada(_ unit: String) -> String {
        switch unit.lowercased() {
        case "liter", "litro", "l":
            return "litros"
        case "bal":
            return "balones"
        default:
            return unit
        }
    }

    private func unidadCompacta(_ unit: String) -> String {
        switch unit.lowercased() {
        case "liter", "litro", "l":
            return "L"
        case "bal":
            return " bal"
        default:
            return " \(unit)"
        }
    }

    private func moneda(_ value: Double) -> String {
        "S/ \(String(format: "%.2f", value))"
    }

    private func numero(_ value: Double) -> String {
        if value == value.rounded() {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}

final class DropdownButton: UIControl {
    private let sectionLabel = UILabel()
    private let cardView = UIView()
    private let iconView = UIImageView()
    private let mainLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chevronView = UIImageView(image: UIImage(systemName: "chevron.down"))
    var onTap: (() -> Void)?

    init(sectionTitle: String, iconName: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        sectionLabel.text = sectionTitle
        sectionLabel.font = .sfRounded(size: 11, weight: .semibold)
        sectionLabel.textColor = .systemGray
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false

        cardView.backgroundColor = .appCard
        cardView.layer.cornerRadius = 12
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor.separator.cgColor
        cardView.isUserInteractionEnabled = false
        cardView.applyCardShadow()
        cardView.translatesAutoresizingMaskIntoConstraints = false

        iconView.image = UIImage(systemName: iconName)
        iconView.tintColor = .appBlue
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        mainLabel.font = .sfRounded(size: 15, weight: .bold)
        mainLabel.textColor = .label
        mainLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .sfRounded(size: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        chevronView.tintColor = .tertiaryLabel
        chevronView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(sectionLabel)
        addSubview(cardView)
        [iconView, mainLabel, subtitleLabel, chevronView].forEach(cardView.addSubview)

        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: topAnchor),
            sectionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),

            cardView.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            chevronView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            chevronView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 16),

            mainLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            mainLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            mainLabel.trailingAnchor.constraint(equalTo: chevronView.leadingAnchor, constant: -8),

            subtitleLabel.topAnchor.constraint(equalTo: mainLabel.bottomAnchor, constant: 3),
            subtitleLabel.leadingAnchor.constraint(equalTo: mainLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: mainLabel.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14)
        ])

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(mainText: String, subtitle: String?) {
        mainLabel.text = mainText
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle == nil
    }

    @objc private func handleTap() {
        cardView.layer.borderColor = UIColor.appBlue.cgColor
        onTap?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.cardView.layer.borderColor = UIColor.separator.cgColor
        }
    }
}

final class LabeledNumberField: UIView {
    private let sectionLabel = UILabel()
    private let cardView = UIView()
    private let minusButton = UIButton(type: .system)
    private let plusButton = UIButton(type: .system)
    private let quantityLabel = UILabel()
    private let subtitleLabel = UILabel()

    var onValueChanged: ((Int) -> Void)?
    var value: Int = 40 { didSet { quantityLabel.text = "\(value)" } }
    var minValue = 1
    var maxValue = 99999

    init(sectionTitle: String, subtitle: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        sectionLabel.text = sectionTitle
        sectionLabel.font = .sfRounded(size: 11, weight: .semibold)
        sectionLabel.textColor = .systemGray
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false

        cardView.backgroundColor = .appCard
        cardView.layer.cornerRadius = 12
        cardView.applyCardShadow()
        cardView.translatesAutoresizingMaskIntoConstraints = false

        minusButton.setTitle("−", for: .normal)
        minusButton.titleLabel?.font = .sfRounded(size: 20, weight: .bold)
        minusButton.setTitleColor(.appBlue, for: .normal)
        minusButton.backgroundColor = .appBlue.withAlphaComponent(0.1)
        minusButton.layer.cornerRadius = 16
        minusButton.translatesAutoresizingMaskIntoConstraints = false

        plusButton.setTitle("+", for: .normal)
        plusButton.titleLabel?.font = .sfRounded(size: 20, weight: .bold)
        plusButton.setTitleColor(.white, for: .normal)
        plusButton.backgroundColor = .appBlue
        plusButton.layer.cornerRadius = 16
        plusButton.translatesAutoresizingMaskIntoConstraints = false

        quantityLabel.font = .sfRounded(size: 22, weight: .bold)
        quantityLabel.textAlignment = .center
        quantityLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.text = subtitle
        subtitleLabel.font = .sfRounded(size: 12, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(sectionLabel)
        addSubview(cardView)
        [minusButton, plusButton, quantityLabel, subtitleLabel].forEach(cardView.addSubview)

        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: topAnchor),
            sectionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),

            cardView.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor),

            minusButton.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            minusButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            minusButton.widthAnchor.constraint(equalToConstant: 32),
            minusButton.heightAnchor.constraint(equalToConstant: 32),

            plusButton.topAnchor.constraint(equalTo: minusButton.topAnchor),
            plusButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            plusButton.widthAnchor.constraint(equalToConstant: 32),
            plusButton.heightAnchor.constraint(equalToConstant: 32),

            quantityLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            quantityLabel.centerYAnchor.constraint(equalTo: minusButton.centerYAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: quantityLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14)
        ])

        minusButton.addTarget(self, action: #selector(decrement), for: .touchUpInside)
        plusButton.addTarget(self, action: #selector(increment), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func decrement() {
        guard value > minValue else { return }
        value -= 1
        onValueChanged?(value)
    }

    @objc private func increment() {
        guard value < maxValue else { return }
        value += 1
        onValueChanged?(value)
    }
}

final class PaymentToggleControl: UIView {
    private let stackView = UIStackView()
    private let cashButton = UIButton(type: .system)
    private let creditButton = UIButton(type: .system)
    var onToggle: ((String) -> Void)?
    private var selectedType: String = "cash"

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        [cashButton, creditButton].forEach {
            $0.layer.cornerRadius = 22
            $0.titleLabel?.font = .sfRounded(size: 15, weight: .semibold)
            stackView.addArrangedSubview($0)
        }
        cashButton.setTitle("Efectivo", for: .normal)
        creditButton.setTitle("Crédito", for: .normal)
        cashButton.addTarget(self, action: #selector(selectCash), for: .touchUpInside)
        creditButton.addTarget(self, action: #selector(selectCredit), for: .touchUpInside)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func setSelected(type: String) {
        selectedType = type
        let isCash = type == "cash"
        style(button: cashButton, selected: isCash)
        style(button: creditButton, selected: !isCash)
    }

    private func style(button: UIButton, selected: Bool) {
        button.backgroundColor = selected ? .appBlue : UIColor(hex: "#F3F4F6")
        button.setTitleColor(selected ? .white : .secondaryLabel, for: .normal)
        button.layer.shadowOpacity = selected ? 0.25 : 0
        button.layer.shadowRadius = selected ? 6 : 0
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowColor = UIColor.appBlue.cgColor
    }

    @objc private func selectCash() {
        guard selectedType != "cash" else { return }
        UIView.animate(withDuration: 0.2) {
            self.setSelected(type: "cash")
        }
        onToggle?("cash")
    }

    @objc private func selectCredit() {
        guard selectedType != "credit" else { return }
        UIView.animate(withDuration: 0.2) {
            self.setSelected(type: "credit")
        }
        onToggle?("credit")
    }
}

final class StockInsightCardView: UIView {
    private let container = UIView()
    private let dotView = UIView()
    private let availableLabel = UILabel()
    private let warehouseLabel = UILabel()
    private let remainingLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor(hex: "#F0FDF4")
        container.layer.cornerRadius = 14
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor(hex: "#BBF7D0").cgColor
        addSubview(container)

        dotView.translatesAutoresizingMaskIntoConstraints = false
        dotView.backgroundColor = .appGreen
        dotView.layer.cornerRadius = 4

        availableLabel.font = .sfRounded(size: 14, weight: .bold)
        availableLabel.textColor = .appGreen
        availableLabel.translatesAutoresizingMaskIntoConstraints = false

        warehouseLabel.font = .sfRounded(size: 12, weight: .regular)
        warehouseLabel.textColor = .secondaryLabel
        warehouseLabel.translatesAutoresizingMaskIntoConstraints = false

        remainingLabel.font = .sfRounded(size: 12, weight: .semibold)
        remainingLabel.textColor = UIColor(hex: "#64748B")
        remainingLabel.translatesAutoresizingMaskIntoConstraints = false

        let leftStack = UIStackView(arrangedSubviews: [availableLabel, warehouseLabel])
        leftStack.axis = .horizontal
        leftStack.spacing = 6
        leftStack.alignment = .center
        leftStack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(dotView)
        container.addSubview(leftStack)
        container.addSubview(remainingLabel)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),

            dotView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            dotView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dotView.widthAnchor.constraint(equalToConstant: 8),
            dotView.heightAnchor.constraint(equalToConstant: 8),

            leftStack.leadingAnchor.constraint(equalTo: dotView.trailingAnchor, constant: 10),
            leftStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            remainingLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leftStack.trailingAnchor, constant: 12),
            remainingLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            remainingLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(availableText: String, warehouseText: String, remainingText: String) {
        availableLabel.text = availableText
        warehouseLabel.text = "· \(warehouseText)"
        remainingLabel.text = remainingText
    }
}

final class SaleImpactCardView: UIView {
    private let titleLabel = UILabel()
    private let chipsStack = UIStackView()
    private let warehouseChip = ImpactChipView()
    private let treasuryChip = ImpactChipView()
    private let receivableChip = ImpactChipView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .appCard
        layer.cornerRadius = 20
        layer.borderWidth = 1
        layer.borderColor = UIColor(hex: "#E5E7EB").cgColor

        titleLabel.text = "AFECTARÁ A"
        titleLabel.font = .sfRounded(size: 12, weight: .bold)
        titleLabel.textColor = UIColor(hex: "#94A3B8")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        chipsStack.axis = .horizontal
        chipsStack.spacing = 10
        chipsStack.alignment = .leading
        chipsStack.distribution = .fillProportionally
        chipsStack.translatesAutoresizingMaskIntoConstraints = false

        [warehouseChip, treasuryChip, receivableChip].forEach { chipsStack.addArrangedSubview($0) }
        warehouseChip.configure(icon: "📦", text: "", backgroundColor: UIColor(hex: "#FEE2E2"), textColor: .appRed)
        treasuryChip.configure(icon: "💰", text: "", backgroundColor: UIColor(hex: "#DCFCE7"), textColor: UIColor(hex: "#15803D"))
        receivableChip.configure(icon: "📋", text: "", backgroundColor: UIColor(hex: "#FEF3C7"), textColor: UIColor(hex: "#B45309"))

        addSubview(titleLabel)
        addSubview(chipsStack)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            chipsStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            chipsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            chipsStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            chipsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(quantityText: String, treasuryText: String, receivableText: String, showsReceivable: Bool) {
        warehouseChip.text = quantityText
        treasuryChip.text = treasuryText
        receivableChip.text = receivableText
        receivableChip.isHidden = !showsReceivable
    }
}

final class ImpactChipView: UIView {
    private let label = UILabel()
    private var icon: String = ""

    var text: String = "" {
        didSet { label.text = icon.isEmpty ? text : "\(icon) \(text)" }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 18

        label.font = .sfRounded(size: 13, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(icon: String, text: String, backgroundColor: UIColor, textColor: UIColor) {
        self.icon = icon
        self.text = text
        self.backgroundColor = backgroundColor
        label.textColor = textColor
    }
}

final class CreditSectionView: UIView {
    private let installmentsLabel = UILabel()
    private let installmentsValueLabel = UILabel()
    private let installmentsMinusButton = UIButton(type: .system)
    private let installmentsPlusButton = UIButton(type: .system)
    private let perInstallmentValueLabel = UILabel()
    private let dueDateButton = UIButton(type: .system)
    private let statusContainer = UIView()
    private let clientNameLabel = UILabel()
    private let creditTitleLabel = UILabel()
    private let progressContainer = UIView()
    private let progressFill = UIView()
    private let progressLabel = UILabel()
    private var statusBadge: NewSaleStatusBadgeView?
    private var progressWidthConstraint: NSLayoutConstraint?
    var onInstallmentsChanged: ((Int) -> Void)?
    var onDueDateTapped: (() -> Void)?
    private var installments = 3

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor(hex: "#EFF6FF")
        layer.cornerRadius = 14
        layer.borderWidth = 1
        layer.borderColor = UIColor(hex: "#BFDBFE").cgColor

        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        let row1 = makeKeyValueRow(title: "Cuotas", trailingView: makeInstallmentStepper())
        let row2 = makeKeyValueRow(title: "Por cuota", trailingView: perInstallmentValueLabel)
        let row3 = makeKeyValueRow(title: "Primera cuota", trailingView: dueDateButton)

        perInstallmentValueLabel.font = .sfRounded(size: 16, weight: .semibold)
        perInstallmentValueLabel.textColor = .appBlue
        dueDateButton.titleLabel?.font = .sfRounded(size: 15, weight: .regular)
        dueDateButton.setTitleColor(.appBlue, for: .normal)
        dueDateButton.addTarget(self, action: #selector(dueDateTapped), for: .touchUpInside)

        let divider1 = makeDivider()
        let divider2 = makeDivider()
        let divider3 = makeDivider()

        let statusRow = UIStackView()
        statusRow.axis = .horizontal
        statusRow.spacing = 8
        statusRow.alignment = .center
        statusContainer.translatesAutoresizingMaskIntoConstraints = false
        clientNameLabel.font = .sfRounded(size: 13, weight: .regular)
        clientNameLabel.textColor = .secondaryLabel
        clientNameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusRow.addArrangedSubview(statusContainer)
        statusRow.addArrangedSubview(clientNameLabel)
        statusRow.addArrangedSubview(UIView())

        creditTitleLabel.text = "Disponibilidad de crédito"
        creditTitleLabel.font = .sfRounded(size: 13, weight: .regular)
        creditTitleLabel.textColor = .secondaryLabel

        progressContainer.backgroundColor = UIColor(hex: "#FED7AA")
        progressContainer.layer.cornerRadius = 4
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        progressFill.backgroundColor = .appOrange
        progressFill.layer.cornerRadius = 4
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.addSubview(progressFill)

        progressLabel.font = .sfRounded(size: 12, weight: .regular)
        progressLabel.textColor = .secondaryLabel
        progressLabel.numberOfLines = 0

        [row1, divider1, row2, divider2, row3, divider3, statusRow, creditTitleLabel, progressContainer, progressLabel].forEach(content.addArrangedSubview)

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            progressContainer.heightAnchor.constraint(equalToConstant: 8)
        ])

        progressWidthConstraint = progressFill.widthAnchor.constraint(equalToConstant: 0)
        progressWidthConstraint?.isActive = true
        NSLayoutConstraint.activate([
            progressFill.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(
        installments: Int,
        perInstallmentText: String,
        dueDateText: String,
        statusText: String,
        status: String,
        clientName: String,
        creditUsageText: String,
        progress: CGFloat
    ) {
        self.installments = installments
        installmentsValueLabel.text = "\(installments)"
        perInstallmentValueLabel.text = perInstallmentText
        dueDateButton.setTitle(dueDateText, for: .normal)
        clientNameLabel.text = clientName
        progressLabel.text = creditUsageText

        statusBadge?.removeFromSuperview()
        let badge = NewSaleStatusBadgeView(text: statusText, status: status)
        badge.translatesAutoresizingMaskIntoConstraints = false
        statusContainer.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: statusContainer.topAnchor),
            badge.leadingAnchor.constraint(equalTo: statusContainer.leadingAnchor),
            badge.trailingAnchor.constraint(equalTo: statusContainer.trailingAnchor),
            badge.bottomAnchor.constraint(equalTo: statusContainer.bottomAnchor)
        ])
        statusBadge = badge

        layoutIfNeeded()
        progressWidthConstraint?.constant = max(0, min(bounds.width - 32, (bounds.width - 32) * progress))
        UIView.animate(withDuration: 0.25) {
            self.layoutIfNeeded()
        }
    }

    private func makeInstallmentStepper() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center

        installmentsMinusButton.setTitle("−", for: .normal)
        installmentsMinusButton.backgroundColor = UIColor(hex: "#E5E7EB")
        installmentsMinusButton.setTitleColor(.label, for: .normal)
        installmentsMinusButton.layer.cornerRadius = 16
        installmentsMinusButton.titleLabel?.font = .sfRounded(size: 18, weight: .bold)
        installmentsMinusButton.translatesAutoresizingMaskIntoConstraints = false
        installmentsMinusButton.widthAnchor.constraint(equalToConstant: 32).isActive = true
        installmentsMinusButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
        installmentsMinusButton.addTarget(self, action: #selector(decrementInstallments), for: .touchUpInside)

        installmentsValueLabel.font = .sfRounded(size: 18, weight: .bold)

        installmentsPlusButton.setTitle("+", for: .normal)
        installmentsPlusButton.backgroundColor = .appBlue
        installmentsPlusButton.setTitleColor(.white, for: .normal)
        installmentsPlusButton.layer.cornerRadius = 16
        installmentsPlusButton.titleLabel?.font = .sfRounded(size: 18, weight: .bold)
        installmentsPlusButton.translatesAutoresizingMaskIntoConstraints = false
        installmentsPlusButton.widthAnchor.constraint(equalToConstant: 32).isActive = true
        installmentsPlusButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
        installmentsPlusButton.addTarget(self, action: #selector(incrementInstallments), for: .touchUpInside)

        [installmentsMinusButton, installmentsValueLabel, installmentsPlusButton].forEach(stack.addArrangedSubview)
        return stack
    }

    private func makeKeyValueRow(title: String, trailingView: UIView) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .sfRounded(size: 15, weight: .regular)
        titleLabel.textColor = title == "Cuotas" ? .label : .secondaryLabel
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(UIView())
        row.addArrangedSubview(trailingView)
        return row
    }

    private func makeDivider() -> UIView {
        let view = UIView()
        view.backgroundColor = .separator
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return view
    }

    @objc private func decrementInstallments() {
        guard installments > 1 else { return }
        installments -= 1
        onInstallmentsChanged?(installments)
    }

    @objc private func incrementInstallments() {
        guard installments < 12 else { return }
        installments += 1
        onInstallmentsChanged?(installments)
    }

    @objc private func dueDateTapped() {
        onDueDateTapped?()
    }
}

final class DatePickerSheetViewController: UIViewController {
    private let selectedDate: Date
    private let onDateSelected: (Date) -> Void
    private let picker = UIDatePicker()

    init(selectedDate: Date, onDateSelected: @escaping (Date) -> Void) {
        self.selectedDate = selectedDate
        self.onDateSelected = onDateSelected
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .inline
        picker.date = selectedDate
        picker.translatesAutoresizingMaskIntoConstraints = false
        let button = UIButton(type: .system)
        button.setTitle("Aplicar", for: .normal)
        button.titleLabel?.font = .sfRounded(size: 16, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
        view.addSubview(picker)
        view.addSubview(button)

        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            picker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            picker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            button.topAnchor.constraint(equalTo: picker.bottomAnchor, constant: 16),
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    @objc private func applyTapped() {
        onDateSelected(picker.date)
        dismiss(animated: true)
    }
}

fileprivate extension UIColor {
    static let appBlue = UIColor(hex: "#3B82F6")
    static let appGreen = UIColor(hex: "#22C55E")
    static let appRed = UIColor(hex: "#EF4444")
    static let appOrange = UIColor(hex: "#F59E0B")
    static let appBackground = UIColor(hex: "#F4F6FA")
    static let appCard = UIColor.white

    convenience init(hex: String) {
        let hexSan = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var int: UInt64 = 0
        Scanner(string: hexSan).scanHexInt64(&int)
        let r = CGFloat((int & 0xFF0000) >> 16) / 255
        let g = CGFloat((int & 0x00FF00) >> 8) / 255
        let b = CGFloat(int & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

fileprivate extension UIFont {
    static func sfRounded(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        if let descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return UIFont.systemFont(ofSize: size, weight: weight)
    }
}

fileprivate extension UIView {
    func applyCardShadow(
        color: UIColor = .black,
        opacity: Float = 0.06,
        offset: CGSize = CGSize(width: 0, height: 2),
        radius: CGFloat = 8
    ) {
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = opacity
        layer.shadowOffset = offset
        layer.shadowRadius = radius
        layer.masksToBounds = false
    }
}

private final class NewSaleStatusBadgeView: UIView {
    private let label = UILabel()

    init(text: String, status: String) {
        super.init(frame: .zero)
        let color: UIColor
        switch status {
        case "activo": color = .appGreen
        case "enRiesgo": color = .appOrange
        case "vencido": color = .appRed
        default: color = .systemGray
        }
        backgroundColor = color
        layer.cornerRadius = 10
        label.text = text
        label.font = .sfRounded(size: 11, weight: .semibold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}
