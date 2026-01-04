#!/usr/bin/env node

/**
 * Bing 历史壁纸元信息获取脚本（改进版）
 *
 * 策略：
 * 1. 解析 bing-wallpaper.md 获取基础数据（日期、英文标题、版权、urlbase）
 * 2. 对于最近 7 天的数据，尝试从 Bing 中文 API 获取完整元信息
 * 3. 对于历史数据（7天前），使用英文版数据
 * 4. 逐步通过每日同步脚本更新为中文版
 *
 * 注意：Bing API 的 idx 参数最大支持 7 天
 */

const fs = require('fs');
const https = require('https');
const path = require('path');

// 配置
const CONFIG = {
  BING_API: 'https://www.bing.com/HPImageArchive.aspx',
  MD_PATH: 'd:/github/bing-wallpaper-main/bing-wallpaper.md',
  OUTPUT_DIR: 'd:/github/nuanXinProPic/bing/meta',
};

/**
 * HTTP GET 请求
 */
function httpGet(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      if (res.statusCode === 301 || res.statusCode === 302) {
        return httpGet(res.headers.location).then(resolve).catch(reject);
      }

      const chunks = [];
      res.on('data', chunk => chunks.push(chunk));
      res.on('end', () => {
        const buffer = Buffer.concat(chunks);
        resolve({ buffer, statusCode: res.statusCode });
      });
      res.on('error', reject);
    }).on('error', reject);
  });
}

/**
 * 尝试从 Bing 中文 API 获取元信息
 * 只适用于最近 7 天
 */
async function tryFetchChineseMetadata(date) {
  const today = new Date();
  const targetDate = new Date(date);
  const diffDays = Math.floor((today - targetDate) / (1000 * 60 * 60 * 24));

  // 超过 7 天，API 无法获取
  if (diffDays > 7) {
    return null;
  }

  try {
    // 尝试多个 idx 值（因为 Bing API 的日期可能有偏差）
    for (let idx = diffDays - 1; idx <= diffDays + 1; idx++) {
      if (idx < 0 || idx > 7) continue;

      const url = `${CONFIG.BING_API}?format=js&idx=${idx}&n=1&mkt=zh-CN`;
      const { buffer, statusCode } = await httpGet(url);

      if (statusCode !== 200) {
        continue;
      }

      const data = JSON.parse(buffer.toString('utf-8'));
      if (data.images && data.images.length > 0) {
        const image = data.images[0];

        // 验证日期是否匹配（前后1天都算匹配，因为时区问题）
        const apiDate = `${image.startdate.substring(0, 4)}-${image.startdate.substring(4, 6)}-${image.startdate.substring(6, 8)}`;
        const targetDateStr = date;
        const targetDateObj = new Date(targetDateStr);
        const apiDateObj = new Date(apiDate);
        const dateDiff = Math.abs((targetDateObj - apiDateObj) / (1000 * 60 * 60 * 24));

        // 允许1天的误差
        if (dateDiff <= 1) {
          return {
            title: image.title,
            copyright: image.copyright,
            copyrightlink: image.copyrightlink,
            quiz: image.quiz,
            hsh: image.hsh,
            urlbase: image.urlbase,
          };
        }
      }
    }
  } catch (e) {
    console.log(`  ⚠️  无法获取 ${date} 的中文元信息: ${e.message}`);
  }

  return null;
}

/**
 * 解析 markdown 文件
 */
function parseMarkdown(filePath) {
  const content = fs.readFileSync(filePath, 'utf-8');
  const lines = content.split('\n');

  const wallpapers = [];

  for (const line of lines) {
    // 匹配格式：2025-12-28 | [title (© copyright)](url)
    const match = line.match(/^(\d{4}-\d{2}-\d{2})\s*\|\s*\[(.+?)\s*\(©\s*(.+?)\)\]\((https:\/\/.+?)\)/);

    if (match) {
      const [, date, title, copyright, url] = match;

      // 从 URL 提取 urlbase
      // URL 格式：https://cn.bing.com/th?id=OHR.SuperiorIceMN_EN-US5952266924_UHD.jpg...
      const urlMatch = url.match(/id=OHR\.([^_]+)_([A-Z]{2}-[A-Z]{2})(\d+)/);

      if (urlMatch) {
        const [, name, locale, id] = urlMatch;
        const urlbase = `/th?id=OHR.${name}_${locale}${id}`;

        wallpapers.push({
          date,
          title: title.trim(),
          copyright: `${title.trim()} (© ${copyright.trim()})`,
          urlbase,
          copyrightlink: '',
          quiz: '',
          hsh: '',
        });
      }
    }
  }

  return wallpapers;
}

