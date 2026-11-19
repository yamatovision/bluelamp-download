// SignWithEnvName - run jsign with --name taken from the environment (n=5225).
//
// Why: on Windows the java launcher decodes its command line with the ANSI code page, so a
// Japanese --name ("ブルーランプ") passed as an argument arrives as "??????" on an English
// runner (measured: build-13dad6c's programName was '??????'). System.getenv on Windows
// reads the wide (UTF-16) environment, so the name survives when it travels as BL_SIGN_NAME.
//
// Usage (source-file mode, JDK 11+):
//   java -cp jsign.jar SignWithEnvName.java <jsign options without --name> <file>
// Fails closed: no BL_SIGN_NAME, or a --name on the command line, is an error.
public class SignWithEnvName {
    public static void main(String[] args) throws Exception {
        String name = System.getenv("BL_SIGN_NAME");
        if (name == null || name.isBlank()) {
            System.err.println("SignWithEnvName: BL_SIGN_NAME is not set");
            System.exit(2);
        }
        for (String a : args) {
            if (a.equals("--name") || a.startsWith("--name=")) {
                System.err.println("SignWithEnvName: pass the name in BL_SIGN_NAME, not --name");
                System.exit(2);
            }
        }
        String[] all = new String[args.length + 2];
        all[0] = "--name";
        all[1] = name;
        System.arraycopy(args, 0, all, 2, args.length);
        net.jsign.JsignCLI.main(all);
    }
}
