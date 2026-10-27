import {
  AbilityAware,
  AbilityPluginBinding,
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult
} from '@ohos/flutter_ohos';
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import { notificationManager } from '@kit.NotificationKit';

const CHANNEL = 'com.cinemaradar.app/background_access';
const BUNDLE_NAME = 'com.cinemaradar.app';

export default class BackgroundAccessPlugin implements FlutterPlugin, AbilityAware, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private context: common.UIAbilityContext | null = null;

  getUniqueClassName(): string {
    return 'CinemaRadarBackgroundAccessPlugin';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel !== null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.context = binding.getAbility().context;
  }

  onDetachedFromAbility(): void {
    this.context = null;
  }

  async onMethodCall(call: MethodCall, result: MethodResult): Promise<void> {
    switch (call.method) {
      case 'getStatus':
        await this.getStatus(result);
        break;
      case 'openBackgroundSettings':
      case 'openAppSettings':
        await this.openApplicationDetails(result);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private async getStatus(result: MethodResult): Promise<void> {
    let notificationsEnabled = false;
    try {
      notificationsEnabled = await notificationManager.isNotificationEnabled();
    } catch (_) {
      notificationsEnabled = false;
    }
    const status: Map<string, ESObject> = new Map<string, ESObject>();
    status.set('notificationsEnabled', notificationsEnabled);
    status.set('settingsAvailable', this.context !== null);
    status.set('scheduledBackgroundSupported', false);
    result.success(status);
  }

  private async openApplicationDetails(result: MethodResult): Promise<void> {
    if (this.context === null) {
      result.success(false);
      return;
    }
    const want: Want = {
      bundleName: 'com.huawei.hmos.settings',
      abilityName: 'com.huawei.hmos.settings.MainAbility',
      uri: 'application_info_entry',
      parameters: {
        pushParams: BUNDLE_NAME
      }
    };
    try {
      await this.context.startAbility(want);
      result.success(true);
    } catch (error) {
      result.error('OPEN_SETTINGS_FAILED', 'Unable to open application settings', `${error}`);
    }
  }
}
