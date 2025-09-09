from flask import Flask, request, jsonify, send_file, Response
from flask_cors import CORS
import io
import base64
from PIL import Image
import os
import uuid
from datetime import datetime
import logging
import requests
import json
import random
import re
import time

# 导入配置和路由
from config import FLASK_HOST, FLASK_PORT, FLASK_DEBUG
from routes.analytics import analytics_bp
from routes.auth import auth_bp
from database import db



# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app, supports_credentials=True)  # 允许跨域请求，支持凭证





# ModelScope API配置
API_BASE_URL = 'https://api-inference.modelscope.cn/'
API_KEY = "ms-573a149f-6c76-4319-9fd1-808fab2c670d"  # ModelScope Token

COMMON_HEADERS = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json",
}

# DeepSeek API配置
DEEPSEEK_API_URL = "https://api.deepseek.com/v1/chat/completions"
DEEPSEEK_API_KEY = "sk-6f74eb75ae27434aad871a3bb5d6e281"

DEEPSEEK_HEADERS = {
    "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
    "Content-Type": "application/json",
}

# 图像比例配置
ASPECT_RATIOS = {
    "1:1": (1328, 1328),
    "16:9": (1664, 928),
    "9:16": (928, 1664),
    "4:3": (1472, 1140),
    "3:4": (1140, 1472),
    "3:2": (1584, 1056),
    "2:3": (1056, 1584)
}

# 中英文优化后缀
POSITIVE_MAGIC = {
    "en": ", Ultra HD, 4K, cinematic composition.",
    "zh": ", 超清，4K，电影级构图."
}

def check_api_config():
    """检查API配置"""
    if API_KEY == "your-api-key-here" or not API_KEY:
        logger.warning("请配置有效的API密钥")
        return False
    return True

def generate_image_via_api(prompt, aspect_ratio="1:1", num_inference_steps=20, guidance_scale=7.5):
    """通过ModelScope API生成图像，带重试机制"""
    if not check_api_config():
        return None, "API配置无效，请检查API密钥"
    
    # 重试配置
    max_retries = 3
    retry_delay = 2  # 秒
    
    for retry_count in range(max_retries):
        try:
            if retry_count > 0:
                logger.info(f"第 {retry_count + 1} 次尝试生成图像...")
                time.sleep(retry_delay * retry_count)  # 递增延迟
            
            # 发起异步图像生成请求
            response = requests.post(
                f"{API_BASE_URL}v1/images/generations",
                headers={**COMMON_HEADERS, "X-ModelScope-Async-Mode": "true"},
                data=json.dumps({
                    "model": "Qwen/Qwen-Image",  # ModelScope Model-Id
                    "prompt": prompt
                }, ensure_ascii=False).encode('utf-8'),
                timeout=30  # 添加超时
            )
            
            response.raise_for_status()
            task_id = response.json()["task_id"]
            logger.info(f"图像生成任务已提交，任务ID: {task_id}")
            
            # 轮询任务状态
            max_attempts = 60  # 最多等待5分钟
            attempt = 0
            
            while attempt < max_attempts:
                try:
                    result = requests.get(
                        f"{API_BASE_URL}v1/tasks/{task_id}",
                        headers={**COMMON_HEADERS, "X-ModelScope-Task-Type": "image_generation"},
                        timeout=10
                    )
                    result.raise_for_status()
                    data = result.json()
                    
                    logger.info(f"任务状态检查 {attempt + 1}/{max_attempts}: {data.get('task_status', 'UNKNOWN')}")
                    
                    if data["task_status"] == "SUCCEED":
                        # 下载生成的图像
                        image_url = data["output_images"][0]
                        logger.info(f"图像生成成功，下载URL: {image_url}")
                        
                        img_response = requests.get(image_url, timeout=30)
                        img_response.raise_for_status()
                        
                        # 转换为base64
                        img_base64 = base64.b64encode(img_response.content).decode('utf-8')
                        return img_base64, None
                    
                    elif data["task_status"] == "FAILED":
                        error_msg = data.get("error", "图像生成失败")
                        logger.error(f"图像生成失败: {error_msg}")
                        break  # 跳出状态检查循环，进入重试
                    
                    attempt += 1
                    time.sleep(5)  # 等待5秒后重试
                
                except requests.exceptions.RequestException as e:
                    logger.warning(f"状态检查请求失败: {e}")
                    attempt += 1
                    time.sleep(5)
                    continue
            
            # 如果到这里说明任务失败或超时，尝试重试
            if retry_count < max_retries - 1:
                logger.warning(f"第 {retry_count + 1} 次尝试失败，准备重试...")
                continue
            else:
                return None, "图像生成超时或失败，请稍后重试"
                
        except requests.exceptions.RequestException as e:
            logger.error(f"网络请求错误 (尝试 {retry_count + 1}/{max_retries}): {e}")
            if retry_count < max_retries - 1:
                continue
            return None, f"网络请求错误: {str(e)}"
        except Exception as e:
            logger.error(f"API调用错误 (尝试 {retry_count + 1}/{max_retries}): {e}")
            if retry_count < max_retries - 1:
                continue
            return None, f"生成失败: {str(e)}"
    
    return None, "所有重试均失败，请稍后再试"

