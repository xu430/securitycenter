import { common } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class IoResult {
  ok: boolean = false;
  message: string = '';
  text: string = '';
}

export class FileExchange {
  static async readRaw(ctx: common.UIAbilityContext, name: string): Promise<IoResult> {
    let result = new IoResult();
    try {
      let data = await ctx.resourceManager.getRawFileContent(name);
      let decoder = util.TextDecoder.create('utf-8');
      result.text = decoder.decodeToString(data);
      result.ok = true;
      result.message = '已读取版式样例';
      return result;
    } catch (err) {
      hilog.error(0x4A59, 'FileExchange', 'raw %{public}s', JSON.stringify(err));
      result.message = '版式样例读取失败';
      return result;
    }
  }

  static async pickText(ctx: common.UIAbilityContext): Promise<IoResult> {
    let result = new IoResult();
    try {
      let options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.fileSuffixFilters = ['.json'];
      let view = new picker.DocumentViewPicker(ctx);
      let uris = await view.select(options);
      if (uris.length === 0) {
        result.message = '没有选择文件';
        return result;
      }
      let file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_ONLY);
      let stat = fileIo.statSync(file.fd);
      if (stat.size <= 0 || stat.size > 1000000) {
        fileIo.closeSync(file);
        result.message = '文件是空的，或超过 1MB';
        return result;
      }
      let buffer = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buffer);
      fileIo.closeSync(file);
      let decoder = util.TextDecoder.create('utf-8');
      result.text = decoder.decodeToString(new Uint8Array(buffer));
      result.ok = true;
      result.message = '已读取文件';
      return result;
    } catch (err) {
      hilog.error(0x4A59, 'FileExchange', 'read %{public}s', JSON.stringify(err));
      result.message = '读取文件失败';
      return result;
    }
  }

  static async pickSidecar(ctx: common.UIAbilityContext): Promise<IoResult> {
    let result = new IoResult();
    try {
      let options = new picker.DocumentSelectOptions();
      options.fileSuffixFilters = ['检测报告|.json'];
      let view = new picker.DocumentViewPicker(ctx);
      let uris = await view.select(options);
      if (uris.length === 0) {
        result.message = '未导入';
        return result;
      }
      return FileExchange.readUri(uris[0]);
    } catch (err) {
      hilog.error(0x4A59, 'FileExchange', 'sidecar %{public}s', JSON.stringify(err));
      result.message = '检测报告读取失败';
      return result;
    }
  }

  private static readUri(uri: string): IoResult {
    let result = new IoResult();
    try {
      let file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      try {
        let stat = fileIo.statSync(file.fd);
        if (stat.size <= 0 || stat.size > 1000000) {
          FileExchange.closeQuiet(file);
          result.message = '文件是空的，或超过 1MB';
          return result;
        }
        let buffer = new ArrayBuffer(stat.size);
        fileIo.readSync(file.fd, buffer);
        FileExchange.closeQuiet(file);
        let decoder = util.TextDecoder.create('utf-8');
        result.text = decoder.decodeToString(new Uint8Array(buffer));
        result.ok = true;
        result.message = '已读取文件';
        return result;
      } catch (err) {
        hilog.error(0x4A59, 'FileExchange', 'uri %{public}s', JSON.stringify(err));
        FileExchange.closeQuiet(file);
        result.message = '读取文件失败';
        return result;
      }
    } catch (err) {
      hilog.error(0x4A59, 'FileExchange', 'open %{public}s', JSON.stringify(err));
      result.message = '读取文件失败';
      return result;
    }
  }

  private static closeQuiet(file: fileIo.File): void {
    try {
      fileIo.closeSync(file);
    } catch (err) {
      hilog.error(0x4A59, 'FileExchange', 'close %{public}s', JSON.stringify(err));
    }
  }

  static async saveText(ctx: common.UIAbilityContext, fileName: string, content: string): Promise<IoResult> {
    let result = new IoResult();
    try {
      let options = new picker.DocumentSaveOptions();
      options.newFileNames = [fileName];
      options.fileSuffixChoices = ['.json'];
      let view = new picker.DocumentViewPicker(ctx);
      let uris = await view.save(options);
      if (uris.length === 0) {
        result.message = '没有保存';
        return result;
      }
      let file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, content);
      fileIo.closeSync(file);
      result.ok = true;
      result.message = '已保存 ' + fileName;
      return result;
    } catch (err) {
      hilog.error(0x4A59, 'FileExchange', 'save %{public}s', JSON.stringify(err));
      result.message = '保存失败';
      return result;
    }
  }

  static async saveLocal(ctx: common.UIAbilityContext, fileName: string, content: string): Promise<IoResult> {
    let result = new IoResult();
    try {
      let path = ctx.filesDir + '/' + fileName;
      let file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, content);
      fileIo.closeSync(file);
      result.ok = true;
      result.message = fileName;
      result.text = path;
      return result;
    } catch (err) {
      hilog.error(0x4A59, 'FileExchange', 'local %{public}s', JSON.stringify(err));
      result.message = '写入应用目录失败';
      return result;
    }
  }
}
