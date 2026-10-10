import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MiAplicacion());
}

class Lugar {
  final String nombre;
  final double lat;
  final double lon;

  const Lugar(this.nombre, this.lat, this.lon);
}

class MiAplicacion extends StatelessWidget {
  const MiAplicacion({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Calidad del aire',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const Inicio(),
    );
  }
}

class Inicio extends StatefulWidget {
  const Inicio({super.key});

  @override
  State<Inicio> createState() => _InicioEstado();
}

class _InicioEstado extends State<Inicio> {
  final claveFormulario = GlobalKey<FormState>();
  final horasTexto = TextEditingController();

  final List<Lugar> lugares = const [
    Lugar('Medellín', 6.2442, -75.5812),
    Lugar('Bogotá', 4.7110, -74.0721),
    Lugar('Cali', 3.4516, -76.5320),
    Lugar('Barranquilla', 10.9639, -74.7964),
    Lugar('Cartagena', 10.3910, -75.4794),
  ];

  Lugar? lugarElegido;
  DateTime fecha = DateTime.now();

  bool esperando = false;
  double? promedio;
  double? indice;
  String? riesgo;
  String? mensajeError;

  @override
  void initState() {
    super.initState();
    lugarElegido = lugares[0];
  }

  String mostrarFecha(DateTime dia) {
    final mes = dia.month.toString().padLeft(2, '0');
    final numeroDia = dia.day.toString().padLeft(2, '0');

    return '${dia.year}-$mes-$numeroDia';
  }

  Future<void> elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: fecha,
      firstDate: DateTime(2022),
      lastDate: DateTime(2030),
    );

    if (elegida != null) {
      setState(() {
        fecha = elegida;
        promedio = null;
        indice = null;
        riesgo = null;
        mensajeError = null;
      });
    }
  }

  Future<void> buscarDatos() async {
    if (!claveFormulario.currentState!.validate()) {
      return;
    }

    setState(() {
      esperando = true;
      mensajeError = null;
      promedio = null;
      indice = null;
      riesgo = null;
    });

    try {
      final lugar = lugarElegido!;
      final dia = mostrarFecha(fecha);

      final direccion = Uri.https(
        'air-quality-api.open-meteo.com',
        '/v1/air-quality',
        {
          'latitude': lugar.lat.toString(),
          'longitude': lugar.lon.toString(),
          'hourly': 'pm2_5',
          'start_date': dia,
          'end_date': dia,
          'timezone': 'America/Bogota',
        },
      );

      final respuesta = await http.get(direccion);

      if (respuesta.statusCode != 200) {
        throw Exception(
          'Error al consultar la API: ${respuesta.statusCode}',
        );
      }

      final datos = jsonDecode(respuesta.body)
          as Map<String, dynamic>;

      final datosHoras = datos['hourly'];

      if (datosHoras == null || datosHoras['pm2_5'] == null) {
        throw Exception('No se encontraron datos de PM2.5.');
      }

      final List valores = datosHoras['pm2_5'];

      final List<double> mediciones = valores
          .where((valor) => valor != null)
          .map<double>((valor) => (valor as num).toDouble())
          .toList();

      if (mediciones.isEmpty) {
        throw Exception(
          'No hay mediciones disponibles para ese día.',
        );
      }

      final suma = mediciones.reduce((a, b) => a + b);
      final resultadoPromedio = suma / mediciones.length;

      final tiempo = double.parse(
        horasTexto.text.replaceAll(',', '.'),
      );

      final resultadoIndice = resultadoPromedio * tiempo;

      String resultadoRiesgo;

      if (resultadoIndice < 100) {
        resultadoRiesgo = 'Bajo';
      } else if (resultadoIndice <= 200) {
        resultadoRiesgo = 'Moderado';
      } else {
        resultadoRiesgo = 'Alto';
      }

      if (!mounted) return;

      setState(() {
        promedio = resultadoPromedio;
        indice = resultadoIndice;
        riesgo = resultadoRiesgo;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        mensajeError = 'No fue posible consultar los datos: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          esperando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    horasTexto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calidad del aire'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: claveFormulario,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.air,
                size: 75,
                color: Colors.teal,
              ),
              const SizedBox(height: 12),
              const Text(
                'Índice de exposición diaria',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              DropdownButtonFormField<Lugar>(
                initialValue: lugarElegido,
                decoration: const InputDecoration(
                  labelText: 'Selecciona una ciudad',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
                items: lugares.map((lugar) {
                  return DropdownMenuItem<Lugar>(
                    value: lugar,
                    child: Text(lugar.nombre),
                  );
                }).toList(),
                onChanged: (nuevoLugar) {
                  setState(() {
                    lugarElegido = nuevoLugar;
                    promedio = null;
                    indice = null;
                    riesgo = null;
                    mensajeError = null;
                  });
                },
              ),

              const SizedBox(height: 18),

              OutlinedButton.icon(
                onPressed: elegirFecha,
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  'Fecha: ${mostrarFecha(fecha)}',
                ),
              ),

              const SizedBox(height: 18),

              TextFormField(
                controller: horasTexto,
                keyboardType:
                    const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Horas al aire libre',
                  hintText: 'Ejemplo: 4',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.schedule),
                ),
                validator: (texto) {
                  final tiempo = double.tryParse(
                    (texto ?? '').replaceAll(',', '.'),
                  );

                  if (tiempo == null ||
                      !tiempo.isFinite ||
                      tiempo <= 0 ||
                      tiempo > 24) {
                    return 'Ingresa un valor mayor que 0 y hasta 24';
                  }

                  return null;
                },
                onChanged: (_) {
                  setState(() {
                    promedio = null;
                    indice = null;
                    riesgo = null;
                  });
                },
              ),

              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: esperando ? null : buscarDatos,
                icon: const Icon(Icons.search),
                label: const Text('Consultar calidad del aire'),
              ),

              if (esperando) ...[
                const SizedBox(height: 24),
                const Center(
                  child: CircularProgressIndicator(),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Consultando la API...',
                  textAlign: TextAlign.center,
                ),
              ],

              if (mensajeError != null) ...[
                const SizedBox(height: 20),
                Text(
                  mensajeError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],

              if (promedio != null && indice != null) ...[
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ciudad: ${lugarElegido!.nombre}',
                        ),
                        Text('Fecha: ${mostrarFecha(fecha)}'),
                        const Divider(height: 28),
                        const Text('Promedio diario de PM2.5'),
                        Text(
                          '${promedio!.toStringAsFixed(2)} µg/m³',
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Índice de exposición'),
                        Text(
                          indice!.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Nivel de riesgo: $riesgo',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: riesgo == 'Bajo'
                                ? Colors.green
                                : riesgo == 'Moderado'
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}