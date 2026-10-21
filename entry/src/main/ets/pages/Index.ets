import { Theme } from '../common/Theme';
import { probeName } from '../model/ProbeStatus';
import { ArchiveView } from './ArchiveView';
import { DeviceView } from './DeviceView';
import { HomeView } from './HomeView';
import { LedgerView } from './LedgerView';
import { ScanView } from './ScanView';
import { SocView } from './SocView';

@Entry
@Component
struct Index {
  private pages: NavPathStack = new NavPathStack();

  build() {
    Navigation(this.pages) {
      HomeView({
        onOpen: (route: string) => {
          this.pages.pushPathByName(route, route);
        }
      })
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .hideToolBar(true)
    .navDestination(this.routeMap)
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.page)
  }

  @Builder
  routeMap(route: string) {
    NavDestination() {
      if (route === 'P1' || route === 'P2' || route === 'P3') {
        ScanView({ only: route })
      } else if (route === 'ledger') {
        LedgerView()
      } else if (route === 'report') {
        SocView()
      } else if (route === 'archive') {
        ArchiveView()
      } else if (route === 'about') {
        ArchiveView({ section: 'about' })
      } else if (route === 'device') {
        DeviceView()
      }
    }
    .title(routeTitle(route))
    .backgroundColor(Theme.page)
  }
}

function routeTitle(route: string): string {
  if (route === 'P1' || route === 'P2' || route === 'P3') {
    return probeName(route);
  }
  if (route === 'ledger') {
    return '风险记录';
  }
  if (route === 'report') {
    return '安全报告';
  }
  if (route === 'archive') {
    return '记录导入导出';
  }
  if (route === 'about') {
    return '安全说明';
  }
  if (route === 'device') {
    return '设备信息';
  }
  return '安全中心';
}
