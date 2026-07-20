class EngineHealth {
  const EngineHealth({
    required this.protocolVersion,
    required this.engine,
    required this.engineVersion,
    required this.executable,
  });

  factory EngineHealth.fromJson(Map<String, dynamic> json) => EngineHealth(
    protocolVersion: json['protocolVersion'] as int,
    engine: json['engine'] as String,
    engineVersion: json['engineVersion'] as String,
    executable: json['executable'] as String,
  );

  final int protocolVersion;
  final String engine;
  final String engineVersion;
  final String executable;
}

class PdfOcrHealth {
  const PdfOcrHealth({
    required this.provider,
    required this.version,
    required this.executable,
    required this.features,
  });

  factory PdfOcrHealth.fromJson(Map<String, dynamic> json) => PdfOcrHealth(
    provider: json['provider'] as String,
    version: json['version'] as String,
    executable: json['executable'] as String,
    features: (json['features'] as List<dynamic>? ?? const [])
        .cast<String>()
        .toSet(),
  );

  final String provider;
  final String version;
  final String executable;
  final Set<String> features;

  bool get preservesVisualLayout =>
      features.contains('visualLayoutPreservation');
  bool get supportsStructuredLayout => features.contains('structuredOutput');
  bool get supportsTables => features.contains('tables');
  bool get supportsFormulas => features.contains('formulas');
}

class PdfOcrResult {
  const PdfOcrResult({
    required this.provider,
    required this.version,
    required this.language,
    required this.output,
    required this.bytes,
    required this.features,
  });

  factory PdfOcrResult.fromJson(Map<String, dynamic> json) => PdfOcrResult(
    provider: json['provider'] as String,
    version: json['version'] as String,
    language: json['language'] as String,
    output: json['output'] as String,
    bytes: json['bytes'] as int,
    features: (json['features'] as List<dynamic>? ?? const [])
        .cast<String>()
        .toSet(),
  );

  final String provider;
  final String version;
  final String language;
  final String output;
  final int bytes;
  final Set<String> features;
}

enum PdfSignatureProfile {
  baselineB,
  baselineLT,
  baselineLTA;

  bool get requiresTimestamp => this != PdfSignatureProfile.baselineB;

  String get displayName => switch (this) {
    PdfSignatureProfile.baselineB => 'PAdES Baseline B (offline)',
    PdfSignatureProfile.baselineLT => 'PAdES Baseline LT',
    PdfSignatureProfile.baselineLTA => 'PAdES Baseline LTA',
  };
}

class PdfSignatureHealth {
  const PdfSignatureHealth({
    required this.provider,
    required this.version,
    required this.executable,
    required this.profiles,
  });

  factory PdfSignatureHealth.fromJson(Map<String, dynamic> json) =>
      PdfSignatureHealth(
        provider: json['provider'] as String,
        version: json['version'] as String,
        executable: json['executable'] as String,
        profiles: (json['profiles'] as List<dynamic>? ?? const [])
            .cast<String>()
            .map(
              (value) => PdfSignatureProfile.values.firstWhere(
                (profile) => profile.name == value,
              ),
            )
            .toSet(),
      );

  final String provider;
  final String version;
  final String executable;
  final Set<PdfSignatureProfile> profiles;
}

class PdfSignatureVerification {
  const PdfSignatureVerification({
    required this.integrity,
    required this.certificateTrust,
    required this.details,
    required this.hasTimestamp,
    required this.hasValidationInfo,
    this.signerName,
  });

  factory PdfSignatureVerification.fromJson(Map<String, dynamic> json) =>
      PdfSignatureVerification(
        integrity: json['integrity'] as String,
        certificateTrust: json['certificateTrust'] as String,
        signerName: json['signerName'] as String?,
        details: json['details'] as String,
        hasTimestamp: json['hasTimestamp'] as bool? ?? false,
        hasValidationInfo: json['hasValidationInfo'] as bool? ?? false,
      );

  final String integrity;
  final String certificateTrust;
  final String? signerName;
  final String details;
  final bool hasTimestamp;
  final bool hasValidationInfo;

  bool get isCryptographicallyValid => integrity == 'valid';

