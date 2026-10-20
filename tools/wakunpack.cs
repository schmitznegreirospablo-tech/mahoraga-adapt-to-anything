using System;
using System.IO;
using System.Text;

// Unpacks Noita's data.wak (unencrypted format) into a folder.
class WakUnpack {
    static void Main(string[] args) {
        string wak = args[0], outDir = args[1];
        string filter = args.Length > 2 ? args[2] : null;
        byte[] buf = File.ReadAllBytes(wak);
        int count = BitConverter.ToInt32(buf, 4);
        int pos = 16;
        int written = 0;
        for (int i = 0; i < count; i++) {
            int off = BitConverter.ToInt32(buf, pos);
            int size = BitConverter.ToInt32(buf, pos + 4);
            int nlen = BitConverter.ToInt32(buf, pos + 8);
            string name = Encoding.UTF8.GetString(buf, pos + 12, nlen);
            pos += 12 + nlen;
            if (filter != null && !name.EndsWith(filter)) continue;
            string dest = Path.Combine(outDir, name.Replace('/', Path.DirectorySeparatorChar));
            Directory.CreateDirectory(Path.GetDirectoryName(dest));
            using (var fs = File.Create(dest)) fs.Write(buf, off, size);
            written++;
        }
        Console.WriteLine("files: " + count + " written: " + written);
    }
}
