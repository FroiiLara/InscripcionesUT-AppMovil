import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource, XFile;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';
import '../services/api_service.dart';
import 'inscripcion_screen.dart'
    show UTSCStepper, UTSCSeccion, UTSCCampo, UTSCFilePicker, UTSCResumen;

class ReinscripcionScreen extends StatefulWidget {
  const ReinscripcionScreen({super.key});
  @override
  State<ReinscripcionScreen> createState() => _ReinscripcionScreenState();
}

class _ReinscripcionScreenState extends State<ReinscripcionScreen> {
  int  _paso    = 0;
  bool _enviando = false;

  // Paso 1
  final _matriculaCtrl = TextEditingController();
  final _nombreCtrl    = TextEditingController();
  String? _carrera;

  // Paso 2
  String? _cuatrimestre;
  bool    _esEstadia = false;
  final Set<String> _materias = {};

  // Paso 3
  final _refCtrl = TextEditingController();
  DateTime?     _fechaPago;
  XFile? _comprobante;

  static const _carreras = [
    ('ITID', 'Ing. en Tecnologías de la Información e Innovación Digital'),
    ('II',   'Ingeniería Industrial'),
    ('IMI',  'Ing. en Mantenimiento Industrial'),
    ('IMT',  'Ingeniería Mecatrónica'),
    ('IE',   'Ingeniería en Electromovilidad'),
    ('LNM',  'Lic. en Negocios y Mercadotecnia'),
    ('LLI',  'Lic. en Educación (Enseñanza del Idioma Inglés)'),
  ];

  static const _cuatrimestres = ['2025-A','2025-B','2025-C','2026-A','2026-B','2026-C'];

  static const _materiasPorCarrera = <String, List<String>>{
    'ITID': ['Fundamentos de Programación','Bases de Datos','Redes de Computadoras','Desarrollo Web','Sistemas Operativos','Inteligencia Artificial','Seguridad Informática','Inglés Técnico'],
    'II':   ['Investigación de Operaciones','Control de Calidad','Ergonomía','Procesos de Manufactura','Logística','Estadística Industrial','Administración de Proyectos'],
    'IMI':  ['Mantenimiento Preventivo','Hidráulica y Neumática','Electricidad Industrial','Instrumentación','Seguridad Industrial','Gestión de Mantenimiento'],
    'IMT':  ['Robótica','Electrónica Digital','Control Automático','Sensores y Actuadores','Programación de PLCs','Sistemas Embebidos'],
    'IE':   ['Motores Eléctricos','Baterías y Almacenamiento','Electrónica de Potencia','Infraestructura de Carga','Normativa Vehicular'],
    'LNM':  ['Marketing Digital','Administración Financiera','Comercio Electrónico','Ventas y Negociación','Investigación de Mercados'],
    'LLI':  ['Gramática Avanzada','Conversación Aplicada','Literatura en Inglés','Didáctica del Idioma','Inglés de Negocios'],
  };

  List<String> get _materiasDisp => _carrera != null ? (_materiasPorCarrera[_carrera] ?? []) : [];

  String get _nombreCarrera {
    for (final c in _carreras) { if (c.$1 == _carrera) return c.$2; }
    return '—';
  }

  @override
  void initState() {
    super.initState();
    _precargarDatos();
  }

