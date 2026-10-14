import java.io.*;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.util.regex.*;
import java.util.zip.*;
import org.objectweb.asm.*;
import org.objectweb.asm.commons.*;

/** Keeps QRing's Java-only RealSil BBPro 1.9.4 separate from Yucheng's 1.6.1. */
public final class IsolateQRing {
    // Only the Java core collides. Leave DSP/authentication JNI owners and
    // model names untouched; libDspConfig.so refers to them by fixed names.
    private static final String ORIGINAL = "com/realsil/sdk/bbpro/core/";
    private static final String ISOLATED = "cc/saidian/vendor/qring/bbpro/core/";
    private static final Remapper NAMES = new Remapper() {
        @Override public String map(String name) {
            return name.startsWith(ORIGINAL) ? ISOLATED + name.substring(ORIGINAL.length()) : name;
        }
        @Override public Object mapValue(Object value) {
            if (value instanceof String) {
                String name = (String) value;
                if (name.startsWith(ORIGINAL.replace('/', '.'))) {
                    return map(name.replace('.', '/')).replace('/', '.');
                }
            }
            return super.mapValue(value);
        }
    };
    private static byte[] consumerRules(byte[] input) {
        String rules = new String(input, StandardCharsets.UTF_8);
        // QRing repeats its vendor build rules twice. R8 resolves this output
        // relative to the extracted AAR and writes into Gradle's immutable
        // transform cache. The app already owns its mapping output; keep every
        // SDK keep/optimization rule and remove only these two output lines.
        Matcher mapping = Pattern.compile(
            "(?m)^[ \\t]*-printmapping[ \\t]+map\\.txt[ \\t]*(?:\\r?\\n|$)").matcher(rules);
        int count = 0;
        while (mapping.find()) count++;
        if (count != 2) {
            throw new IllegalArgumentException("Expected two QRing mapping outputs, found " + count);
        }
        String cleaned = mapping.replaceAll("");
        if (Pattern.compile("(?m)^[ \\t]*-printmapping\\b").matcher(cleaned).find()) {
            throw new IllegalArgumentException("Unexpected QRing mapping output; review the vendor rules");
        }
        return cleaned.getBytes(StandardCharsets.UTF_8);
    }
    private static byte[] rewrite(byte[] input, boolean archive) throws IOException {
        if (!archive) {
            ClassReader reader = new ClassReader(input);
            {
                reader.accept(new ClassVisitor(Opcodes.ASM9) {
                    @Override public MethodVisitor visitMethod(int access, String name, String descriptor, String signature, String[] exceptions) {
                        if ((access & Opcodes.ACC_NATIVE) != 0 &&
                            (reader.getClassName().startsWith(ORIGINAL) || descriptor.contains(ORIGINAL))) {
                            throw new IllegalArgumentException("Unsupported BBPro JNI owner/signature: " + reader.getClassName() + "." + name);
                        }
                        return null;
                    }
                }, ClassReader.SKIP_CODE | ClassReader.SKIP_DEBUG | ClassReader.SKIP_FRAMES);
            }
            ClassWriter output = new ClassWriter(0);
            reader.accept(new ClassRemapper(output, NAMES), 0);
            return output.toByteArray();
        }
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (ZipInputStream source = new ZipInputStream(new ByteArrayInputStream(input));
             ZipOutputStream output = new ZipOutputStream(bytes)) {
            ZipEntry entry;
            while ((entry = source.getNextEntry()) != null) {
                String name = entry.getName();
                byte[] data = source.readAllBytes();
                if (name.endsWith(".class")) {
                    data = rewrite(data, false);
                    name = NAMES.map(name.substring(0, name.length() - 6)) + ".class";
                } else if (name.endsWith(".jar")) {
                    data = rewrite(data, true);
                } else if (name.equals("proguard.txt")) {
                    data = consumerRules(data);
                }
                ZipEntry target = new ZipEntry(name);
                target.setTime(0);
                output.putNextEntry(target);
                output.write(data);
                output.closeEntry();
            }
        }
        return bytes.toByteArray();
    }
    public static void main(String[] args) throws IOException {
        Path output = Path.of(args[1]);
        Files.createDirectories(output.getParent());
        Files.write(output, rewrite(Files.readAllBytes(Path.of(args[0])), true));
    }
}
