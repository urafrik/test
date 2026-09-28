"""Validate cross-platform project metadata and create a repository upload ZIP."""
from pathlib import Path
import plistlib
import re
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / 'safee_ios'


def main():
    with (PROJECT / 'Safee' / 'Info.plist').open('rb') as source:
        plist = plistlib.load(source)
    for permission in ('NSCameraUsageDescription', 'NSMicrophoneUsageDescription'):
        assert plist.get(permission), 'Missing permission description: ' + permission
    project_text = (PROJECT / 'Safee.xcodeproj' / 'project.pbxproj').read_text(encoding='utf-8')
    defined = set(re.findall(r'^\s*(A[0-9]{23}) = \{isa', project_text, re.M))
    referenced = set(re.findall(r'A[0-9]{23}', project_text))
    assert referenced <= defined, 'Undefined Xcode object references: ' + str(referenced - defined)
    scheme = ET.parse(PROJECT / 'Safee.xcodeproj' / 'xcshareddata' / 'xcschemes' / 'Safee.xcscheme')
    for reference in scheme.iter('BuildableReference'):
        assert reference.attrib['BlueprintIdentifier'] in defined
    for path in (PROJECT / 'Safee').glob('*.swift'):
        assert 'path = ' + path.name + ';' in project_text, 'Source not in project: ' + path.name
    workflow = ROOT / '.github' / 'workflows' / 'build-ios.yml'
    assert workflow.exists()
    # PyYAML is optional; the upload package itself has no Python dependency.
    try:
        import yaml
    except ImportError:
        print('YAML parser unavailable; metadata and file references checked only.')
    else:
        config = yaml.load(workflow.read_text(encoding='utf-8'), Loader=yaml.BaseLoader)
        assert 'workflow_dispatch' in config['on']
        assert config['permissions'] == {'contents': 'read'}
        assert config['jobs']['build']['runs-on'] == 'macos-15'
    readme = '''# Safee Studio — Windows + GitHub 云端构建

原生 SwiftUI iPhone 原型。无需本地 Mac，不依赖 Pythonista。

## 打包

Actions → Build iPhone IPA → Run workflow。构建成功后下载 Safee-unsigned-ipa。

这是未签名 IPA，须通过 Windows 侧载工具重新签名后安装，不是点击即可安装的文件。

详见 [Windows 安装与日志反馈](safee_ios/INSTALL_WINDOWS.md)。

## 当前功能

麦克风录音、拍照录像、前台黑色界面、本地媒体管理与诊断导出。
系统电话双方录音尚未实现。已通过 Xcode 16.4 云端编译，尚需签名侧载和真机验证。
[首次成功构建](https://github.com/urafrik/test/actions/runs/36416033912)。

不包含 Safee 官方代码、素材、账号或服务。
'''
    destination = ROOT / 'safee-github-ready.zip'
    with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED) as archive:
        archive.writestr('README.md', readme)
        archive.writestr('.gitignore', '.build/\nDerivedData/\n*.ipa\n*.p12\n*.mobileprovision\n*.xcuserstate\nxcuserdata/\n__pycache__/\n')
        archive.write(workflow, '.github/workflows/build-ios.yml')
        for file in PROJECT.rglob('*'):
            if file.is_file() and file.suffix in ('.swift', '.plist', '.pbxproj', '.xcscheme', '.md', '.py') and not any(part in ('__pycache__', 'artifacts') for part in file.relative_to(PROJECT).parts):
                archive.write(file, file.relative_to(ROOT).as_posix())
    with zipfile.ZipFile(destination) as archive:
        assert archive.testzip() is None
        assert '.github/workflows/build-ios.yml' in archive.namelist()
    print('PASS: plist, project references, shared scheme, workflow settings and ZIP integrity.')
    print('NOT RUN: Xcode compilation, code signing, or iPhone runtime tests.')
    print(destination)


if __name__ == '__main__':
    main()
