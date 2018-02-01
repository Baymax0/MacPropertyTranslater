//
//  InterfaceToPropertyVC.m
//  接口文档工具
//
//  Created by 李志伟 on 17/7/12.
//  Copyright © 2017年 baymax0. All rights reserved.
//

#import "InterfaceToPropertyVC.h"

//1-转换后自动复制到剪切板   0不赋值
#define AutoCopy 1

@interface InterfaceToPropertyVC ()
@property (unsafe_unretained) IBOutlet NSTextView *textView1;
@property (unsafe_unretained) IBOutlet NSTextView *textView2;

@end

@implementation InterfaceToPropertyVC

- (void)viewDidLoad {
    [super viewDidLoad];

}



- (IBAction)changeToPropertyAction:(id)sender {
    //文本内容
    NSMutableString *str = _textView1.textStorage.mutableString;
    //行为单位创建数组
    NSArray *arr = [str componentsSeparatedByString:@"\n"];
    //最终的结果字符串
    NSMutableString *result = [NSMutableString string];
    //对每行单独处理
    for (int y=0 ; y<arr.count; y++) {
        NSString *sentence = arr[y];

        //1. 删除开头空格 判断是否是空行
        sentence = [self deleteHeadBlank:sentence];
        sentence = [self deleteContinuousBlank:sentence];//删除连续的空格
        if (sentence.length==0) {//空行跳过
            continue;
        }

        NSString *firstWord = [sentence substringWithRange:NSMakeRange(0,1)];
        //2. 如果第一个字符不是字母 就作为注释 单独占一行
        if (![self isEnglishString:firstWord]) {
            sentence = [sentence stringByReplacingOccurrencesOfString:@"\\" withString:@""];
            [result appendString:[NSString stringWithFormat:@"//%@\n",sentence]];
            continue;
        }

        //3. 将数据分为三部分
        NSString *typeStr = nil;//数据类型
        NSString *propertyName = nil;//字段名称
        NSString *notes = nil;//注释
        NSString *temp = @"";//缓存截取的字符串
        for(int i =0; i < [sentence length]; i++){
            NSString* chara = [sentence substringWithRange:NSMakeRange(i,1)];
            //先读取类型
            if (!typeStr) {
                //读到不是英文的字符
                if ([self isEnglishString:chara]) {
                    temp = [temp stringByAppendingString:chara];
                    continue;
                }else{
                    //保存数据类型
                    typeStr = temp;
                    temp = @"";
                    //本轮循环读到的 chara 当做分隔符 舍弃
                    continue;
                }
            }
            //再读字段名
            if (!propertyName) {
                //读到不是英文的字符 或空格
                if ([self isEnglishString:chara]) {
                    temp = [temp stringByAppendingString:chara];
                    continue;
                }else{
                    propertyName = temp;
                    temp = @"";
                    i--;
                    continue;
                }
            }
            //最后的内容全加入注释中
            temp = [temp stringByAppendingString:chara];
            notes = temp;
        }
        //当只能识别一段  或两端的时候  手动保存temp
        if (!typeStr) {
            typeStr = temp;
        }else{
            if (!propertyName) {
                propertyName = temp;
            }
        }

        //如果格式读取失败 当做注释
        if (!propertyName) {
            sentence = [sentence stringByReplacingOccurrencesOfString:@"\\" withString:@""];
            [result appendString:[NSString stringWithFormat:@"//%@\n",sentence]];
            continue;
        }

        //4. 处理数据
        typeStr = [self whatTypeIs:typeStr];//将类型转化为OC类型（NSString | NSNumber）
        propertyName = [self deleteHeadBlank:propertyName];
        notes = [self disposeNotes:notes];//去除注释开头的；; //等字符

        //获得属性
        NSString *property = [NSString stringWithFormat:@"@property (nonatomic, strong) %@ *%@; ",typeStr,propertyName];
        [result appendString:[NSString stringWithFormat:@"%@%@\n",property,notes]];
    }

    //将结果 输出到 结果框里
    [_textView2 replaceCharactersInRange: NSMakeRange (0, [[_textView2 string] length]) withString: result];

    //复制到剪切板
    if (AutoCopy==1) {
        [self copyResult:nil];
    }
}

