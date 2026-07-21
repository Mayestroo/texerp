import {
  Injectable,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { DataSource, EntityManager } from 'typeorm';

@Injectable()
export class PlatformDatabase implements OnModuleInit, OnModuleDestroy {
  private readonly adminDataSource: DataSource;

  constructor() {
    this.adminDataSource = new DataSource({
      type: 'postgres',
      url: process.env.DATABASE_ADMIN_URL || process.env.DATABASE_URL,
    });
  }

  async onModuleInit(): Promise<void> {
    if (!this.adminDataSource.isInitialized) {
      await this.adminDataSource.initialize();
    }
  }

  async onModuleDestroy(): Promise<void> {
    if (this.adminDataSource.isInitialized) {
      await this.adminDataSource.destroy();
    }
  }

  async execute<T>(operation: (manager: EntityManager) => Promise<T>): Promise<T> {
    return this.adminDataSource.transaction(async (manager) => {
      return operation(manager);
    });
  }
}
