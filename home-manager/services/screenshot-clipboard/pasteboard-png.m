#import <AppKit/AppKit.h>

int main(int argc, char *argv[]) {
  @autoreleasepool {
    if (argc != 2) {
      fprintf(stderr, "usage: pasteboard-png FILE\n");
      return 2;
    }
    NSData *data = [NSData dataWithContentsOfFile:@(argv[1])];
    if (data == nil) {
      fprintf(stderr, "pasteboard-png: cannot read %s\n", argv[1]);
      return 1;
    }
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    if (![pasteboard setData:data forType:NSPasteboardTypePNG]) {
      fprintf(stderr, "pasteboard-png: pasteboard rejected %s\n", argv[1]);
      return 1;
    }
  }
  return 0;
}
