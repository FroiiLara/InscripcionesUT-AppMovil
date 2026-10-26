import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/colors.dart';
import '../services/api_service.dart';

class InscripcionScreen extends StatefulWidget {
  const InscripcionScreen({super.key});
  @override
  State<InscripcionScreen> createState() => _InscripcionScreenState();
}

class _InscripcionScreenState extends State<InscripcionScreen> {
  int  _paso    = 0;
  bool _enviando = false;

  // Paso 1
  final _nombreCtrl   = TextEditingController();
  final _curpCtrl     = TextEditingController();
  final _telCtrl      = TextEditingController();
  DateTime? _fechaNac;
  XFile?    _foto;
  String?   _curpMsg;
  Color     _curpColor = UTSCColors.textoGris;
  // Privacidad: la CURP solo se envía al servicio externo (RENAPO) si el alumno lo autoriza.
  bool      _curpExterno = false;

  // Paso 2
  String? _carrera;
  final _contactoNombreCtrl = TextEditingController();
  final _contactoTelCtrl    = TextEditingController();

  // Paso 3
  XFile? _acta, _cert, _comprobante;

  static const _carreras = [
    ('ITID', 'Ing. en Tecnologías de la Información e Innovación Digital'),
    ('II',   'Ingeniería Industrial'),
    ('IMI',  'Ing. en Mantenimiento Industrial'),
    ('IMT',  'Ingeniería Mecatrónica'),
    ('IE',   'Ingeniería en Electromovilidad'),
    ('LNM',  'Lic. en Negocios y Mercadotecnia'),
    ('LLI',  'Lic. en Educación (Enseñanza del Idioma Inglés)'),
  ];

  @override
  void dispose() {
    _nombreCtrl.dispose(); _curpCtrl.dispose(); _telCtrl.dispose();
    _contactoNombreCtrl.dispose(); _contactoTelCtrl.dispose();
    super.dispose();
  }

  Future<void> _validarCurp(String curp) async {
    final regex = RegExp(r'^[A-Z]{4}[0-9]{6}[HM][A-Z]{2}[B-DF-HJ-NP-TV-Z]{3}[A-Z0-9]{2}$');
    if (curp.length < 18) { setState(() { _curpMsg = null; }); return; }
    if (!regex.hasMatch(curp)) {
      setState(() { _curpMsg = 'Formato de CURP inválido'; _curpColor = UTSCColors.error; });
      return;
    }
    if (!_curpExterno) {
      setState(() { _curpMsg = null; });
      return;
    }
    setState(() { _curpMsg = 'Verificando con RENAPO...'; _curpColor = UTSCColors.textoGris; });
    final data = await ApiService.validarCurp(curp);
    setState(() {
      if (data['valida'] == true) {
        _curpMsg = '✓ CURP válida — ${data['nombre'] ?? ''} ${data['paterno'] ?? ''}';
        _curpColor = UTSCColors.aprobada;
        if (_nombreCtrl.text.trim().isEmpty) {
          _nombreCtrl.text = '${data['nombre'] ?? ''} ${data['paterno'] ?? ''} ${data['materno'] ?? ''}'.trim();
        }
      } else if (data['valida'] == false) {
        _curpMsg = data['mensaje'] ?? 'CURP no encontrada';
        _curpColor = UTSCColors.error;
      } else {
        _curpMsg = '⚠ Servicio RENAPO no disponible. Puedes continuar.';
        _curpColor = UTSCColors.revision;
      }
    });
  }