def detect_language(text):
    """简单的语言检测"""
    # 检测中文字符
    chinese_chars = sum(1 for char in text if '\u4e00' <= char <= '\u9fff')
    total_chars = len(text.replace(' ', ''))
    
    if total_chars == 0:
        return "en"
    
    # 如果中文字符占比超过30%，认为是中文
    if chinese_chars / total_chars > 0.3:
        return "zh"
    else:
        return "en"

@app.route('/health', methods=['GET'])
def health_check():
    """健康检查端点"""
    return jsonify({
        'status': 'healthy',
        'model_loaded': True,
        'message': 'Flask服务器运行正常',
        'timestamp': datetime.now().isoformat()
    })

@app.route('/test-new-route', methods=['GET'])
def test_new_route():
    """全新的测试路由"""
    # 触发自动重载测试
    return jsonify({
        'message': 'This is a brand new route!',
        'timestamp': datetime.now().isoformat()
    })

@app.route('/generate', methods=['POST'])
def generate_image():
    """图像生成API端点"""
    try:
        # 获取请求参数
        data = request.get_json()
        if not data:
            return jsonify({
                'error': '请求参数不能为空',
                'success': False
            }), 400
        
        prompt = data.get('prompt', '').strip()
        if not prompt:
            return jsonify({
                'error': '提示词不能为空',
                'success': False
            }), 400
        
        aspect_ratio = data.get('aspect_ratio', '16:9')
        negative_prompt = data.get('negative_prompt', '')
        num_inference_steps = data.get('num_inference_steps', 50)
        true_cfg_scale = data.get('true_cfg_scale', 4.0)
        seed = data.get('seed', None)
        
        # 验证比例参数
        if aspect_ratio not in ASPECT_RATIOS:
            return jsonify({
                'error': f'不支持的图像比例: {aspect_ratio}',
                'success': False
            }), 400
        
        # 检测语言并添加优化后缀
        lang = detect_language(prompt)
        optimized_prompt = prompt + POSITIVE_MAGIC[lang]
        
        logger.info(f"开始生成图像 - 提示词: {prompt[:50]}...")
        logger.info(f"参数: aspect_ratio: {aspect_ratio}, steps: {num_inference_steps}, cfg: {true_cfg_scale}")
        
        # 通过API生成图像
        image_base64, error = generate_image_via_api(
            optimized_prompt,
            aspect_ratio,
            num_inference_steps,
            true_cfg_scale
        )
        
        if error:
            return jsonify({
                'error': error,
                'success': False
            }), 500
        
        # 生成唯一文件名
        filename = f"qwen_image_{uuid.uuid4().hex[:8]}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
        
        logger.info("图像生成成功！")
        
        return jsonify({
            'success': True,
            'image_base64': image_base64,
            'filename': filename,
            'prompt': prompt,
            'optimized_prompt': optimized_prompt,
            'parameters': {
                'aspect_ratio': aspect_ratio,
                'num_inference_steps': num_inference_steps,
                'true_cfg_scale': true_cfg_scale,
                'seed': seed
            },
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        logger.error(f"图像生成失败: {str(e)}")
        return jsonify({
            'error': f'图像生成失败: {str(e)}',
            'success': False
        }), 500

@app.route('/download/<filename>', methods=['GET'])
def download_image(filename):
    """图像下载端点（如果需要文件下载功能）"""
    # 这里可以实现文件下载逻辑
    # 目前主要通过base64返回图像数据
    return jsonify({
        'error': '请使用base64数据下载图像',
        'success': False
    }), 404

def generate_learning_path_with_deepseek_stream(subject, level, time_available, goal, preferences=""):
    """使用DeepSeek API流式生成个性化学习路径"""
    try:
        # 构建完整的提示词，支持联网搜索
        prompt = f"""
你是一位世界顶级的个性化学习规划专家，拥有丰富的教育心理学和认知科学背景。请为用户制定一份科学、实用、高度个性化的学习路径。

**重要：请使用你的联网搜索功能，查找并提供真实存在的、当前可访问的课程和学习资源链接。所有资源必须是真实有效的，不允许使用虚构或示例链接。**

## 用户画像分析
- 🎯 学习领域：{subject}
- 📊 当前水平：{level}
- ⏰ 时间投入：{time_available}
- 🚀 学习目标：{goal}
- 💡 学习偏好：{preferences if preferences else '暂无特殊偏好，请根据领域特点推荐最佳学习方式'}

## 任务要求
请基于认知负荷理论、间隔重复原理和刻意练习方法，设计一份循序渐进的学习路径：

### 路径设计原则：
1. **认知递进**：从具体到抽象，从简单到复杂
2. **实践导向**：理论与实践并重，每个阶段都有动手环节
3. **资源真实性**：**必须通过联网搜索验证所有资源链接的真实性和可访问性**
4. **时间科学**：根据用户时间合理分配学习强度
5. **反馈机制**：每阶段都有明确的检验标准

### 输出格式要求：
请严格按照以下JSON结构返回，确保数据完整且格式正确：

```json
{{
  "overview": "简洁有力的学习路径总览，说明整体学习策略和预期成果",
  "total_duration": "基于用户时间投入的总预计用时（如：6-8周）",
  "difficulty_level": "整体难度评估（beginner/intermediate/advanced）",
  "stages": [
    {{
      "title": "阶段名称（体现核心学习内容）",
      "duration": "该阶段预计用时",
      "description": "详细描述该阶段的学习重点、方法和预期成果",
      "learning_objectives": ["具体的学习目标1", "具体的学习目标2", "具体的学习目标3"],
      "resources": [
        {{
          "title": "资源名称",
          "type": "video/course/article/book/practice/project/tool",
          "url": "具体的资源链接（优先知名平台）",
          "description": "资源特点和学习价值说明",
          "estimated_time": "预计学习时长",
          "difficulty": "easy/medium/hard"
        }}
      ],
      "practice_projects": [
        {{
          "title": "实践项目名称",
          "description": "项目详细描述和学习价值",
          "estimated_time": "预计完成时间",
          "skills_practiced": ["技能1", "技能2"]
        }}
      ],
      "assessment_criteria": ["评估标准1", "评估标准2"]
    }}
  ],
  "additional_resources": [
    {{
      "title": "补充资源名称",
      "type": "community/tool/reference",
      "url": "资源链接",
      "description": "资源用途说明"
    }}
  ],
  "success_metrics": ["成功指标1", "成功指标2", "成功指标3"]
}}
```

**再次强调：所有URL必须是真实有效的链接，请通过联网搜索验证每个资源的可访问性。**
        """
        
        payload = {
            "model": "deepseek-chat",  # 使用deepseek-chat模型
            "messages": [
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            "stream": True,  # 启用流式输出
            "temperature": 0.7,
            "max_tokens": 4000
        }
        
        # 发送思考开始信号
        yield {'type': 'thinking', 'message': '🤖 DeepSeek AI开始深度思考...'}
        time.sleep(0.5)
        
        yield {'type': 'thinking', 'message': '🔍 正在联网搜索最新学习资源...'}
        time.sleep(1.0)
        
        yield {'type': 'thinking', 'message': '📚 分析认知科学理论应用...'}
        time.sleep(0.8)
        
        yield {'type': 'thinking', 'message': '⚡ 构建个性化学习策略...'}
        time.sleep(0.8)
        
        # 调用DeepSeek API
        response = requests.post(
            DEEPSEEK_API_URL,
            headers=DEEPSEEK_HEADERS,
            json=payload,
            timeout=120,  # 增加超时时间
            stream=True
        )
        
        if response.status_code == 200:
            content_buffer = ""
            thinking_messages = [
                '💡 AI正在整合多维度学习理论...',
                '🎯 优化学习路径的认知负荷分布...',
                '📋 验证学习资源的真实性和有效性...',
                '🚀 调整学习节奏和实践项目难度...',
                '✨ 完善个性化推荐算法...',
                '🔧 优化学习反馈机制设计...'
            ]
            
            message_index = 0
            chunk_count = 0
            
            for line in response.iter_lines():
                if line:
                    line = line.decode('utf-8')
                    if line.startswith('data: '):
                        chunk_count += 1
                        
                        # 每处理几个chunk就发送一个思考消息
                        if chunk_count % 3 == 0 and message_index < len(thinking_messages):
                            yield {'type': 'thinking', 'message': thinking_messages[message_index]}
                            message_index += 1
                            time.sleep(0.6)
                        
                        data = line[6:]  # 移除'data: '前缀
                        if data.strip() == '[DONE]':
                            break
                        
                        try:
                            chunk_data = json.loads(data)
                            if 'choices' in chunk_data and len(chunk_data['choices']) > 0:
                                delta = chunk_data['choices'][0].get('delta', {})
                                if 'content' in delta:
                                    content_buffer += delta['content']
                        except json.JSONDecodeError:
                            continue
            
            # 发送最终思考消息
            yield {'type': 'thinking', 'message': '🎉 学习路径生成即将完成...'}
            time.sleep(0.5)
            
            # 解析完整响应
            if content_buffer:
                # 清理markdown代码块标记
                content_buffer = re.sub(r'^```json\s*', '', content_buffer, flags=re.MULTILINE)
                content_buffer = re.sub(r'\s*```$', '', content_buffer, flags=re.MULTILINE)
                content_buffer = content_buffer.strip()
                
                # 尝试提取JSON部分
                json_content = None
                
                # 方法1: 寻找第一个{到最后一个}的内容
                first_brace = content_buffer.find('{')
                last_brace = content_buffer.rfind('}')
                
                if first_brace != -1 and last_brace != -1 and last_brace > first_brace:
                    json_content = content_buffer[first_brace:last_brace+1]
                    
                    try:
                        learning_path = json.loads(json_content)
                        yield {'type': 'complete', 'data': learning_path}
                    except json.JSONDecodeError as e:
                        # 方法2: 如果直接解析失败，尝试修复常见的JSON格式问题
                        try:
                            # 移除可能的多余文本
                            lines = content_buffer.split('\n')
                            json_lines = []
                            in_json = False
                            brace_count = 0
                            
                            for line in lines:
                                if '{' in line and not in_json:
                                    in_json = True
                                    json_lines.append(line[line.find('{'):])
                                    brace_count += line.count('{') - line.count('}')
                                elif in_json:
                                    json_lines.append(line)
                                    brace_count += line.count('{') - line.count('}')
                                    if brace_count <= 0:
                                        break
                            
                            if json_lines:
                                json_content = '\n'.join(json_lines)
                                learning_path = json.loads(json_content)
                                yield {'type': 'complete', 'data': learning_path}
                            else:
                                raise json.JSONDecodeError("无法找到有效的JSON内容", content_buffer, 0)
                                
                        except json.JSONDecodeError as e2:
                            logger.error(f"JSON解析错误: {e2}")
                            logger.error(f"原始内容: {content_buffer[:500]}...")
                            # 返回原始内容作为文本响应
                            yield {'type': 'content', 'content': content_buffer}
                            yield {'type': 'complete', 'message': '学习路径生成完成（文本格式）'}
                else:
                    logger.error("未找到有效的JSON结构")
                    logger.error(f"原始内容: {content_buffer[:500]}...")
                    # 返回原始内容作为文本响应
                    yield {'type': 'content', 'content': content_buffer}
                    yield {'type': 'complete', 'message': '学习路径生成完成（文本格式）'}
            else:
                yield {'type': 'error', 'message': 'AI响应内容为空'}
        else:
            error_msg = f"DeepSeek API调用失败，状态码: {response.status_code}"
            logger.error(error_msg)
            yield {'type': 'error', 'message': error_msg}
            
    except requests.exceptions.Timeout:
        error_msg = "DeepSeek API调用超时，请稍后重试"
        logger.error(error_msg)
        yield {'type': 'error', 'message': error_msg}
    except Exception as e:
        error_msg = f"生成学习路径时发生错误: {str(e)}"
        logger.error(error_msg)
        yield {'type': 'error', 'message': error_msg}

def generate_learning_path_with_deepseek(subject, level, time_available, goal, preferences=""):
    """使用DeepSeek API生成个性化学习路径"""
    try:
        # 构建完整的提示词，支持联网搜索
        prompt = f"""
你是一位世界顶级的个性化学习规划专家，拥有丰富的教育心理学和认知科学背景。请为用户制定一份科学、实用、高度个性化的学习路径。

**重要：请使用你的联网搜索功能，查找并提供真实存在的、当前可访问的课程和学习资源链接。所有资源必须是真实有效的，不允许使用虚构或示例链接。**

## 用户画像分析
- 🎯 学习领域：{subject}
- 📊 当前水平：{level}
- ⏰ 时间投入：{time_available}
- 🚀 学习目标：{goal}
- 💡 学习偏好：{preferences if preferences else '暂无特殊偏好，请根据领域特点推荐最佳学习方式'}

## 任务要求
请基于认知负荷理论、间隔重复原理和刻意练习方法，设计一份循序渐进的学习路径：

### 路径设计原则：
1. **认知递进**：从具体到抽象，从简单到复杂
2. **实践导向**：理论与实践并重，每个阶段都有动手环节
3. **资源真实性**：**必须通过联网搜索验证所有资源链接的真实性和可访问性**
4. **时间科学**：根据用户时间合理分配学习强度
5. **反馈机制**：每阶段都有明确的检验标准

### 输出格式要求：
请严格按照以下JSON结构返回，确保数据完整且格式正确：

```json
{{
  "overview": "简洁有力的学习路径总览，说明整体学习策略和预期成果",
  "total_duration": "基于用户时间投入的总预计用时（如：6-8周）",
  "difficulty_level": "整体难度评估（beginner/intermediate/advanced）",
  "stages": [
    {{
      "title": "阶段名称（体现核心学习内容）",
      "duration": "该阶段预计用时",
      "description": "详细描述该阶段的学习重点、方法和预期成果",
      "learning_objectives": ["具体的学习目标1", "具体的学习目标2", "具体的学习目标3"],
      "resources": [
        {{
          "title": "资源名称",
          "type": "video/course/article/book/practice/project/tool",
          "url": "具体的资源链接（优先知名平台）",
          "description": "资源特点和学习价值说明",
          "estimated_time": "预计学习时长",
          "difficulty": "easy/medium/hard"
        }}
      ],
      "milestone": "该阶段完成标志和自检方法",
      "tips": "学习建议和注意事项"
    }}
  ],
  "success_metrics": "整体学习成功的衡量标准",
  "next_steps": "完成此路径后的进阶建议"
}}
```

## 特别要求：
**🔍 联网搜索要求（必须执行）：**
- **必须使用联网搜索功能**查找当前可用的真实课程和学习资源
- **验证所有链接的有效性**，确保用户可以直接访问
- 优先搜索并推荐：Coursera、edX、Udemy、YouTube、GitHub、官方文档、知名大学公开课等
- **禁止使用任何虚构、示例或占位符链接**

**📚 资源质量要求：**
- 每个阶段至少包含3-5个不同类型的真实学习资源
- 根据用户水平调整起点，避免过于简单或困难
- 考虑学习曲线，合理安排难度递增
- 提供具体的实践项目和练习建议
- 所有推荐的课程、教程、工具都必须是当前可访问的

**⚠️ 重要提醒：如果无法进行联网搜索或验证链接，请在资源描述中明确说明这是基于知识库的推荐，并建议用户自行验证链接有效性。**

请直接返回JSON格式的学习路径，不要包含任何解释文字。
        """

        # 调用DeepSeek API (使用chat模型)
        payload = {
            "model": "deepseek-chat",
            "messages": [
                {
                    "role": "system",
                    "content": "你是一个专业的学习规划助手，擅长为用户制定个性化的学习计划。请始终以JSON格式返回结构化的学习路径。"
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            "temperature": 0.7,
            "max_tokens": 4000
        }

        # 增加超时时间并添加重试机制
        max_retries = 2
        for attempt in range(max_retries + 1):
            try:
                response = requests.post(
                    DEEPSEEK_API_URL,
                    headers=DEEPSEEK_HEADERS,
                    json=payload,
                    timeout=60  # 增加到60秒
                )
                break  # 成功则跳出重试循环
            except requests.exceptions.Timeout as e:
                if attempt < max_retries:
                    logger.warning(f"DeepSeek API超时，正在重试 ({attempt + 1}/{max_retries})...")
                    time.sleep(2)  # 等待2秒后重试
                    continue
                else:
                    logger.error(f"DeepSeek API多次超时失败: {str(e)}")
                    raise Exception("AI服务响应超时，请稍后重试")
            except Exception as e:
                logger.error(f"DeepSeek API请求异常: {str(e)}")
                raise e

        if response.status_code == 200:
            result = response.json()
            content = result['choices'][0]['message']['content']
            
            # 尝试解析JSON
            try:
                # 清理可能的markdown代码块标记
                content = content.strip()
                if content.startswith('```json'):
                    content = content[7:]
                if content.endswith('```'):
                    content = content[:-3]
                content = content.strip()
                
                learning_path = json.loads(content)
                return learning_path
            except json.JSONDecodeError as e:
                logger.error(f"JSON解析失败: {e}, 原始内容: {content}")
                raise Exception(f"AI返回的数据格式错误，无法解析学习路径")
        else:
            logger.error(f"DeepSeek API请求失败: {response.status_code}, {response.text}")
            raise Exception(f"AI服务暂时不可用，请稍后重试")
            
    except Exception as e:
        logger.error(f"生成学习路径失败: {str(e)}")
        raise e



def adjust_learning_path_with_deepseek(original_path, completed_stages, feedback, difficulty_feedback="", time_feedback=""):
    """使用DeepSeek API调整学习路径"""
    try:
        # 构建调整提示词
        prompt = f"""
你是一名经验丰富的学习规划导师。用户已经开始了学习路径，现在需要根据学习进度和反馈来调整后续的学习计划。

原始学习路径：
{json.dumps(original_path, ensure_ascii=False, indent=2)}

用户反馈信息：
- 已完成阶段：{completed_stages}
- 学习反馈：{feedback}
- 难度反馈：{difficulty_feedback if difficulty_feedback else '无'}
- 时间反馈：{time_feedback if time_feedback else '无'}

请根据用户的学习进度和反馈，调整后续的学习路径。调整原则：
1. 保持已完成的阶段不变
2. 根据难度反馈调整后续阶段的难度和内容
3. 根据时间反馈调整后续阶段的时间安排
4. 根据学习反馈优化学习资源和方法
5. 确保调整后的路径更符合用户的实际情况

请以JSON格式返回调整后的完整学习路径，结构与原路径相同：
{{
  "overview": "调整后的学习路径总览",
  "total_duration": "调整后的总预计用时",
  "adjustment_summary": "本次调整的主要变化说明",
  "stages": [
    {{
      "title": "阶段标题",
      "duration": "预计用时",
      "description": "阶段详细描述",
      "status": "completed/current/upcoming",
      "resources": [
        {{
          "title": "资源标题",
          "type": "资源类型",
          "url": "资源链接",
          "description": "资源描述"
        }}
      ]
    }}
  ]
}}

请确保返回的是有效的JSON格式，不要包含任何其他文本。
        """

        # 调用DeepSeek API
        payload = {
            "model": "deepseek-chat",
            "messages": [
                {
                    "role": "system",
                    "content": "你是一个专业的学习规划助手，擅长根据用户反馈调整学习计划。请始终以JSON格式返回结构化的学习路径。"
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            "temperature": 0.7,
            "max_tokens": 4000
        }

        response = requests.post(
            DEEPSEEK_API_URL,
            headers=DEEPSEEK_HEADERS,
            json=payload,
            timeout=30
        )

        if response.status_code == 200:
            result = response.json()
            content = result['choices'][0]['message']['content']
            
            # 尝试解析JSON
            try:
                # 清理可能的markdown代码块标记
                content = content.strip()
                if content.startswith('```json'):
                    content = content[7:]
                if content.endswith('```'):
                    content = content[:-3]
                content = content.strip()
                
                adjusted_path = json.loads(content)
                return adjusted_path
            except json.JSONDecodeError as e:
                logger.error(f"JSON解析失败: {e}, 原始内容: {content}")
                # 如果JSON解析失败，返回原始路径并添加调整说明
                original_path["adjustment_summary"] = "调整失败，保持原计划"
                return original_path
        else:
            logger.error(f"DeepSeek API请求失败: {response.status_code}, {response.text}")
            original_path["adjustment_summary"] = "调整失败，保持原计划"
            return original_path
            
    except Exception as e:
        logger.error(f"调整学习路径失败: {str(e)}")
        original_path["adjustment_summary"] = "调整失败，保持原计划"
        return original_path

@app.route('/generate_learning_path', methods=['POST'])
def generate_learning_path():
    """生成个性化学习路径"""
    try:
        data = request.get_json()
        
        # 验证必需字段
        required_fields = ['subject', 'level', 'timeAvailable', 'goal']
        for field in required_fields:
            if not data.get(field):
                return jsonify({
                    "success": False, 
                    "error": f"缺少必需字段: {field}"
                }), 400
        
        subject = data['subject']
        level = data['level']
        time_available = data['timeAvailable']
        goal = data['goal']
        preferences = data.get('preferences', '')
        
        logger.info(f"生成学习路径请求: {subject}, {level}, {time_available}")
        
        # 生成学习路径
        learning_path = generate_learning_path_with_deepseek(
            subject, level, time_available, goal, preferences
        )
        
        return jsonify({
            "success": True,
            "learning_path": learning_path
        })
        
    except Exception as e:
        logger.error(f"生成学习路径失败: {str(e)}")
        return jsonify({
            "success": False,
            "error": "生成学习路径时发生错误，请稍后重试"
        }), 500

@app.route('/generate_learning_path_stream', methods=['POST'])
def generate_learning_path_stream():
    """流式生成个性化学习路径的API端点"""
    try:
        data = request.get_json()
        
        # 验证必需字段
        required_fields = ['subject', 'level', 'timeAvailable', 'goal']
        for field in required_fields:
            if not data.get(field):
                return jsonify({
                    "success": False, 
                    "error": f"缺少必需字段: {field}"
                }), 400
        
        subject = data['subject']
        level = data['level']
        time_available = data['timeAvailable']
        goal = data['goal']
        preferences = data.get('preferences', '')
        
        def generate_stream():
            try:
                # 发送开始信号
                yield f"data: {json.dumps({'type': 'start', 'message': '🤔 开始分析您的学习需求...'}, ensure_ascii=False)}\n\n"
                time.sleep(0.5)
                
                # 发送分析阶段信息
                yield f"data: {json.dumps({'type': 'thinking', 'message': f'📚 正在分析学习领域：{subject}'}, ensure_ascii=False)}\n\n"
                time.sleep(0.8)
                
                yield f"data: {json.dumps({'type': 'thinking', 'message': f'📊 评估当前水平：{level}'}, ensure_ascii=False)}\n\n"
                time.sleep(0.8)
                
                yield f"data: {json.dumps({'type': 'thinking', 'message': f'⏰ 规划时间安排：{time_available}'}, ensure_ascii=False)}\n\n"
                time.sleep(0.8)
                
                yield f"data: {json.dumps({'type': 'thinking', 'message': f'🎯 明确学习目标：{goal}'}, ensure_ascii=False)}\n\n"
                time.sleep(0.8)
                
                if preferences:
                    yield f"data: {json.dumps({'type': 'thinking', 'message': f'💡 考虑学习偏好：{preferences}'}, ensure_ascii=False)}\n\n"
                    time.sleep(0.8)
                
                # 发送AI思考过程
                yield f"data: {json.dumps({'type': 'thinking', 'message': '🧠 正在运用认知科学理论设计学习路径...'}, ensure_ascii=False)}\n\n"
                time.sleep(1.0)
                
                yield f"data: {json.dumps({'type': 'thinking', 'message': '🔍 搜索最新的优质学习资源...'}, ensure_ascii=False)}\n\n"
                time.sleep(1.2)
                
                yield f"data: {json.dumps({'type': 'thinking', 'message': '📋 构建循序渐进的学习阶段...'}, ensure_ascii=False)}\n\n"
                time.sleep(1.0)
                
                yield f"data: {json.dumps({'type': 'thinking', 'message': '⚡ 优化学习效率和实践项目...'}, ensure_ascii=False)}\n\n"
                time.sleep(1.0)
                
                # 调用AI生成学习路径（流式）
                yield f"data: {json.dumps({'type': 'generating', 'message': '🚀 AI正在生成您的专属学习路径...'}, ensure_ascii=False)}\n\n"
                
                # 流式调用DeepSeek API
                for chunk in generate_learning_path_with_deepseek_stream(
                    subject, level, time_available, goal, preferences
                ):
                    if chunk['type'] == 'thinking':
                        yield f"data: {json.dumps(chunk, ensure_ascii=False)}\n\n"
                    elif chunk['type'] == 'complete':
                        # 安全地获取data字段
                        chunk_data = chunk.get('data', chunk.get('content', '学习路径生成完成'))
                        yield f"data: {json.dumps({'type': 'complete', 'message': '✅ 学习路径生成完成！', 'data': chunk_data}, ensure_ascii=False)}\n\n"
                        break
                    elif chunk['type'] == 'content':
                        # 处理内容类型的chunk
                        yield f"data: {json.dumps({'type': 'content', 'message': '📝 正在生成学习内容...', 'content': chunk.get('content', '')}, ensure_ascii=False)}\n\n"
                    elif chunk['type'] == 'error':
                        yield f"data: {json.dumps(chunk, ensure_ascii=False)}\n\n"
                        break
                
            except Exception as e:
                logger.error(f"流式生成学习路径时发生错误: {str(e)}")
                yield f"data: {json.dumps({'type': 'error', 'message': f'生成过程中出现错误: {str(e)}'}, ensure_ascii=False)}\n\n"
        
        return Response(
            generate_stream(),
            mimetype='text/event-stream',
            headers={
                'Cache-Control': 'no-cache',
                'Connection': 'keep-alive',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            }
        )
        
    except Exception as e:
        logger.error(f"流式生成学习路径时发生错误: {str(e)}")
        return jsonify({
            "success": False,
            "error": "生成学习路径时发生错误，请稍后重试"
        }), 500

@app.route('/adjust_learning_path', methods=['POST'])
def adjust_learning_path():
    """调整学习路径"""
    try:
        data = request.get_json()
        
        # 验证必需字段
        required_fields = ['originalPath', 'completedStages', 'feedback']
        for field in required_fields:
            if not data.get(field):
                return jsonify({
                    "success": False,
                    "error": f"缺少必需字段: {field}"
                }), 400
        
        original_path = data['originalPath']
        completed_stages = data['completedStages']
        feedback = data['feedback']
        difficulty_feedback = data.get('difficultyFeedback', '')
        time_feedback = data.get('timeFeedback', '')
        
        logger.info(f"调整学习路径请求: 已完成阶段数: {len(completed_stages)}")
        
        # 调整学习路径
        adjusted_path = adjust_learning_path_with_deepseek(
            original_path, completed_stages, feedback, difficulty_feedback, time_feedback
        )
        
        return jsonify({
            "success": True,
            "adjusted_path": adjusted_path
        })
        
    except Exception as e:
        logger.error(f"调整学习路径失败: {str(e)}")
        return jsonify({
            "success": False,
            "error": "调整学习路径时发生错误，请稍后重试"
        }), 500

@app.route('/models/info', methods=['GET'])
def model_info():
    """获取模型信息"""
    return jsonify({
        'model_name': 'Qwen-Image (API) + DeepSeek',
        'supported_ratios': list(ASPECT_RATIOS.keys()),
        'default_steps': 50,
        'default_cfg_scale': 4.0,
        'supports_chinese': True,
        'supports_english': True,
        'api_configured': check_api_config(),
        'api_provider': 'DashScope + DeepSeek',
        'capabilities': ['图像生成', '学习路径规划']
    })

# 聊天功能API
@app.route('/chat_with_deepseek', methods=['POST'])
def chat_with_deepseek():
    try:
        data = request.json
        user_message = data.get('message', '').strip()
        
        if not user_message:
            return jsonify({
                'success': False,
                'error': '消息不能为空'
            }), 400
        
        # 构建聊天提示词
        chat_prompt = f"""
你是一位友善、专业的卷王AI助手，名字叫小智。你的任务是帮助学生解决学习相关的问题，激励他们成为学习卷王。

## 角色设定：
- 🎓 你是一位经验丰富的学习顾问
- 😊 性格友善、耐心，善于鼓励学生
- 🧠 擅长各个学科领域的知识
- 💡 能提供实用的学习方法和建议
- 🔍 可以帮助学生分析问题、制定学习计划

## 回答要求：
1. **语言风格**：亲切友好，像学长学姐一样
2. **内容质量**：准确、实用、有针对性
3. **格式要求**：结构清晰，适当使用emoji增加亲和力，避免使用过多的markdown符号如#
4. **长度控制**：回答要详细但不冗长，一般200-500字
5. **互动性**：适当提出后续问题，引导深入交流
6. **数学公式**：当涉及数学内容时，请使用LaTeX格式：
   - 行内公式使用 \\( 和 \\) 包围
   - 独立公式使用 \\[ 和 \\] 包围

## 特别注意：
- 如果问题涉及具体的学习资源，请尽量推荐真实存在的网站、课程或书籍
- 对于学习困难，要给予鼓励和具体的解决方案
- 如果问题超出学习范畴，礼貌地引导回到学习话题
- 回答中尽量少用标题符号#，用简洁的文字和emoji来组织内容

学生问题：{user_message}

请作为小智回答这个问题：
        """
        
        # 调用DeepSeek API
        payload = {
            "model": "deepseek-chat",
            "messages": [
                {
                    "role": "user",
                    "content": chat_prompt
                }
            ],
            "stream": False
        }
        
        response = requests.post(
            DEEPSEEK_API_URL,
            headers=DEEPSEEK_HEADERS,
            json=payload,
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            ai_reply = result['choices'][0]['message']['content'].strip()
            
            return jsonify({
                'success': True,
                'reply': ai_reply
            })
        else:
            error_msg = f"DeepSeek API错误: {response.status_code}"
            if response.text:
                try:
                    error_data = response.json()
                    error_msg += f" - {error_data.get('error', {}).get('message', response.text)}"
                except:
                    error_msg += f" - {response.text[:200]}"
            
            return jsonify({
                'success': False,
                'error': error_msg
            }), 500
            
    except requests.exceptions.Timeout:
        return jsonify({
            'success': False,
            'error': 'AI服务响应超时，请稍后再试'
        }), 504
    except requests.exceptions.RequestException as e:
        return jsonify({
            'success': False,
            'error': f'网络请求失败: {str(e)}'
        }), 503
    except Exception as e:
        return jsonify({
            'success': False,
            'error': f'服务器内部错误: {str(e)}'
        }), 500

# 注册路由
app.register_blueprint(analytics_bp, url_prefix='/api/analytics')
app.register_blueprint(auth_bp, url_prefix='/api/auth')

if __name__ == '__main__':
    # 启动时检查API配置
    logger.info("启动Qwen-Image API服务器...")
    
    # 创建输出目录
    os.makedirs('generated_images', exist_ok=True)
    
    # 检查API配置
    if check_api_config():
        logger.info("API配置检查通过，启动Flask服务器")
    else:
        logger.warning("API配置未完成，请在代码中设置有效的API_KEY")
    
    # 启动Flask应用
    app.run(
        host=FLASK_HOST,
        port=FLASK_PORT,
        debug=FLASK_DEBUG,
        threaded=True
    )