  String get summary {
    final integrityText = switch (integrity) {
      'valid' => 'Tính toàn vẹn chữ ký hợp lệ.',
      'invalid' => 'Chữ ký không khớp với nội dung PDF.',
      'unsigned' => 'PDF không có chữ ký số nhúng.',
      _ => 'Chưa xác định được tính toàn vẹn chữ ký.',
    };
    final trustText = switch (certificateTrust) {
      'trusted' => 'Certificate được trust store hiện tại tin cậy.',
      'untrusted' => 'Certificate chưa được trust store hiện tại tin cậy.',
      _ => 'Chưa xác định được certificate trust.',
    };
    return [
      integrityText,
      trustText,
      if (signerName != null) 'Người ký: $signerName.',
      hasTimestamp ? 'Có timestamp.' : 'Chưa phát hiện timestamp.',
      hasValidationInfo
          ? 'Có dữ liệu validation/DSS.'
          : 'Chưa phát hiện dữ liệu validation/DSS.',
    ].join(' ');
  }
}

class PdfSignatureResult {
  const PdfSignatureResult({
    required this.provider,
    required this.version,
    required this.profile,
    required this.output,
    required this.bytes,
    required this.verification,
  });

  factory PdfSignatureResult.fromJson(Map<String, dynamic> json) =>
      PdfSignatureResult(
        provider: json['provider'] as String,
        version: json['version'] as String,
        profile: PdfSignatureProfile.values.firstWhere(
          (profile) => profile.name == json['profile'] as String,
        ),
        output: json['output'] as String,
        bytes: json['bytes'] as int,
        verification: PdfSignatureVerification.fromJson(
          json['verification'] as Map<String, dynamic>,
        ),
      );

  final String provider;
  final String version;
  final PdfSignatureProfile profile;
  final String output;
  final int bytes;
  final PdfSignatureVerification verification;
}

enum DocumentIrBlockKind {
  paragraph,
  heading,
  listItem,
  table,
  formula,
  figure,
  caption,
  header,
  footer,
  footnote,
  pageNumber,
  unknown;

  static DocumentIrBlockKind fromJson(String value) => values.firstWhere(
    (kind) => kind.name == value,
    orElse: () => DocumentIrBlockKind.unknown,
  );
}

class DocumentIr {
  const DocumentIr({
    required this.schemaVersion,
    required this.providerId,
    this.providerVersion,
    this.modelId,
    required this.pages,
  });