  void _mostrarOpcionesFoto() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text('Seleccionar fotografía',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: UTSCColors.verde),
              title: const Text('Tomar foto con cámara'),
              onTap: () async {
                Navigator.pop(context);
                final f = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 800, imageQuality: 85);
                if (f != null) setState(() => _foto = f);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: UTSCColors.verde),
              title: const Text('Seleccionar de galería'),
              onTap: () async {
                Navigator.pop(context);
                final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
                if (f != null) setState(() => _foto = f);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<XFile?> _elegirArchivo() async {
    final picker = ImagePicker();
    // Se limita el tamaño: el servidor rechaza documentos de más de 5 MB.
    return await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 2000, maxHeight: 2000, imageQuality: 85);
  }

  // ── Edad mínima para inscribirse ──
  static const int _edadMinima = 18;
  static const int _edadMaxima = 100;

  static DateTime get _fechaMaxNac {
    final h = DateTime.now();
    return DateTime(h.year - _edadMinima, h.month, h.day);
  }

  static DateTime get _fechaMinNac {
    final h = DateTime.now();
    return DateTime(h.year - _edadMaxima, h.month, h.day);
  }

  static int _edadCumplida(DateTime nac) {
    final h = DateTime.now();
    var e = h.year - nac.year;
    if (h.month < nac.month || (h.month == nac.month && h.day < nac.day)) e--;
    return e;
  }

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: UTSCColors.error));

  bool _validarP1() {
    if (_nombreCtrl.text.trim().isEmpty) { _err('Ingresa tu nombre completo'); return false; }
    if (_curpCtrl.text.trim().length != 18) { _err('Ingresa una CURP válida'); return false; }
    if (_fechaNac == null) { _err('Selecciona tu fecha de nacimiento'); return false; }
    if (_edadCumplida(_fechaNac!) < _edadMinima) {
      _err('Debes tener al menos $_edadMinima años cumplidos para inscribirte'); return false;
    }
    if (_telCtrl.text.trim().length != 10) { _err('El teléfono debe tener 10 dígitos'); return false; }
    if (_foto == null) { _err('Agrega tu fotografía'); return false; }
    return true;
  }

  bool _validarP2() {
    if (_carrera == null) { _err('Selecciona una carrera'); return false; }
    if (_contactoNombreCtrl.text.trim().isEmpty) { _err('Ingresa el nombre del contacto de emergencia'); return false; }
    if (_contactoTelCtrl.text.trim().length != 10) { _err('El teléfono del contacto debe tener 10 dígitos'); return false; }
    return true;
  }

  bool _validarP3() {
    if (_acta == null) { _err('Sube tu acta de nacimiento'); return false; }
    if (_cert == null) { _err('Sube tu certificado de estudios'); return false; }
    if (_comprobante == null) { _err('Sube tu comprobante de pago'); return false; }
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

    // El servidor vuelve a validar TODO (edad, CURP, teléfono, archivos...): lo que se
    // revisa aquí es solo comodidad para el alumno.
    final resultado = await ApiService.enviarInscripcion(
      nombre: _nombreCtrl.text.trim(),
      curp: _curpCtrl.text.trim().toUpperCase(),
      fechaNacimiento: _fechaIso(_fechaNac!),
      telefono: _telCtrl.text.trim(),
      carrera: _carrera!,
      contactoNombre: _contactoNombreCtrl.text.trim(),
      contactoTel: _contactoTelCtrl.text.trim(),
      fotografia: _foto!,
      acta: _acta!,
      certificado: _cert!,
      comprobante: _comprobante!,
    );
    if (!mounted) return;
    setState(() => _enviando = false);

    if (resultado['ok'] != true) {
      _err(resultado['mensaje']?.toString() ?? 'No se pudo enviar la solicitud.');
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
              ? 'Tu solicitud fue recibida.\n\nFolio: $folio\n\nRecibirás un correo de confirmación.'
              : 'Tu solicitud fue recibida. Recibirás un correo con tu folio.'),
          actions: [ElevatedButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text('Aceptar'),
          )],
        ),
      );
    }
  }

  String get _nombreCarrera {
    for (final c in _carreras) { if (c.$1 == _carrera) return c.$2; }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UTSCColors.fondo,
      appBar: AppBar(
        title: const Text('Inscripción — Nuevo Ingreso'),
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
      const UTSCSeccion(icono: Icons.person, texto: 'Datos Personales'),
      const SizedBox(height: 16),
      UTSCCampo(label: 'Nombre Completo *', child: TextFormField(
        controller: _nombreCtrl, textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Ej. Juan Carlos Pérez Martínez',
            prefixIcon: Icon(Icons.person_outline, color: UTSCColors.verde)),
      )),
      const SizedBox(height: 14),
      UTSCCampo(label: 'CURP *', child: TextFormField(
        controller: _curpCtrl, maxLength: 18,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')), _UpperCase()],
        decoration: const InputDecoration(hintText: 'Ej. PEGJ990101HNLRZN01',
            prefixIcon: Icon(Icons.fingerprint, color: UTSCColors.verde), counterText: ''),
        onChanged: (v) { if (v.length == 18) _validarCurp(v); else setState(() => _curpMsg = null); },
      )),
      if (_curpMsg != null) ...[
        const SizedBox(height: 4),
        Text(_curpMsg!, style: TextStyle(fontSize: 12, color: _curpColor)),
      ],
      CheckboxListTile(
        value: _curpExterno,
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: UTSCColors.verde,
        title: const Text(
          'Opcional: autorizo enviar únicamente mi CURP a un servicio externo '
          '(consultacurp.com.mx) para comprobar que existe. Si no lo autorizo, '
          'solo se valida su formato y puedes continuar.',
          style: TextStyle(fontSize: 11.5, color: UTSCColors.textoGris),
        ),
        onChanged: (v) {
          setState(() => _curpExterno = v ?? false);
          final curp = _curpCtrl.text.trim().toUpperCase();
          if (_curpExterno && curp.length == 18) {
            _validarCurp(curp);
          } else {
            setState(() => _curpMsg = null);
          }
        },
      ),
      const SizedBox(height: 14),
      UTSCCampo(label: 'Fecha de Nacimiento *', child: InkWell(
        onTap: () async {
          final maxNac = _fechaMaxNac;
          final inicial = _fechaNac ?? DateTime(maxNac.year - 2, 1, 1);
          final p = await showDatePicker(context: context,
              initialDate: inicial.isAfter(maxNac) ? maxNac : inicial,
              firstDate: _fechaMinNac, lastDate: maxNac,
              helpText: 'Fecha de nacimiento (mínimo $_edadMinima años)',
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: UTSCColors.verde)),
                child: child!));
          if (p != null) setState(() => _fechaNac = p);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: UTSCColors.borde), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined, color: UTSCColors.verde),
            const SizedBox(width: 12),
            Text(
              _fechaNac != null
                  ? '${_fechaNac!.day.toString().padLeft(2,'0')}/${_fechaNac!.month.toString().padLeft(2,'0')}/${_fechaNac!.year}'
                  : 'Seleccionar fecha',
              style: TextStyle(color: _fechaNac != null ? UTSCColors.texto : UTSCColors.textoGris, fontSize: 15),
            ),
          ]),
        ),
      )),
      const SizedBox(height: 14),
      UTSCCampo(label: 'Teléfono *', child: TextFormField(
        controller: _telCtrl, keyboardType: TextInputType.phone, maxLength: 10,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(hintText: 'Ej. 8112345678',
            prefixIcon: Icon(Icons.phone_outlined, color: UTSCColors.verde), counterText: ''),
      )),
      const SizedBox(height: 14),
      UTSCCampo(label: 'Fotografía * (JPG o PNG)', child: Column(
        children: [
          GestureDetector(
            onTap: _mostrarOpcionesFoto,
            child: Container(
              width: 110, height: 110,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: Colors.grey.shade100,
                  border: Border.all(color: _foto != null ? UTSCColors.naranja : UTSCColors.borde, width: 3)),
              child: _foto != null
                  ? ClipOval(child: Image.file(File(_foto!.path), fit: BoxFit.cover))
                  : const Icon(Icons.camera_alt, size: 40, color: UTSCColors.textoGris),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _mostrarOpcionesFoto,
            icon: const Icon(Icons.upload, color: UTSCColors.verde),
            label: Text(_foto != null ? 'Cambiar fotografía' : 'Seleccionar fotografía',
                style: const TextStyle(color: UTSCColors.verde)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: UTSCColors.verde)),
          ),
        ],
      )),
    ],
  );

  Widget _buildP2() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const UTSCSeccion(icono: Icons.school, texto: 'Datos Académicos'),
      const SizedBox(height: 16),
      UTSCCampo(label: 'Carrera *', child: DropdownButtonFormField<String>(
        value: _carrera,
        decoration: const InputDecoration(prefixIcon: Icon(Icons.school_outlined, color: UTSCColors.verde)),
        hint: const Text('-- Selecciona una carrera --'),
        items: _carreras.map((c) => DropdownMenuItem(value: c.$1,
            child: Text(c.$2, style: const TextStyle(fontSize: 13)))).toList(),
        onChanged: (v) => setState(() => _carrera = v),
      )),
      const SizedBox(height: 14),
      UTSCCampo(label: 'Nombre del Contacto de Emergencia *', child: TextFormField(
        controller: _contactoNombreCtrl, textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Ej. María López',
            prefixIcon: Icon(Icons.contact_emergency_outlined, color: UTSCColors.verde)),
      )),
      const SizedBox(height: 14),
      UTSCCampo(label: 'Teléfono del Contacto *', child: TextFormField(
        controller: _contactoTelCtrl, keyboardType: TextInputType.phone, maxLength: 10,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(hintText: 'Ej. 8119876543',
            prefixIcon: Icon(Icons.phone_forwarded_outlined, color: UTSCColors.verde), counterText: ''),
      )),
    ],
  );

  Widget _buildP3() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const UTSCSeccion(icono: Icons.folder_open, texto: 'Carga de Documentos'),
      const SizedBox(height: 4),
      const Text('Formatos: PDF, JPG, PNG — Máximo 5 MB por archivo',
          style: TextStyle(fontSize: 12, color: UTSCColors.textoGris)),
      const SizedBox(height: 20),
      UTSCFilePicker(label: 'Acta de Nacimiento *', archivo: _acta,
          onSeleccionar: () async { final f = await _elegirArchivo(); if (f != null) setState(() => _acta = f); }),
      const SizedBox(height: 14),
      UTSCFilePicker(label: 'Certificado de Estudios *', archivo: _cert,
          onSeleccionar: () async { final f = await _elegirArchivo(); if (f != null) setState(() => _cert = f); }),
      const SizedBox(height: 14),
      UTSCFilePicker(label: 'Comprobante de Pago *', archivo: _comprobante,
          onSeleccionar: () async { final f = await _elegirArchivo(); if (f != null) setState(() => _comprobante = f); }),
    ],
  );

  Widget _buildP4() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const UTSCSeccion(icono: Icons.check_circle, texto: 'Confirmación'),
      const SizedBox(height: 16),
      UTSCResumen(titulo: 'Datos Personales', items: [
        ('Nombre',    _nombreCtrl.text),
        ('CURP',      _curpCtrl.text),
        ('Teléfono',  _telCtrl.text),
        ('Nacimiento', _fechaNac != null ? '${_fechaNac!.day}/${_fechaNac!.month}/${_fechaNac!.year}' : '—'),
      ]),
      const SizedBox(height: 12),
      UTSCResumen(titulo: 'Datos Académicos', items: [
        ('Carrera',             _nombreCarrera),
        ('Contacto emergencia', _contactoNombreCtrl.text),
        ('Tel. contacto',       _contactoTelCtrl.text),
      ]),
      const SizedBox(height: 12),
      UTSCResumen(titulo: 'Documentos', items: [
        ('Acta de nacimiento',  _acta?.name ?? '—'),
        ('Certificado',         _cert?.name ?? '—'),
        ('Comprobante de pago', _comprobante?.name ?? '—'),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: UTSCColors.verdeClaro,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: UTSCColors.verde.withOpacity(0.4)),
        ),
        child: const Row(children: [
          Icon(Icons.info_outline, color: UTSCColors.verde, size: 18), SizedBox(width: 8),
          Expanded(child: Text('Al enviar, recibirás un correo con tu folio.',
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

// ── Widgets compartidos (usados también en reinscripcion_screen) ──

class UTSCStepper extends StatelessWidget {
  final int pasoActual;
  static const _labels = ['Datos\nPersonales', 'Académicos', 'Documentos', 'Confirmación'];
  const UTSCStepper({super.key, required this.pasoActual});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(_labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            final paso = i ~/ 2;
            return Expanded(child: Container(height: 3,
                color: paso < pasoActual ? UTSCColors.verde : Colors.grey.shade300));
          }
          final paso = i ~/ 2;
          final activo = paso == pasoActual;
          final hecho  = paso < pasoActual;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: hecho ? UTSCColors.verde : activo ? UTSCColors.naranja : Colors.grey.shade300),
                child: Center(child: hecho
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : Text('${paso + 1}', style: TextStyle(
                        color: activo ? Colors.white : Colors.grey, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(height: 4),
              Text(_labels[paso], textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9,
                      color: activo ? UTSCColors.naranja : hecho ? UTSCColors.verde : Colors.grey)),
            ],
          );
        }),
      ),
    );
  }
}

