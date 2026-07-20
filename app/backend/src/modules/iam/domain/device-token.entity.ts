import { Entity, PrimaryColumn, Column } from 'typeorm';

@Entity('device_tokens')
export class DeviceToken {
  @PrimaryColumn('uuid')
  id!: string;

  @Column('uuid')
  tenant_id!: string;

  @Column('uuid')
  user_id!: string;

  @Column({ length: 500 })
  fcm_token!: string;

  @Column({ type: 'varchar', length: 10 })
  platform!: 'ANDROID' | 'IOS';

  @Column({ default: true })
  is_active!: boolean;

  @Column('timestamptz')
  registered_at!: Date;

  @Column('timestamptz')
  last_used_at!: Date;
}
