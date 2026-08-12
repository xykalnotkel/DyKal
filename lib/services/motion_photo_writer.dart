import 'dart:convert';
import 'dart:typed_data';

/// BATCH K — Writer Motion Photo (format resmi Google, spek terbuka):
/// developer.android.com/media/platform/motion-photo-format (GCamera v1).
///
/// Anatomi file:
///   [JPEG utuh] + [segmen APP1 berisi XMP GContainer] + [byte MP4 di ekor]
/// Galeri membaca XMP -> tahu ada video sepanjang Item:Length di AKHIR file
/// -> tampilkan badge motion-photo. Galeri tanpa dukungan tetap menampilkan
/// fotonya (file JPG sah, byte MP4 "tidur" di belakang EOI).
///
/// Murni operasi byte -> tanpa dependensi native, aman di semua device.
class MotionPhotoWriter {
  static const String _ns = 'http://ns.adobe.com/xap/1.0/';

  /// [presentationTimestampUs]: posisi cover di dalam klip, relatif ke AKHIR
  /// video (konvensi Google = negatif, mis. cover 1.5dtk sebelum klip habis).
  static Uint8List build({
    required Uint8List jpeg,
    required Uint8List mp4,
    int presentationTimestampUs = 0,
  }) {
    if (jpeg.length < 4 || jpeg[0] != 0xFF || jpeg[1] != 0xD8) {
      throw ArgumentError('Cover bukan JPEG (SOI/FFD8 tidak ditemukan)');
    }
    if (mp4.isEmpty) {
      throw ArgumentError('MP4 kosong');
    }

    // 1) Rangkai segmen APP1: FFE1 + panjang(2B, termasuk 2 byte panjang itu sendiri)
    //    + header namespace XMP + payload XMP.
    final xmpPayload = utf8.encode(_xmp(mp4.length, presentationTimestampUs));
    final xmpBytes = utf8.encode(_ns) // header namespace diakhiri NUL
        .followedBy(const [0])
        .followedBy(xmpPayload)
        .toList();
    final app1Len = xmpBytes.length + 2;
    if (app1Len > 0xFFFF) {
      throw ArgumentError('XMP terlalu besar untuk satu segmen APP1');
    }
    final app1 = Uint8List(4 + xmpBytes.length);
    app1[0] = 0xFF;
    app1[1] = 0xE1;
    app1[2] = (app1Len >> 8) & 0xFF;
    app1[3] = app1Len & 0xFF;
    app1.setRange(4, app1.length, xmpBytes);

    // 2) Titik sisip: setelah SOI, lewati segmen APPn (FFE0..FFEF) yang sudah
    //    ada (mis. APP0 "JFIF"). Panjang segmen = 2 byte BE yang menghitung
    //    field panjangnya sendiri -> lompatan = 2 (marker) + L.
    var ins = 2;
    while (ins + 3 < jpeg.length && jpeg[ins] == 0xFF) {
      final marker = jpeg[ins + 1];
      if (marker < 0xE0 || marker > 0xEF) break; // bukan APPn -> berhenti
      final segLen = (jpeg[ins + 2] << 8) | jpeg[ins + 3];
      if (segLen < 2) break; // header korup: jangan nekat, sisip di sini saja
      ins += 2 + segLen;
      if (ins > jpeg.length) return jpeg; // mustahil, tapi jangan crash
    }

    // 3) Output: [0..ins) + APP1(XMP) + [ins..) + MP4
    final out = BytesBuilder(copy: false)
      ..add(jpeg.sublist(0, ins))
      ..add(app1)
      ..add(jpeg.sublist(ins))
      ..add(mp4);
    return out.toBytes();
  }

  static String _xmp(int mp4Len, int tsUs) =>
      '<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="DyKal MotionPhotoWriter">\n'
      ' <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">\n'
      '  <rdf:Description rdf:about=""\n'
      '   xmlns:GCamera="http://ns.google.com/photos/1.0/camera/"\n'
      '   xmlns:Container="http://ns.google.com/photos/1.0/container/"\n'
      '   xmlns:Item="http://ns.google.com/photos/1.0/container/item/"\n'
      '   GCamera:MotionPhoto="1"\n'
      '   GCamera:MotionPhotoVersion="1"\n'
      '   GCamera:MotionPhotoPresentationTimestampUs="$tsUs">\n'
      '   <Container:Directory>\n'
      '    <rdf:Seq>\n'
      '     <rdf:li rdf:parseType="Resource">\n'
      '      <Container:Item Item:Semantic="Primary" Item:Mime="image/jpeg" Item:Padding="0"/>\n'
      '     </rdf:li>\n'
      '     <rdf:li rdf:parseType="Resource">\n'
      '      <Container:Item Item:Semantic="MotionPhoto" Item:Mime="video/mp4" Item:Length="$mp4Len" Item:Padding="0"/>\n'
      '     </rdf:li>\n'
      '    </rdf:Seq>\n'
      '   </Container:Directory>\n'
      '  </rdf:Description>\n'
      ' </rdf:RDF>\n'
      '</x:xmpmeta>';
}
