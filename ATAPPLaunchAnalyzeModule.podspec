#
# To learn more about a Podspec see http://ibiu.jd.com/docs/podspec_reference.html
#
require "biu"

Pod::Spec.new do |s|
  s.name             = 'ATAPPLaunchAnalyzeModule'
   s.version        = '1.0.17'
  s.summary          = 'APP启动检测'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
ATAPPLaunchAnalyzeModule-APP启动检测
                       DESC

   s.homepage        = 'https://coding.jd.com/IBKFXHJingxiTest/ATAPPLaunchAnalyzeModule'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '何骁' => 'hexiao156@jd.com' }
   s.source        = { :git => 'https://coding.jd.com/IBKFXHJingxiTest/ATAPPLaunchAnalyzeModule.git', :tag => s.version.to_s }


  s.ios.deployment_target = '8.0'
  s.platform         = :ios, '8.0'


Biu::Spec.new(spec:s) { |se|

#-----基础组件依赖,请不要手动修改-----
    se.dependency {
    }
    se.dynamic_enable = true
#19108

#---------
#	非公用二进制文件处理办法(注意公用二进制文件请申请新的组件)：
#   (1)上传文件到云存储:打开iBiuTool工具->打开->工具->上传，按照工具提示上传文件;
#   (2)修改podspec，编写引用，如下面例子,JDPaySDK_1.0.0对应zip包名，root对应包的根目录：
#eg1（library）:
#   se.vendored_spec("JDPaySDK_1.0.0"){|vsp, root|
#      vsp.ios.vendored_library = "#{root}/**/*.a"
#      vsp.source_files = "#{root}/**/*.h"
#      vsp.resource = "#{root}/**/*.bundle"
#      其它需要的描述；
#    }
#
#eg2（framework）:
#   se.vendored_spec("jdmobilesecurity_1.0.0"){|vsp, root|
#     vsp.vendored_frameworks = "#{root}/**/*.framework"
#      其它需要的描述；
#   }
#--------

#   组件源码配置请写在run{}之间,文件路径请以root开始，root对应组件文件根目录
    se.run() { |root|
#源码文件，请保留umbrella.h
      s.source_files="#{root}/ATAPPLaunchAnalyzeModule-umbrella.h","#{root}/Classes/**/*"
#如果需要暴露头文件，请保留umbrella.h,头文件不给值默认所有头文件为public
s.public_header_files="#{root}/Classes/ATAPPLaunchAnalyzeModule.h"
      #不要修改Assets文件夹名称，资源文件统一放到Assets目录下
     s.resources="#{root}/Assets/*"
     s.libraries = 'stdc++', 'sqlite3'
     s.frameworks = 'UIKit', 'Foundation', 'Security', 'CoreGraphics'
  #s.libraries = 'z', 'sqlite3'
    }


}


end
