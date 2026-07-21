import { execSync } from 'child_process';
import { S3Client, PutObjectCommand, ListObjectsV2Command, DeleteObjectCommand } from '@aws-sdk/client-s3';
import * as fs from 'fs';
import * as path from 'path';

async function performBackup() {
  const dbUrl = process.env.DATABASE_URL || 'postgresql://texerp:texerp@localhost:5432/texerp';
  const bucketName = process.env.BACKUP_S3_BUCKET || 'texerp-database-backups';
  const region = process.env.AWS_REGION || 'us-east-1';

  console.log('📦 Starting PostgreSQL Database Backup...');

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const tempDir = path.join(__dirname, '../tmp');
  if (!fs.existsSync(tempDir)) {
    fs.mkdirSync(tempDir, { recursive: true });
  }

  const dumpFileName = `texerp-db-backup-${timestamp}.sql.gz`;
  const dumpFilePath = path.join(tempDir, dumpFileName);

  try {
    // 1. Run pg_dump and compress
    console.log(`Executing pg_dump to ${dumpFilePath}...`);
    execSync(`pg_dump "${dbUrl}" | gzip > "${dumpFilePath}"`, { stdio: 'inherit' });

    const fileBuffer = fs.readFileSync(dumpFilePath);
    console.log(`Dump generated successfully. File size: ${(fileBuffer.length / (1024 * 1024)).toFixed(2)} MB`);

    // 2. Upload to S3 if credentials exist
    if (process.env.AWS_ACCESS_KEY_ID && process.env.AWS_SECRET_ACCESS_KEY) {
      const s3Client = new S3Client({ region });
      const s3Key = `daily-dumps/${dumpFileName}`;

      console.log(`Uploading dump to s3://${bucketName}/${s3Key}...`);
      await s3Client.send(
        new PutObjectCommand({
          Bucket: bucketName,
          Key: s3Key,
          Body: fileBuffer,
          ContentType: 'application/gzip',
        }),
      );
      console.log('✅ Upload to S3 completed successfully.');

      // 3. Prune backups older than 30 days
      console.log('🧹 Pruning S3 backups older than 30 days...');
      const listCommand = new ListObjectsV2Command({ Bucket: bucketName, Prefix: 'daily-dumps/' });
      const listResult = await s3Client.send(listCommand);

      const thirtyDaysAgo = Date.now() - 30 * 24 * 60 * 60 * 1000;
      if (listResult.Contents) {
        for (const item of listResult.Contents) {
          if (item.LastModified && item.LastModified.getTime() < thirtyDaysAgo && item.Key) {
            console.log(`Deleting old backup: ${item.Key}`);
            await s3Client.send(new DeleteObjectCommand({ Bucket: bucketName, Key: item.Key }));
          }
        }
      }
    } else {
      console.log('⚠️ AWS credentials not provided in ENV. Backup saved locally at:', dumpFilePath);
    }
  } catch (error) {
    console.error('❌ Backup failed:', error);
    process.exit(1);
  } finally {
    if (fs.existsSync(dumpFilePath)) {
      fs.unlinkSync(dumpFilePath);
    }
  }
}

performBackup();
