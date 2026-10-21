declare module '@ohos.bundle.installer' {
  namespace installer {
    interface InstallParam {
      userId?: number;
      installFlag?: number;
      isKeepData?: boolean;
    }

    interface BundleInstaller {
      install(hapFilePaths: Array<string>, installParam?: InstallParam): Promise<void>;
      uninstall(bundleName: string, installParam?: InstallParam): Promise<void>;
    }

    function getBundleInstaller(): Promise<BundleInstaller>;
  }

  export default installer;
}