/**
 * 按年份分组
 */
function groupByYear(wallpapers) {
  const grouped = {};

  for (const wp of wallpapers) {
    const year = wp.date.substring(0, 4);
    if (!grouped[year]) {
      grouped[year] = [];
    }
    grouped[year].push(wp);
  }

  return grouped;
}

/**
 * 生成元数据文件
 */
async function generateMetadata(wallpapers, outputDir) {
  // 确保输出目录存在
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  console.log('\n尝试获取最近 7 天的中文元信息...');

  // 对于最近 7 天的数据，尝试获取中文版
  const today = new Date();
  let chineseCount = 0;

  for (let i = 0; i < wallpapers.length && i < 10; i++) {
    const wp = wallpapers[i];
    const diffDays = Math.floor((today - new Date(wp.date)) / (1000 * 60 * 60 * 24));

    if (diffDays <= 7) {
      console.log(`  检查 ${wp.date}...`);
      const chineseMeta = await tryFetchChineseMetadata(wp.date);

      if (chineseMeta) {
        // 更新为中文版
        Object.assign(wp, chineseMeta);
        chineseCount++;
        console.log(`    ✓ 已更新为中文版: ${wp.title}`);

        // 添加延迟，避免请求过快
        await new Promise(resolve => setTimeout(resolve, 500));
      }
    } else {
      break;
    }
  }

  console.log(`\n✓ 获取到 ${chineseCount} 条中文元信息\n`);

  // 按年份分组
  const byYear = groupByYear(wallpapers);

  // 生成索引文件
  const years = Object.keys(byYear).sort().reverse().map(year => ({
    year: parseInt(year),
    total: byYear[year].length,
    file: `${year}.json`,
  }));

  const indexData = {
    generatedAt: new Date().toISOString(),
    total: wallpapers.length,
    years,
  };

  fs.writeFileSync(
    path.join(outputDir, 'index.json'),
    JSON.stringify(indexData, null, 2)
  );

  console.log(`Generated index.json (${wallpapers.length} total wallpapers)`);

  // 生成每年的元数据文件
  for (const [year, items] of Object.entries(byYear)) {
    const yearData = {
      year: parseInt(year),
      total: items.length,
      items: items.sort((a, b) => b.date.localeCompare(a.date)), // 降序
    };

    fs.writeFileSync(
      path.join(outputDir, `${year}.json`),
      JSON.stringify(yearData, null, 2)
    );

    console.log(`Generated ${year}.json (${items.length} items)`);
  }
}

/**
 * 主函数
 */
async function main() {
  console.log('========================================');
  console.log('  Bing 历史壁纸导入（改进版）');
  console.log('========================================\n');

  console.log('解析 bing-wallpaper.md...');
  const wallpapers = parseMarkdown(CONFIG.MD_PATH);

  console.log(`找到 ${wallpapers.length} 张壁纸`);
  console.log(`日期范围: ${wallpapers[wallpapers.length - 1].date} 至 ${wallpapers[0].date}\n`);

  console.log('生成元数据文件...');
  await generateMetadata(wallpapers, CONFIG.OUTPUT_DIR);

  console.log('\n✅ 完成！\n');
  console.log('说明：');
  console.log('1. 最近 7 天的数据已更新为中文版（如果 API 可用）');
  console.log('2. 历史数据（7天前）使用英文版');
  console.log('3. 后续通过每日同步脚本会自动更新为中文版');
  console.log('4. copyrightlink, quiz, hsh 仅中文版有效\n');
}

main().catch(console.error);
