import { preferences } from '@kit.ArkData';
import common from '@ohos.app.ability.common';

// 定义支持的基础类型（Preferences 原生支持）
type PrimitiveType = number | string | boolean;
// 扩展类型，支持对象（需要我们在内部转换）
type DataType = PrimitiveType | object;

export class UserPreferencesManager {
  // 单例模式（可选，如果全局只有一个实例更方便管理）
  private static instance: UserPreferencesManager;
  private pref: preferences.Preferences | null = null;

  public static getInstance(): UserPreferencesManager {
    if (!UserPreferencesManager.instance) {
      UserPreferencesManager.instance = new UserPreferencesManager();
    }
    return UserPreferencesManager.instance;
  }

  // 初始化用户仓库
  async initUser(context: common.UIAbilityContext, userId: string) {
    const storeName = `store_${userId}`;
    try {
      this.pref = await preferences.getPreferences(context, storeName);
      console.info(`[UserPreferencesManager] Success init store: ${storeName}`);
    } catch (error) {
      console.error(`[UserPreferencesManager] Failed to init store: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 存储数据
   * 如果是 object 类型，自动序列化为 JSON 字符串存储
   */
  async setValue(key: string, value: DataType) {
    if (!this.pref) {
      console.error('[UserPreferencesManager] Preferences not initialized!');
      return;
    }

    try {
      let saveValue: preferences.ValueType;

      if (typeof value === 'object' && value !== null) {
        // 如果是对象，加一个前缀标识，转为字符串
        saveValue = 'OBJ_' + JSON.stringify(value);
      } else {
        saveValue = value as preferences.ValueType;
      }

      await this.pref.put(key, saveValue);
      await this.pref.flush(); // 立即写入磁盘
    } catch (e) {
      console.error(`[UserPreferencesManager] setValue error: ${e}`);
    }
  }

  /**
   * 读取数据
   * 使用泛型 T 自动推导返回类型
   */
  async getValue<T extends DataType>(key: string, defaultValue: T): Promise<T> {
    if (!this.pref) {
      console.error('[UserPreferencesManager] Preferences not initialized!');
      return defaultValue;
    }

    try {
      // 获取原始值，如果不存在则返回 defaultValue
      // 注意：这里 defaultValue 如果是对象，需要特殊处理，因为底层get不支持传对象作为默认值
      let distinctDefault: preferences.ValueType;
      if (typeof defaultValue === 'object') {
        distinctDefault = ''; // 占位
      } else {
        distinctDefault = defaultValue as preferences.ValueType;
      }

      const res = await this.pref.get(key, distinctDefault);

      // 检查是否是我们标记的 JSON 对象字符串
      if (typeof res === 'string' && res.startsWith('OBJ_')) {
        const jsonStr = res.substring(4); // 去掉 'OBJ_' 前缀
        return JSON.parse(jsonStr) as T;
      }

      // 如果取出来是空字符串且默认值是对象，说明没取到值，返回默认对象
      if (res === '' && typeof defaultValue === 'object') {
        return defaultValue;
      }

      return res as T;
    } catch (e) {
      console.error(`[UserPreferencesManager] getValue error: ${e}`);
      return defaultValue;
    }
  }

  // 删除当前用户的所有数据
  async deleteUserStore(context: common.UIAbilityContext, userId: string) {
    const storeName = `store_${userId}`;
    try {
      // 先从内存移除
      await preferences.deletePreferences(context, storeName);
      this.pref = null;
      console.info(`[UserPreferencesManager] Store deleted: ${storeName}`);
    } catch (e) {
      console.error(`[UserPreferencesManager] deleteUserStore error: ${e}`);
    }
  }
}
