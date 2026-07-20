import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

@Injectable()
export class StorageService implements OnModuleInit {
  private client: S3Client | null = null;
  private bucket!: string;

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    const endpoint = this.config.get<string>('S3_ENDPOINT');
    const bucket = this.config.get<string>('S3_BUCKET');
    const accessKeyId = this.config.get<string>('S3_ACCESS_KEY_ID');
    const secretAccessKey = this.config.get<string>('S3_SECRET_ACCESS_KEY');
    const region = this.config.get<string>('S3_REGION') ?? 'us-east-1';

    if (!bucket) {
      console.warn('S3 bucket config missing. Storage will be stubbed.');
      return;
    }

    this.bucket = bucket;

    if (!endpoint || !accessKeyId || !secretAccessKey) {
      console.warn('S3 credentials missing. Storage will be stubbed.');
      return;
    }

    try {
      const forcePathStyle = this.config.get<string>('S3_FORCE_PATH_STYLE') === 'false' ? false : true;
      this.client = new S3Client({
        endpoint,
        region,
        credentials: {
          accessKeyId,
          secretAccessKey,
        },
        forcePathStyle,
      });
    } catch (error) {
      console.error('Failed to initialize S3 client. Storage will be stubbed:', error);
    }
  }

  async uploadFile(
    tenantId: string,
    fileName: string,
    fileBuffer: Buffer,
    contentType: string,
  ): Promise<{ key: string; sizeBytes: number }> {
    const key = `exports/${tenantId}/${fileName}`;

    if (!this.client) {
      console.log(`[Storage Mock] Uploading file to ${key} (${fileBuffer.length} bytes)`);
      return { key, sizeBytes: fileBuffer.length };
    }

    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: fileBuffer,
        ContentType: contentType,
      }),
    );

    return { key, sizeBytes: fileBuffer.length };
  }

  async getSignedUrl(tenantId: string, key: string, expiresInSeconds = 900): Promise<string> {
    if (!this.client) {
      return `https://storage.mock-texerp.uz/${key}`;
    }

    const command = new GetObjectCommand({
      Bucket: this.bucket,
      Key: key,
    });

    return getSignedUrl(this.client, command, { expiresIn: expiresInSeconds });
  }
}