  // La matrícula y el nombre vienen de la cuenta (el servidor exige que la matrícula
  // de la reinscripción sea la de la sesión).
  Future<void> _precargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      if (_matriculaCtrl.text.isEmpty) _matriculaCtrl.text = prefs.getString('matricula') ?? '';
      if (_nombreCtrl.text.isEmpty) _nombreCtrl.text = prefs.getString('usuario_nombre') ?? '';
    });
  }

  @override
  void dispose() {
    _matriculaCtrl.dispose(); _nombreCtrl.dispose(); _refCtrl.dispose();
    super.dispose();
  }

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: UTSCColors.error));

  bool _validarP1() {
    if (_matriculaCtrl.text.trim().isEmpty) { _err('Ingresa tu matrícula'); return false; }
    if (_nombreCtrl.text.trim().isEmpty) { _err('Ingresa tu nombre completo'); return false; }
    if (_carrera == null) { _err('Selecciona tu carrera'); return false; }
    return true;
  }

  bool _validarP2() {
    if (_cuatrimestre == null) { _err('Selecciona el cuatrimestre'); return false; }
    if (!_esEstadia && _materias.isEmpty) { _err('Selecciona al menos una materia'); return false; }
    return true;
  }

  bool _validarP3() {
    if (_refCtrl.text.trim().length < 3) { _err('Ingresa la referencia de pago (mínimo 3 caracteres)'); return false; }
    if (_fechaPago == null) { _err('Selecciona la fecha de pago'); return false; }
    if (_comprobante == null) { _err('Sube el comprobante de pago'); return false; }
    return true;
  }

  void _siguiente() {
    bool ok = false;
    if (_paso == 0) ok = _validarP1();
    if (_paso == 1) ok = _validarP2();
    if (_paso == 2) ok = _validarP3();
    if (ok) setState(() => _paso++);
  }

  static String _fechaIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _enviar() async {
    if (_enviando) return;
    if (!_validarP1() || !_validarP2() || !_validarP3()) return;
    setState(() => _enviando = true);

    // El servidor vuelve a validar todo; esto es solo comodidad para el alumno.
    final resultado = await ApiService.enviarReinscripcion(
      matricula: _matriculaCtrl.text.trim(),
      nombre: _nombreCtrl.text.trim(),
      carreraClave: _carrera!,
      cuatrimestre: _cuatrimestre!,
      esEstadia: _esEstadia,
      materias: _esEstadia ? <String>[] : _materias.toList(),
      referenciaPago: _refCtrl.text.trim(),
      fechaPago: _fechaIso(_fechaPago!),
      comprobante: _comprobante!,
    );
    if (!mounted) return;
    setState(() => _enviando = false);

    if (resultado['ok'] != true) {
      _err(resultado['mensaje']?.toString() ?? 'No se pudo enviar la reinscripción.');
      return;
    }
    final folio = resultado['folio']?.toString();
    if (mounted) {
      showDialog(
        context: context, barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.check_circle, color: UTSCColors.aprobada, size: 28),
            SizedBox(width: 8), Text('¡Solicitud enviada!'),
          ]),
          content: Text(folio != null
              ? 'Tu reinscripción fue recibida.\n\nFolio: $folio\n\nRecibirás un correo de confirmación.'
              : 'Tu reinscripción fue recibida. Recibirás un correo con tu folio REINSC-.'),
          actions: [ElevatedButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text('Aceptar'),
          )],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UTSCColors.fondo,
      appBar: AppBar(
        title: const Text('Trámite de Reinscripción'),
        backgroundColor: UTSCColors.verde, foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          UTSCStepper(pasoActual: _paso),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: [_buildP1(), _buildP2(), _buildP3(), _buildP4()][_paso],
          )),
          _buildNav(),
        ],
      ),
    );
  }

  Widget _buildP1() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const UTSCSeccion(icono: Icons.badge, texto: 'Datos del Alumno'),
      const SizedBox(height: 16),
      UTSCCampo(label: 'Matrícula *', child: TextFormField(
        controller: _matriculaCtrl, keyboardType: TextInputType.number, maxLength: 10,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(hintText: 'Ej. 202312345',
            prefixIcon: Icon(Icons.badge_outlined, color: UTSCColors.verde), counterText: ''),
      )),
      const SizedBox(height: 14),
      UTSCCampo(label: 'Nombre Completo *', child: TextFormField(
        controller: _nombreCtrl, textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Ej. Juan Carlos Pérez Martínez',
            prefixIcon: Icon(Icons.person_outline, color: UTSCColors.verde)),
      )),
      const SizedBox(height: 14),
      UTSCCampo(label: 'Carrera *', child: DropdownButtonFormField<String>(
        value: _carrera,
        decoration: const InputDecoration(prefixIcon: Icon(Icons.school_outlined, color: UTSCColors.verde)),
        hint: const Text('-- Selecciona tu carrera --'),
        items: _carreras.map((c) => DropdownMenuItem(value: c.$1,
            child: Text(c.$2, style: const TextStyle(fontSize: 13)))).toList(),
        onChanged: (v) => setState(() { _carrera = v; _materias.clear(); }),
      )),
    ],
  );

  Widget _buildP2() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const UTSCSeccion(icono: Icons.calendar_month, texto: 'Cuatrimestre y Materias'),
      const SizedBox(height: 16),
      UTSCCampo(label: 'Cuatrimestre *', child: DropdownButtonFormField<String>(
        value: _cuatrimestre,
        decoration: const InputDecoration(prefixIcon: Icon(Icons.date_range_outlined, color: UTSCColors.verde)),
        hint: const Text('-- Selecciona el cuatrimestre --'),
        items: _cuatrimestres.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => setState(() => _cuatrimestre = v),
      )),
      const SizedBox(height: 16),
      // Toggle estadía
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _esEstadia ? UTSCColors.verdeClaro : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _esEstadia ? UTSCColors.verde : UTSCColors.borde),
        ),
        child: Row(
          children: [
            const Icon(Icons.work_outline, color: UTSCColors.verde),
            const SizedBox(width: 12),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Es estadía', style: TextStyle(fontWeight: FontWeight.w600, color: UTSCColors.verde)),
                Text('Activa si realizas estadía en lugar de materias',
                    style: TextStyle(fontSize: 12, color: UTSCColors.textoGris)),
              ],
            )),
            Switch(value: _esEstadia, activeColor: UTSCColors.verde,
                onChanged: (v) => setState(() { _esEstadia = v; if (v) _materias.clear(); })),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (!_esEstadia) ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Materias a Cursar *',
                style: TextStyle(fontWeight: FontWeight.w600, color: UTSCColors.texto)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: UTSCColors.verde.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('${_materias.length} seleccionadas',
                  style: const TextStyle(fontSize: 12, color: UTSCColors.verde, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_materiasDisp.isEmpty)
          const Text('Selecciona una carrera en el paso anterior.',
              style: TextStyle(color: UTSCColors.textoGris))
        else
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(), shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, childAspectRatio: 2.4, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: _materiasDisp.length,
            itemBuilder: (_, i) {
              final m = _materiasDisp[i];
              final sel = _materias.contains(m);
              return GestureDetector(
                onTap: () => setState(() => sel ? _materias.remove(m) : _materias.add(m)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? UTSCColors.aprobadaFondo : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? UTSCColors.aprobada : UTSCColors.borde, width: sel ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Icon(sel ? Icons.check_circle : Icons.circle_outlined, size: 18,
                          color: sel ? UTSCColors.aprobada : UTSCColors.textoGris),
                      const SizedBox(width: 6),
                      Expanded(child: Text(m,
                          style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                              color: sel ? UTSCColors.aprobada : UTSCColors.texto),
                          maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
      if (_esEstadia)
        Container(
          padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(color: UTSCColors.verdeClaro, borderRadius: BorderRadius.circular(8)),
          child: const Row(children: [
            Icon(Icons.info_outline, color: UTSCColors.verde, size: 18), SizedBox(width: 8),
            Expanded(child: Text('Modalidad estadía. Solo necesitas el comprobante de pago.',
                style: TextStyle(color: UTSCColors.verde, fontSize: 13))),
          ]),
        ),
    ],
  );

  Widget _buildP3() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const UTSCSeccion(icono: Icons.receipt_long, texto: 'Comprobante de Pago'),
      const SizedBox(height: 16),
      UTSCCampo(label: 'Número de Referencia *', child: TextFormField(
        controller: _refCtrl, keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(hintText: 'Número de referencia bancaria',
            prefixIcon: Icon(Icons.tag, color: UTSCColors.verde)),
      )),
      const SizedBox(height: 14),
      UTSCCampo(label: 'Fecha de Pago *', child: InkWell(
        onTap: () async {
          final p = await showDatePicker(context: context, initialDate: DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now(),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: UTSCColors.verde)),
                child: child!));
          if (p != null) setState(() => _fechaPago = p);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: UTSCColors.borde), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.event_available_outlined, color: UTSCColors.verde),
            const SizedBox(width: 12),
            Text(_fechaPago != null
                ? '${_fechaPago!.day.toString().padLeft(2,'0')}/${_fechaPago!.month.toString().padLeft(2,'0')}/${_fechaPago!.year}'
                : 'Seleccionar fecha de pago',
                style: TextStyle(color: _fechaPago != null ? UTSCColors.texto : UTSCColors.textoGris, fontSize: 15)),
          ]),
        ),
      )),
      const SizedBox(height: 14),
      UTSCFilePicker(
        label: 'Comprobante de Pago * (JPG o PNG)', archivo: _comprobante,
        onSeleccionar: () async {
          final picker = ImagePicker();
          // Se limita el tamaño: el servidor rechaza documentos de más de 5 MB.
          final f = await picker.pickImage(
              source: ImageSource.gallery, maxWidth: 2000, maxHeight: 2000, imageQuality: 85);
          if (f != null) setState(() => _comprobante = f);
        },
      ),
    ],
  );

  Widget _buildP4() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const UTSCSeccion(icono: Icons.check_circle, texto: 'Confirmación'),
      const SizedBox(height: 16),
      UTSCResumen(titulo: 'Datos del Alumno', items: [
        ('Matrícula',    _matriculaCtrl.text),
        ('Nombre',       _nombreCtrl.text),
        ('Carrera',      _nombreCarrera),
        ('Cuatrimestre', _cuatrimestre ?? '—'),
        ('Modalidad',    _esEstadia ? 'Estadía' : 'Materias'),
      ]),
      const SizedBox(height: 12),
      if (!_esEstadia && _materias.isNotEmpty) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Materias seleccionadas:', style: TextStyle(fontWeight: FontWeight.bold, color: UTSCColors.verde, fontSize: 14)),
              const Divider(height: 12),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: _materias.map((m) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: UTSCColors.verde, borderRadius: BorderRadius.circular(20)),
                  child: Text(m, style: const TextStyle(color: Colors.white, fontSize: 11)),
                )).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
      UTSCResumen(titulo: 'Datos de Pago', items: [
        ('Referencia', _refCtrl.text),
        ('Fecha pago', _fechaPago != null ? '${_fechaPago!.day}/${_fechaPago!.month}/${_fechaPago!.year}' : '—'),
        ('Comprobante', _comprobante?.name ?? '—'),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: UTSCColors.verdeClaro, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: UTSCColors.verde.withOpacity(0.4))),
        child: const Row(children: [
          Icon(Icons.email_outlined, color: UTSCColors.verde, size: 18), SizedBox(width: 8),
          Expanded(child: Text('Al enviar, recibirás un correo con tu folio REINSC-.',
              style: TextStyle(color: UTSCColors.verde, fontSize: 13))),
        ]),
      ),
    ],
  );

  Widget _buildNav() {
    final esUltimo = _paso == 3;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -3))]),
      child: Row(
        children: [
          if (_paso > 0) ...[
            Expanded(child: OutlinedButton.icon(
              onPressed: () => setState(() => _paso--),
              icon: const Icon(Icons.arrow_back, color: UTSCColors.textoGris),
              label: const Text('Anterior', style: TextStyle(color: UTSCColors.textoGris)),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48),
                  side: const BorderSide(color: UTSCColors.borde),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            )),
            const SizedBox(width: 12),
          ],
          Expanded(flex: 2, child: ElevatedButton.icon(
            onPressed: _enviando ? null : (esUltimo ? _enviar : _siguiente),
            icon: _enviando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Icon(esUltimo ? Icons.send : Icons.arrow_forward),
            label: Text(esUltimo ? 'Enviar Solicitud' : 'Siguiente'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48),
                backgroundColor: esUltimo ? UTSCColors.verde : UTSCColors.naranja,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          )),
        ],
      ),
    );
  }
}
