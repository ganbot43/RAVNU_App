import CoreData
import UIKit


class CajeroViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var lblNombreBienvenido: UILabel!
    
    @IBOutlet weak var tblCajero: UITableView!
    
    @IBOutlet weak var lblSaldoActual: UILabel!
    
    var nombreBienvenido: String?
        
        var misVentas: [LoginEntity] = []
        
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        
        override func viewDidLoad() {
            super.viewDidLoad()
              
            lblNombreBienvenido.text = "Bienvenido \(nombreBienvenido ?? "")!"
            
            tblCajero.dataSource = self
            tblCajero.delegate = self
            
            // Al cargar por primera vez, intentamos leer la BD
            cargarDatosDeBaseDeDatos()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            // Refrescamos cada vez que el cajero regrese de la pestaña "Ventas"
            cargarDatosDeBaseDeDatos()
        }
         
        func cargarDatosDeBaseDeDatos() {
            let solicitud: NSFetchRequest<LoginEntity> = LoginEntity.fetchRequest()
            
            do {
                misVentas = try context.fetch(solicitud)
                tblCajero.reloadData()
                
                // 2. LÓGICA DE SALDO REAL:
                // Si no hay nada en misVentas, mostrará 0.00
                // Si hay ventas, sumará los elementos.
                if misVentas.count > 0 {
                    // Aquí podrías sumar un atributo 'monto' si tu entidad lo tuviera.
                    // Por ahora, solo cuenta cuántos registros hay.
                    lblSaldoActual.text = "Saldo Actual: S/ \(misVentas.count).00"
                } else {
                    lblSaldoActual.text = "Saldo Actual: S/ 0.00"
                }
                
            } catch {
                print("Error al cargar de Core Data")
                lblSaldoActual.text = "Saldo Actual: S/ 0.00"
            }
        }

        // MARK: - Métodos de la Tabla
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return misVentas.count
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "celdaCajero", for: indexPath)
            
            let venta = misVentas[indexPath.row]
            // Mostramos el nombre del cajero o usuario que registró
            cell.textLabel?.text = "Venta: \(venta.usuario ?? "Registro")"
            cell.detailTextLabel?.text = "S/ 1.00" // Valor simbólico por cada registro
            
            return cell
        }

    
    @IBAction func btnSalir(_ sender: UIButton) {
        cerrarSesionUniversal()
    }
}


