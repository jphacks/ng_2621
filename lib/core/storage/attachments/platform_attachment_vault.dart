export 'attachment_vault.dart';
export 'attachment_vault_io.dart'
    if (dart.library.js_interop) 'attachment_vault_web.dart'
    show openAttachmentVault;
