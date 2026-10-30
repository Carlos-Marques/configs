# ssh-agent's confirm-before-use program on macOS (SSH_ASKPASS): Touch ID (or
# the login password) before every use of a key that KeePassXC loaded with the
# confirm constraint, as 1Password's agent does. Exit 0 allows that one use.
# It only answers confirmations, never passphrase prompts.
{
  lib,
  stdenv,
  writeText,
}:

let
  src = writeText "ssh-askpass-touchid.m" ''
    #import <Foundation/Foundation.h>
    #import <LocalAuthentication/LocalAuthentication.h>

    int main(int argc, const char *argv[]) {
      @autoreleasepool {
        const char *kind = getenv("SSH_ASKPASS_PROMPT");
        if (kind == NULL || strcmp(kind, "confirm") != 0) return 1;

        // ssh-agent asks "Allow use of key <comment>?\nKey fingerprint ...".
        NSString *prompt = argc > 1 ? [NSString stringWithUTF8String:argv[1]] : @"";
        NSString *what = @"use your SSH key";
        NSRange head = [prompt rangeOfString:@"Allow use of key "];
        if (head.location != NSNotFound) {
          NSUInteger start = NSMaxRange(head);
          NSRange end = [prompt rangeOfString:@"?" options:0
                                        range:NSMakeRange(start, prompt.length - start)];
          if (end.location != NSNotFound)
            what = [NSString stringWithFormat:@"use SSH key %@",
                    [prompt substringWithRange:NSMakeRange(start, end.location - start)]];
        }

        LAContext *context = [[LAContext alloc] init];
        __block BOOL allowed = NO;
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication
                localizedReason:what
                          reply:^(BOOL success, NSError *error) {
                            allowed = success;
                            dispatch_semaphore_signal(done);
                          }];
        dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
        return allowed ? 0 : 1;
      }
    }
  '';
in
stdenv.mkDerivation {
  name = "ssh-askpass-touchid";
  dontUnpack = true;

  buildPhase = ''
    $CC -fobjc-arc -O2 -framework Foundation -framework LocalAuthentication ${src} -o ssh-askpass-touchid
  '';

  installPhase = ''
    install -Dm755 ssh-askpass-touchid $out/bin/ssh-askpass-touchid
  '';

  meta = {
    mainProgram = "ssh-askpass-touchid";
    platforms = lib.platforms.darwin;
  };
}
