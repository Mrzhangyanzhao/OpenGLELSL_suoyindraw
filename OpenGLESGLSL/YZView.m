//
//  YZView.m
//  OpenGLESGLSL
//
//  Created by yz on 2020/8/6.
//  Copyright © 2020 yz. All rights reserved.
//

#import "YZView.h"
#import <OpenGLES/ES2/gl.h>
#import "GLESMath.h"
#import "GLESUtils.h"

@interface YZView ()

@property (strong, nonatomic) EAGLContext *myContext;
@property (strong, nonatomic) CAEAGLLayer *myEagLayer;
@property (assign, nonatomic) GLuint myColorRenderBuffer;
@property (assign, nonatomic) GLuint myColorFrameBuffer;
@property (assign, nonatomic) GLuint myProgram;
@property (assign, nonatomic) GLuint myVertices;
@end

@implementation YZView
{
    float xDegree;
    float yDegree;
    float zDegree;
    BOOL bX;
    BOOL bY;
    BOOL bZ;
    NSTimer* myTimer;
}
/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

-(void)layoutSubviews{
    [self setupLayer];
    [self setupContext];
    [self deleteRenderAndFrameBuffer];
    [self setupColorRenderBuffer];
    [self setupColorFrameBuffer];
    [self render];
}

//绘制
-(void)render{
    glClearColor(0.3, 0.1, 0.2, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    //设置视口
    CGFloat scale = [[UIScreen mainScreen] scale];
    CGRect frame = self.frame;
    glViewport(frame.origin.x * scale, frame.origin.y * scale, frame.size.width * scale, frame.size.height * scale);
    
    //获取顶点、片元着色器文件 加载到program上
    NSString *verFile = [[NSBundle mainBundle]pathForResource:@"shaderv" ofType:@"vsh"];
    NSString *fragFile = [[NSBundle mainBundle]pathForResource:@"shaderf" ofType:@"fsh"];
    if (self.myProgram) {
        glDeleteProgram(self.myProgram);
        self.myProgram = 0;
    }
    self.myProgram = [self loadShader:verFile frag:fragFile];
    
    //链接program
    glLinkProgram(self.myProgram);
    //查看链接状态
    GLint linkStatus;
    glGetProgramiv(self.myProgram, GL_LINK_STATUS, &linkStatus);
    if (linkStatus == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(self.myProgram, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"error%@", messageString);
        
        return ;
    }
    glUseProgram(self.myProgram);
    
    //创建顶点数据组。索引数组
     GLfloat attrArr[] =
       {
           -0.5f, 0.5f, 0.0f,      1.0f, 0.0f, 1.0f, //左上0
           0.5f, 0.5f, 0.0f,       1.0f, 0.0f, 1.0f, //右上1
           -0.5f, -0.5f, 0.0f,     1.0f, 1.0f, 1.0f, //左下2
           
           0.5f, -0.5f, 0.0f,      1.0f, 1.0f, 1.0f, //右下3
           0.0f, 0.0f, 1.0f,       0.0f, 1.0f, 0.0f, //顶点4
       };
    //(2).索引数组
    GLuint indices[] =
    {
        0, 3, 2,
        0, 1, 3,
        0, 2, 4,
        0, 4, 1,
        2, 3, 4,
        1, 4, 3,
    };
    //(3).判断顶点缓存区是否为空，如果为空则申请一个缓存区标识符
    if (self.myVertices == 0) {
        glGenBuffers(1, &_myVertices);
    }
    
    //处理顶点数据
    //将myVertices绑定到GL_ARRAY_BUFFER标识符上
    glBindBuffer(GL_ARRAY_BUFFER, _myVertices);
    //把顶点数据从CPU复制到GPU
    glBufferData(GL_ARRAY_BUFFER, sizeof(attrArr), attrArr, GL_DYNAMIC_DRAW);
    
    //将顶点数据通过myProgram传递到顶点着色器程序的position
    /**
     * glGetAttribLocation(<#GLuint program#>, <#const GLchar *name#>)
     * 1、用来获取vertex attribute的入口的
     * 2、告诉OpenGL ES，通过glEnableVertexAttribArray
     * 3、最后数据通过glVertexAttribPointer传递过去
     */
    //注意第二个参数字符串必须和shader.vsh中的position保持一致
    GLuint position = glGetAttribLocation(self.myProgram, "position");
    //打开position
    glEnableVertexAttribArray(position);
    
    //设置读取方式
    /**
     * glVertexAttribPointer(<#GLuint indx#>, <#GLint size#>, <#GLenum type#>, <#GLboolean normalized#>, <#GLsizei stride#>, <#const GLvoid *ptr#>)
     * 参数
     * 1、index 顶点数据索引
     * 2、size,每个顶点属性的组件数量，1，2，3，或者4.默认初始值是4.
     * 3、type,数据中的每个组件的类型，常用的有GL_FLOAT,GL_BYTE,GL_SHORT。默认初始值为GL_FLOAT
     * 4、normalized,固定点数据值是否应该归一化，或者直接转换为固定值。（GL_FALSE）
     * 5、stride,连续顶点属性之间的偏移量，默认为0；
     * 6、指定一个指针，指向数组中的第一个顶点属性的第一个组件。默认为0
     */
    glVertexAttribPointer(position, 3, GL_FLOAT, GL_FALSE, sizeof(GLfloat) * 6, NULL);
    
    //处理顶点数据颜色
    GLuint positionColor = glGetAttribLocation(self.myProgram, "positionColor");
    
    glEnableVertexAttribArray(positionColor);
    
    glVertexAttribPointer(positionColor, 3, GL_FLOAT, GL_FALSE, sizeof(CGFloat) *6, (float *)NULL + 3);
    
    //处理投影矩阵、模型视图矩阵
    GLuint projectionMatrixSlot = glGetUniformLocation(self.myProgram, "projectionMartix");
    GLuint modelViewMatrixSlot = glGetUniformLocation(self.myProgram, "modelViewMartix");
    float width = frame.size.width;
    float height = frame.size.height;
    
    float aspect = width/height;
    
    //创建投影矩阵
    KSMatrix4 _projectionMatrix;
    //加载单元矩阵
    ksMatrixLoadIdentity(&_projectionMatrix);
    
    //获取透视矩阵
    ksPerspective(&_projectionMatrix, 30.0f, aspect, 5.0f, 20.0f);
    
    //将投影矩阵传递到顶点着色器
    glUniformMatrix4fv(projectionMatrixSlot, 1, GL_FALSE, (GLfloat*)&_projectionMatrix.m[0][0]);
    
    //创建4 * 4 的模型视图矩阵
    KSMatrix4 _modelViewMatrix;
    
    ksMatrixLoadIdentity(&_modelViewMatrix);
    
    //平移 z轴平移
    ksTranslate(&_modelViewMatrix, 0, 0, -10.0f);
    
    //创建4 * 4 旋转矩阵
    KSMatrix4 _rotationMatrix;
      //(4)初始化为单元矩阵
      ksMatrixLoadIdentity(&_rotationMatrix);
      //(5)旋转
      ksRotate(&_rotationMatrix, xDegree, 1.0, 0.0, 0.0); //绕X轴
      ksRotate(&_rotationMatrix, yDegree, 0.0, 1.0, 0.0); //绕Y轴
      ksRotate(&_rotationMatrix, zDegree, 0.0, 0.0, 1.0); //绕Z轴
      //(6)把变换矩阵相乘.将_modelViewMatrix矩阵与_rotationMatrix矩阵相乘，结合到模型视图
       ksMatrixMultiply(&_modelViewMatrix, &_rotationMatrix, &_modelViewMatrix);
      //(7)将模型视图矩阵传递到顶点着色器
      /*
       void glUniformMatrix4fv(GLint location,  GLsizei count,  GLboolean transpose,  const GLfloat *value);
       参数列表：
       location:指要更改的uniform变量的位置
       count:更改矩阵的个数
       transpose:是否要转置矩阵，并将它作为uniform变量的值。必须为GL_FALSE
       value:执行count个元素的指针，用来更新指定uniform变量
       */
      glUniformMatrix4fv(modelViewMatrixSlot, 1, GL_FALSE, (GLfloat*)&_modelViewMatrix.m[0][0]);
      
     
      //14.开启剔除操作效果
      glEnable(GL_CULL_FACE);

      
      //15.使用索引绘图
      /*
       void glDrawElements(GLenum mode,GLsizei count,GLenum type,const GLvoid * indices);
       参数列表：
       mode:要呈现的画图的模型
                  GL_POINTS
                  GL_LINES
                  GL_LINE_LOOP
                  GL_LINE_STRIP
                  GL_TRIANGLES
                  GL_TRIANGLE_STRIP
                  GL_TRIANGLE_FAN
       count:绘图个数
       type:类型
               GL_BYTE
               GL_UNSIGNED_BYTE
               GL_SHORT
               GL_UNSIGNED_SHORT
               GL_INT
               GL_UNSIGNED_INT
       indices：绘制索引数组

       */
      glDrawElements(GL_TRIANGLES, sizeof(indices) / sizeof(indices[0]), GL_UNSIGNED_INT, indices);
      
    
      //16.要求本地窗口系统显示OpenGL ES渲染<目标>
      [self.myContext presentRenderbuffer:GL_RENDERBUFFER];
    
    
    
}

//设置上下文
-(void)setupContext{
    EAGLContext *context = [[EAGLContext alloc]initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!context) {
        NSLog(@"creat context failed");
        return;
    }
    if (![EAGLContext setCurrentContext:context]) {
        NSLog(@"set current context failed");
        return;
    }
    self.myContext = context;
}
//设置layer
-(void)setupLayer{
    self.myEagLayer = (CAEAGLLayer *)self.layer;
    [self setContentScaleFactor:[[UIScreen mainScreen]scale]];
    self.myEagLayer.opaque = YES;
    self.myEagLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking,kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
}
+(Class)layerClass{
    return [CAEAGLLayer class];
}

//设置ColorFrameBuffer
-(void)setupColorFrameBuffer{
    //定义缓存区
    //申请缓存区标志
    //绑定当前framebuffer
    //将_myColorRenderBuffer 装配到GL_COLOR_ATTACHMENT0 附着点上
    GLuint buffer;
    glGenFramebuffers(1, &buffer);
    self.myColorFrameBuffer = buffer;
    glBindFramebuffer(GL_FRAMEBUFFER, self.myColorFrameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, self.myColorRenderBuffer);
}
//设置rcolorRenderBuffer
-(void)setupColorRenderBuffer{
   //定义缓存区
    //申请缓存区标志
    //将标识符绑定到shader
    GLuint buffer;
    glGenRenderbuffers(1, &buffer);
    self.myColorRenderBuffer = buffer;
    glBindRenderbuffer(GL_RENDERBUFFER, self.myColorRenderBuffer);
    [self.myContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.myEagLayer];
}
//清空render、frame buffer
-(void)deleteRenderAndFrameBuffer{
    glDeleteBuffers(1, &_myColorRenderBuffer);
    _myColorRenderBuffer = 0;
    
    glDeleteBuffers(1, &_myColorFrameBuffer);
    _myColorFrameBuffer = 0;
    
}




-(GLuint)loadShader:(NSString *)vert frag:(NSString *)frag{
    
    //创建临时 shader，program
    //编译shader，
    //将shader 附着到program
    //释放shader。返回program
    
    GLuint verShader,fragShader;
    
    GLuint program = glCreateProgram();
    
    [self compileShader:&verShader type:GL_VERTEX_SHADER file:vert];
    [self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:frag];
    
    glAttachShader(program, verShader);
    glAttachShader(program, fragShader);
    
    glDeleteShader(verShader);
    glDeleteShader(fragShader);
    
    return program;
}
//编译shader
-(void)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file{
    //1、读取文件路径。转化c字符串
    //2、根据类型创建shader
    //3、将shader源码附着到着色器对象
    //4、把着色器源码编译成目标代码
    NSString *content = [NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
    const GLchar *source = (GLchar *)[content UTF8String];
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
}

#pragma mark - XYClick
- (IBAction)XClick:(id)sender {
    
    //开启定时器
    if (!myTimer) {
        myTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(reDegree) userInfo:nil repeats:YES];
    }
    //更新的是X还是Y
    bX = !bX;
    
}
- (IBAction)YClick:(id)sender {
    
    //开启定时器
    if (!myTimer) {
        myTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(reDegree) userInfo:nil repeats:YES];
    }
    //更新的是X还是Y
    bY = !bY;
}
- (IBAction)ZClick:(id)sender {
    
    //开启定时器
    if (!myTimer) {
        myTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(reDegree) userInfo:nil repeats:YES];
    }
    //更新的是X还是Y
    bZ = !bZ;
}

-(void)reDegree
{
    //如果停止X轴旋转，X = 0则度数就停留在暂停前的度数.
    //更新度数
    xDegree += bX * 5;
    yDegree += bY * 5;
    zDegree += bZ * 5;
    //重新渲染
    [self render];
    
}

@end