class UTSCSeccion extends StatelessWidget {
  final IconData icono;
  final String texto;
  const UTSCSeccion({super.key, required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icono, color: UTSCColors.verde, size: 20), const SizedBox(width: 8),
          Text(texto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: UTSCColors.verde)),
        ]),
        const SizedBox(height: 4),
        Container(height: 2, color: UTSCColors.naranja),
      ],
    );
  }
}

class UTSCCampo extends StatelessWidget {
  final String label;
  final Widget child;
  const UTSCCampo({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: UTSCColors.texto)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class UTSCFilePicker extends StatelessWidget {
  final String label;
  final XFile? archivo;
  final VoidCallback onSeleccionar;
  const UTSCFilePicker({super.key, required this.label, required this.archivo, required this.onSeleccionar});

  @override
  Widget build(BuildContext context) {
    final tiene = archivo != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tiene ? UTSCColors.aprobadaFondo : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tiene ? UTSCColors.aprobada : UTSCColors.borde),
      ),
      child: Row(
        children: [
          Icon(tiene ? Icons.check_circle : Icons.upload_file,
              color: tiene ? UTSCColors.aprobada : UTSCColors.textoGris, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: UTSCColors.texto)),
              if (tiene) Text(archivo!.path.split('/').last,
                  style: const TextStyle(fontSize: 12, color: UTSCColors.aprobada),
                  overflow: TextOverflow.ellipsis),
            ],
          )),
          TextButton(onPressed: onSeleccionar,
              child: Text(tiene ? 'Cambiar' : 'Subir', style: const TextStyle(color: UTSCColors.verde))),
        ],
      ),
    );
  }
}

class UTSCResumen extends StatelessWidget {
  final String titulo;
  final List<(String, String)> items;
  const UTSCResumen({super.key, required this.titulo, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, color: UTSCColors.verde, fontSize: 14)),
          const Divider(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 140, child: Text('${item.$1}:',
                    style: const TextStyle(fontSize: 13, color: UTSCColors.textoGris))),
                Expanded(child: Text(item.$2,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: UTSCColors.texto))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) =>
      n.copyWith(text: n.text.toUpperCase());
}