  factory DocumentIr.fromJson(Map<String, dynamic> json) {
    final provenance = json['provenance'] as Map<String, dynamic>? ?? const {};
    return DocumentIr(
      schemaVersion: json['schemaVersion'] as int,
      providerId: provenance['providerID'] as String,
      providerVersion: provenance['providerVersion'] as String?,
      modelId: provenance['modelID'] as String?,
      pages: (json['pages'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(DocumentIrPage.fromJson)
          .toList(growable: false),
    );
  }

  final int schemaVersion;
  final String providerId;
  final String? providerVersion;
  final String? modelId;
  final List<DocumentIrPage> pages;

  String get plainText {
    final orderedPages = [...pages]..sort((a, b) => a.index.compareTo(b.index));
    return orderedPages
        .map((page) => page.plainText)
        .where((text) => text.isNotEmpty)
        .join('\n\n');
  }
}

class DocumentIrPage {
  const DocumentIrPage({
    required this.index,
    required this.width,
    required this.height,
    required this.sourceRotation,
    required this.blocks,
    required this.readingOrder,
  });

  factory DocumentIrPage.fromJson(Map<String, dynamic> json) {
    final size = json['size'] as Map<String, dynamic>;
    return DocumentIrPage(
      index: json['index'] as int,
      width: (size['width'] as num).toDouble(),
      height: (size['height'] as num).toDouble(),
      sourceRotation: json['sourceRotation'] as int? ?? 0,
      blocks: (json['blocks'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(DocumentIrBlock.fromJson)
          .toList(growable: false),
      readingOrder: (json['readingOrder'] as List<dynamic>? ?? const [])
          .cast<String>(),
    );
  }

  final int index;
  final double width;
  final double height;
  final int sourceRotation;
  final List<DocumentIrBlock> blocks;
  final List<String> readingOrder;

  List<DocumentIrBlock> get orderedBlocks {
    final byId = <String, DocumentIrBlock>{};
    for (final block in blocks) {
      byId.putIfAbsent(block.id, () => block);
    }
    final ordered = readingOrder
        .map((id) => byId[id])
        .whereType<DocumentIrBlock>()
        .toList();
    final included = ordered.map((block) => block.id).toSet();
    ordered.addAll(blocks.where((block) => !included.contains(block.id)));
    return ordered;
  }

  String get plainText => orderedBlocks
      .where((block) => !block.isArtifact && block.plainText.isNotEmpty)
      .map((block) => block.plainText)
      .join('\n');
}

class DocumentIrBlock {
  const DocumentIrBlock({
    required this.id,
    required this.kind,
    required this.bounds,
    required this.isArtifact,
    this.confidence,
    this.language,
    this.text,
    this.lines = const [],
    this.tableCells = const [],
    this.formula,
    this.figureAltText,
  });

  factory DocumentIrBlock.fromJson(Map<String, dynamic> json) {
    final table = json['table'] as Map<String, dynamic>?;
    final formula = json['formula'] as Map<String, dynamic>?;
    final figure = json['figure'] as Map<String, dynamic>?;
    return DocumentIrBlock(
      id: json['id'] as String,
      kind: DocumentIrBlockKind.fromJson(json['kind'] as String),
      bounds: PdfBounds.fromJson(json['bounds'] as Map<String, dynamic>),
      isArtifact: json['isArtifact'] as bool? ?? false,
      confidence: (json['confidence'] as num?)?.toDouble(),
      language: json['language'] as String?,
      text: json['text'] as String?,
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map((line) => line['text'] as String? ?? '')
          .where((text) => text.isNotEmpty)
          .toList(growable: false),
      tableCells: (table?['cells'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(DocumentIrTableCell.fromJson)
          .toList(growable: false),
      formula: formula?['latex'] as String? ?? formula?['mathML'] as String?,
      figureAltText: figure?['altText'] as String?,
    );
  }

  final String id;
  final DocumentIrBlockKind kind;
  final PdfBounds bounds;
  final bool isArtifact;
  final double? confidence;
  final String? language;
  final String? text;
  final List<String> lines;
  final List<DocumentIrTableCell> tableCells;
  final String? formula;
  final String? figureAltText;

  String get plainText {
    if (text?.isNotEmpty == true) return text!;
    if (lines.isNotEmpty) return lines.join('\n');
    if (tableCells.isNotEmpty) {
      final rows = <int, List<DocumentIrTableCell>>{};
      for (final cell in tableCells) {
        rows.putIfAbsent(cell.row, () => []).add(cell);
      }
      final indexes = rows.keys.toList()..sort();
      return indexes
          .map((row) {
            final cells = rows[row]!
              ..sort((a, b) => a.column.compareTo(b.column));
            return cells.map((cell) => cell.text).join('\t');
          })
          .join('\n');
    }
    if (formula?.isNotEmpty == true) return formula!;
    if (figureAltText?.isNotEmpty == true) return figureAltText!;
    return '';
  }
}

class DocumentIrTableCell {
  const DocumentIrTableCell({
    required this.row,
    required this.column,
    required this.text,
  });

  factory DocumentIrTableCell.fromJson(Map<String, dynamic> json) =>
      DocumentIrTableCell(
        row: json['row'] as int,
        column: json['column'] as int,
        text: json['text'] as String,
      );

  final int row;
  final int column;
  final String text;
}

class PdfMetadata {
  const PdfMetadata({
    this.title,
    this.author,
    this.subject,
    this.creator,
    this.producer,
    this.language,
    this.keywords = const [],
  });

  factory PdfMetadata.fromJson(Map<String, dynamic> json) => PdfMetadata(
    title: json['title'] as String?,
    author: json['author'] as String?,
    subject: json['subject'] as String?,
    creator: json['creator'] as String?,
    producer: json['producer'] as String?,
    language: json['language'] as String?,
    keywords: (json['keywords'] as List<dynamic>? ?? const []).cast<String>(),
  );

  final String? title;
  final String? author;
  final String? subject;
  final String? creator;
  final String? producer;
  final String? language;
  final List<String> keywords;
}

class PdfDocumentInfo {
  const PdfDocumentInfo({
    required this.protocolVersion,
    required this.pageCount,
    required this.metadata,
    required this.capabilities,
  });

  factory PdfDocumentInfo.fromJson(Map<String, dynamic> json) =>
      PdfDocumentInfo(
        protocolVersion: json['protocolVersion'] as int,
        pageCount: json['pageCount'] as int,
        metadata: PdfMetadata.fromJson(
          (json['metadata'] as Map<String, dynamic>?) ?? const {},
        ),
        capabilities: (json['capabilities'] as List<dynamic>? ?? const [])
            .cast<String>()
            .toSet(),
      );

  final int protocolVersion;
  final int pageCount;
  final PdfMetadata metadata;
  final Set<String> capabilities;
}

class RenderedPdfPage {
  RenderedPdfPage({
    required this.page,
    required this.width,
    required this.height,
    required this.format,
    required this.output,
    PdfBounds? pageBox,
    this.rotation = 0,
  }) : pageBox =
           pageBox ??
           PdfBounds(
             x: 0,
             y: 0,
             width: rotation == 90 || rotation == 270 ? height : width,
             height: rotation == 90 || rotation == 270 ? width : height,
           );

  factory RenderedPdfPage.fromJson(Map<String, dynamic> json) =>
      RenderedPdfPage(
        page: json['page'] as int,
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        format: json['format'] as String,
        output: json['output'] as String,
        pageBox: json['pageBox'] == null
            ? null
            : PdfBounds.fromJson(json['pageBox'] as Map<String, dynamic>),
        rotation: json['rotation'] as int? ?? 0,
      );

  final int page;
  final double width;
  final double height;
  final String format;
  final String output;
  final PdfBounds pageBox;
  final int rotation;
}

enum PdfAnnotationKind {
  note,
  freeText,
  image,
  unknown;

  static PdfAnnotationKind fromJson(String value) => values.firstWhere(
    (kind) => kind.name == value,
    orElse: () => PdfAnnotationKind.unknown,
  );
}

enum PdfTextAlignment { left, center, right }

class PdfBounds {
  const PdfBounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory PdfBounds.fromJson(Map<String, dynamic> json) {
    final origin = json['origin'] as Map<String, dynamic>;
    final size = json['size'] as Map<String, dynamic>;
    return PdfBounds(
      x: (origin['x'] as num).toDouble(),
      y: (origin['y'] as num).toDouble(),
      width: (size['width'] as num).toDouble(),
      height: (size['height'] as num).toDouble(),
    );
  }

  final double x;
  final double y;
  final double width;
  final double height;

  Map<String, dynamic> toJson() => {
    'origin': {'x': x, 'y': y},
    'size': {'width': width, 'height': height},
  };
}

class PdfPageGeometry {
  const PdfPageGeometry({required this.pageBox, required this.rotation});

  final PdfBounds pageBox;
  final int rotation;

  int get normalizedRotation {
    final value = ((rotation % 360) + 360) % 360;
    return value == 90 || value == 180 || value == 270 ? value : 0;
  }

  double get viewportWidth =>
      normalizedRotation == 90 || normalizedRotation == 270
      ? pageBox.height
      : pageBox.width;

  double get viewportHeight =>
      normalizedRotation == 90 || normalizedRotation == 270
      ? pageBox.width
      : pageBox.height;

  PdfBounds toViewport(PdfBounds bounds) {
    final x = bounds.x - pageBox.x;
    final y = bounds.y - pageBox.y;
    return switch (normalizedRotation) {
      90 => PdfBounds(x: y, y: x, width: bounds.height, height: bounds.width),
      180 => PdfBounds(
        x: pageBox.width - x - bounds.width,
        y: y,
        width: bounds.width,
        height: bounds.height,
      ),
      270 => PdfBounds(
        x: pageBox.height - y - bounds.height,
        y: pageBox.width - x - bounds.width,
        width: bounds.height,
        height: bounds.width,
      ),
      _ => PdfBounds(
        x: x,
        y: pageBox.height - y - bounds.height,
        width: bounds.width,
        height: bounds.height,
      ),
    };
  }

  PdfBounds fromViewport(PdfBounds bounds) => switch (normalizedRotation) {
    90 => PdfBounds(
      x: pageBox.x + bounds.y,
      y: pageBox.y + bounds.x,
      width: bounds.height,
      height: bounds.width,
    ),
    180 => PdfBounds(
      x: pageBox.x + pageBox.width - bounds.x - bounds.width,
      y: pageBox.y + bounds.y,
      width: bounds.width,
      height: bounds.height,
    ),
    270 => PdfBounds(
      x: pageBox.x + pageBox.width - bounds.y - bounds.height,
      y: pageBox.y + pageBox.height - bounds.x - bounds.width,
      width: bounds.height,
      height: bounds.width,
    ),
    _ => PdfBounds(
      x: pageBox.x + bounds.x,
      y: pageBox.y + pageBox.height - bounds.y - bounds.height,
      width: bounds.width,
      height: bounds.height,
    ),
  };
}

class PdfColor {
  const PdfColor({
    required this.red,
    required this.green,
    required this.blue,
    this.alpha = 1,
  });

  factory PdfColor.fromJson(Map<String, dynamic> json) => PdfColor(
    red: (json['red'] as num).toDouble(),
    green: (json['green'] as num).toDouble(),
    blue: (json['blue'] as num).toDouble(),
    alpha: (json['alpha'] as num? ?? 1).toDouble(),
  );

  final double red;
  final double green;
  final double blue;
  final double alpha;

  Map<String, dynamic> toJson() => {
    'red': red,
    'green': green,
    'blue': blue,
    'alpha': alpha,
  };
}

class PdfTextStyle {
  const PdfTextStyle({
    this.fontName = 'Helv',
    this.fontSize = 14,
    this.color = const PdfColor(red: 0, green: 0, blue: 0),
    this.alignment = PdfTextAlignment.left,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
  });

  factory PdfTextStyle.fromJson(Map<String, dynamic> json) => PdfTextStyle(
    fontName: json['fontName'] as String? ?? 'Helv',
    fontSize: (json['fontSize'] as num? ?? 14).toDouble(),
    color: PdfColor.fromJson(
      (json['color'] as Map<String, dynamic>?) ??
          const {'red': 0, 'green': 0, 'blue': 0, 'alpha': 1},
    ),
    alignment: PdfTextAlignment.values.firstWhere(
      (alignment) => alignment.name == json['alignment'],
      orElse: () => PdfTextAlignment.left,
    ),
    isBold: json['isBold'] as bool? ?? false,
    isItalic: json['isItalic'] as bool? ?? false,
    isUnderline: json['isUnderline'] as bool? ?? false,
  );

  final String fontName;
  final double fontSize;
  final PdfColor color;
  final PdfTextAlignment alignment;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;

  Map<String, dynamic> toJson() => {
    'fontName': fontName,
    'fontSize': fontSize,
    'color': color.toJson(),
    'alignment': alignment.name,
    'isBold': isBold,
    'isItalic': isItalic,
    'isUnderline': isUnderline,
  };
}

class PdfAnnotation {
  const PdfAnnotation({
    required this.id,
    required this.kind,
    required this.pageIndex,
    required this.bounds,
    this.contents,
    this.color,
    this.opacity = 1,
    this.coordinateSpace = 'pdfBottomLeft',
    this.textStyle,
  });

  factory PdfAnnotation.fromJson(Map<String, dynamic> json) => PdfAnnotation(
    id: json['id'] as String,
    kind: PdfAnnotationKind.fromJson(json['kind'] as String),
    pageIndex: json['pageIndex'] as int,
    bounds: PdfBounds.fromJson(json['bounds'] as Map<String, dynamic>),
    contents: json['contents'] as String?,
    color: json['color'] == null
        ? null
        : PdfColor.fromJson(json['color'] as Map<String, dynamic>),
    opacity: (json['opacity'] as num? ?? 1).toDouble(),
    coordinateSpace: json['coordinateSpace'] as String? ?? 'pdfBottomLeft',
    textStyle: json['textStyle'] == null
        ? null
        : PdfTextStyle.fromJson(json['textStyle'] as Map<String, dynamic>),
  );

  final String id;
  final PdfAnnotationKind kind;
  final int pageIndex;
  final PdfBounds bounds;
  final String? contents;
  final PdfColor? color;
  final double opacity;
  final String coordinateSpace;
  final PdfTextStyle? textStyle;

  PdfAnnotation copyWith({
    PdfBounds? bounds,
    String? contents,
    PdfColor? color,
    double? opacity,
    PdfTextStyle? textStyle,
  }) => PdfAnnotation(
    id: id,
    kind: kind,
    pageIndex: pageIndex,
    bounds: bounds ?? this.bounds,
    contents: contents ?? this.contents,
    color: color ?? this.color,
    opacity: opacity ?? this.opacity,
    coordinateSpace: coordinateSpace,
    textStyle: textStyle ?? this.textStyle,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'pageIndex': pageIndex,
    'bounds': bounds.toJson(),
    'contents': contents,
    'color': color?.toJson(),
    'opacity': opacity,
    'coordinateSpace': coordinateSpace,
    'textStyle': textStyle?.toJson(),
  };
}

class PdfSearchMatch {
  const PdfSearchMatch({required this.pageIndex, required this.text});

  factory PdfSearchMatch.fromJson(Map<String, dynamic> json) => PdfSearchMatch(
    pageIndex: json['pageIndex'] as int,
    text: json['text'] as String,
  );

  final int pageIndex;
  final String text;
}