#pragma mark ----------  字符串处理方法  ----------
//判断是否是英文
- (BOOL)isEnglishString:(NSString *)str {
    NSRegularExpression *numberRegular = [NSRegularExpression regularExpressionWithPattern:@"[A-Za-z]" options:NSRegularExpressionCaseInsensitive error:nil];
    NSInteger count = [numberRegular numberOfMatchesInString:str options:NSMatchingReportProgress range:NSMakeRange(0, str.length)];
    if (count > 0) {
        return YES;
    }else{
        return NO;
    }
}

//去除开头的空格
-(NSString*)deleteHeadBlank:(NSString*)sentence{
    if (!sentence || sentence.length == 0) {
        return @"";
    }
    if ([sentence isEqualToString:@" "]) {
        return @"";
    }
    //替换制表符
    sentence = [sentence stringByReplacingOccurrencesOfString:@"\t" withString:@" "];
    NSString *result = @"";
    for(int i =0; i < [sentence length]; i++){
        NSString* temp = [sentence substringWithRange:NSMakeRange(i,1)];
        if ([temp isEqualToString:@" "]) {
            continue;
        }else{
            result = [sentence substringFromIndex:i];
            break;
        }
    }
    return result;
}

//将连续的空格转为单个空格
-(NSString*)deleteContinuousBlank:(NSString*)sentence{
    NSArray *arr = [sentence componentsSeparatedByString:@" "];
    NSString *temp = nil;
    if (arr.count == 1) {
        return sentence;
    }
    for (NSString *sec in arr) {
        if ([sec isEqualToString:@" "]||sec.length == 0) {
            continue;
        }
        if (!temp) {
            temp = sec;
        }else{
            temp = [NSString stringWithFormat:@"%@ %@",temp,sec];
        }
    }
    return temp?temp:sentence;
}

//判断数据类型
-(NSString*)whatTypeIs:(NSString*)type{
    NSString *lower = [type lowercaseString];//转化为小写
    if ([lower isEqualToString:@"string"] || [lower isEqualToString:@"nsstring"]|| [lower isEqualToString:@"str"]) {
        return @"NSString";
    }else{
        return @"NSNumber";
    }
}

//对注释进行加工
-(NSString*)disposeNotes:(NSString*)notes{
    //去除开头空格
    notes = [self deleteHeadBlank:notes];
    //去除开头空格
    notes = [notes stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    if ([notes isEqualToString:@" "] || notes.length == 0) {
        return @"";
    }

    NSString* chara = [notes substringWithRange:NSMakeRange(0,1)];
    //去除开头的分号
    if ([chara isEqualToString:@"；"] || [chara isEqualToString:@";"]) {
        notes = [notes substringFromIndex:1];
        notes = [self deleteHeadBlank:notes];
    }

    //去除开头的 //
    if ([notes isEqualToString:@"//"]) {
        return @"";
    }
    if (notes.length>2) {
        chara = [notes substringWithRange:NSMakeRange(0,2)];
        if ([chara isEqualToString:@"//"]) {
            notes = [notes substringFromIndex:2];
        }
    }
    notes = [self deleteHeadBlank:notes];
    return [NSString stringWithFormat:@"//%@",notes];
}

#pragma mark ----------  btn Action ----------
//清空输入框
- (IBAction)clearTextView1:(id)sender {
    NSRange range;
    range = NSMakeRange (0, [[_textView1 string] length]);
    [_textView1 replaceCharactersInRange: range withString: @""];
}
//复制到剪切板
- (IBAction)copyResult:(id)sender {
    NSMutableString *str = _textView2.textStorage.mutableString;
    NSPasteboard *paste = [NSPasteboard generalPasteboard];
    [paste clearContents];
    [paste writeObjects:@[str]];
}


@end
