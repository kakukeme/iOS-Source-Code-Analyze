//
//  NSAttributedString+YYText.h
//  YYText <https://github.com/ibireme/YYText>
//
//  Created by ibireme on 14/10/7.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>

#if __has_include(<YYText/YYText.h>)
#import <YYText/YYTextAttribute.h>
#import <YYText/YYTextRubyAnnotation.h>
#else
#import "YYTextAttribute.h"
#import "YYTextRubyAnnotation.h"
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 Get pre-defined attributes from attributed string.
 All properties defined in UIKit, CoreText and YYText are included.
 */
@interface NSAttributedString (YYText)

/**
 将字符串存档到数据
 @return 如果发生错误返回nil
 */
/**
 Archive the string to data.
 @return Returns nil if an error occurs.
 */
- (nullable NSData *)yy_archiveToData;


/**
 从数据中取出归档字符串
 @param data  归档的数据
 @return 如果发生错误返回nil
 */

/**
 Unarchive string from data.
 @param data  The archived attributed string data.
 @return Returns nil if an error occurs.
 */
+ (nullable instancetype)yy_unarchiveFromData:(NSData *)data;



#pragma mark - Retrieving character attribute information 检索字符的属性信息
///=============================================================================
/// @name Retrieving character attribute information
///=============================================================================

/**
 返回第一个字符的属性
 */

/**
 Returns the attributes at first charactor.
 */
@property (nullable, nonatomic, copy, readonly) NSDictionary<NSString *, id> *yy_attributes;


/**
 返回指定索引处的字符的属性
 如果索引超出字符组的范围，则引发`NSRangeException`异常。
 
 @param index  索引
 这个值必须位于接受者的范围内.
 
 @return 返回索引处的字符属性
 */

/**
 Returns the attributes for the character at a given index.
 
 @discussion Raises an `NSRangeException` if index lies beyond the end of the 
 receiver's characters.
 
 @param index  The index for which to return attributes. 
 This value must lie within the bounds of the receiver.
 
 @return The attributes for the character at index.
 */
- (nullable NSDictionary<NSString *, id> *)yy_attributesAtIndex:(NSUInteger)index;

/**
 返回指定索引处的字符的某属性的值
 
 如果索引超出字符组的范围，则引发`NSRangeException`异常。
 
 @param attributeName  属性的名称
 @param index          索引
 
 @return 指定索引处，属性名为`attributeName`的属性的值，如果没有这样的属性，则为nil
 */

/**
 Returns the value for an attribute with a given name of the character at a given index.
 
 @discussion Raises an `NSRangeException` if index lies beyond the end of the
 receiver's characters.
 
 @param attributeName  The name of an attribute.
 @param index          The index for which to return attributes. 
 This value must not exceed the bounds of the receiver.
 
 @return The value for the attribute named `attributeName` of the character at 
 index `index`, or nil if there is no such attribute.
 */
- (nullable id)yy_attribute:(NSString *)attributeName atIndex:(NSUInteger)index;


#pragma mark - Get character attribute as property 获取字符的属性attribute作为property
///=============================================================================
/// @name Get character attribute as property
/// 添加像设置属性一样的设置character attribute的font、color、backgroundColor等等的方法。
///=============================================================================

/**
 文本的字体 (只读)
 
 默认的字体是 Helvetica (Neue) 12.
 获取这个属性, 返回第一个字符的字体
 @since CoreText:3.2  UIKit:6.0  YYText:6.0
 */

/**
 The font of the text. (read-only)
 
 @discussion Default is Helvetica (Neue) 12.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0  YYText:6.0
 */
@property (nullable, nonatomic, strong, readonly) UIFont *yy_font;
- (nullable UIFont *)yy_fontAtIndex:(NSUInteger)index;      // 指定索引的字体

/**
 字距调整 (只读)
 
 默认是标准字距. 正数表示字距大,负数表示字距小. 如果这个属性不存在, 将使用默认字距.
 如果这个属性设置为0.0, 则不进行字距的调整.
 返回第一个字符的字距；
 */
/**
 A kerning adjustment. (read-only)
 
 @discussion Default is standard kerning. The kerning attribute indicate how many 
 points the following character should be shifted from its default offset as 
 defined by the current character's font in points; a positive kern indicates a 
 shift farther along and a negative kern indicates a shift closer to the current 
 character. If this attribute is not present, standard kerning will be used. 
 If this attribute is set to 0.0, no kerning will be done at all.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0  YYText:6.0
 */
@property (nullable, nonatomic, strong, readonly) NSNumber *yy_kern;
- (nullable NSNumber *)yy_kernAtIndex:(NSUInteger)index;    // 指定索引的字距

/**
 前景色 (只读)
 
 默认是黑色
 返回第一个字符的这种属性
 */

/**
 The foreground color. (read-only)
 
 @discussion Default is Black.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0  YYText:6.0
 */
@property (nullable, nonatomic, strong, readonly) UIColor *yy_color;
- (nullable UIColor *)yy_colorAtIndex:(NSUInteger)index;


/**
 背景色 (只读)
 
 默认没有背景色, 为nil
 返回第一个字符的这种属性
 */

/**
 The background color. (read-only)
 
 @discussion Default is nil (or no background).
 @discussion Get this property returns the first character's attribute.
 @since UIKit:6.0
 */
@property (nullable, nonatomic, strong, readonly) UIColor *yy_backgroundColor;
- (nullable UIColor *)yy_backgroundColorAtIndex:(NSUInteger)index;

/**
 笔画宽度. (只读)
 
 默认值是 0.0 (没有笔画). 这个属性, 解释为字体点大小的百分比, 控制文本绘制模式: 正值仅用笔画效果绘图; 负值用于笔画和填充。
 概述文本的典型值为3.0。
 返回第一个字符的这种属性
 */

/**
 The stroke width. (read-only)
 
 @discussion Default value is 0.0 (no stroke). This attribute, interpreted as
 a percentage of font point size, controls the text drawing mode: positive 
 values effect drawing with stroke only; negative values are for stroke and fill.
 A typical value for outlined text is 3.0.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0
 */
@property (nullable, nonatomic, strong, readonly) NSNumber *yy_strokeWidth;
- (nullable NSNumber *)yy_strokeWidthAtIndex:(NSUInteger)index;

/**
 笔触颜色. (只读)
 
 默认值为 nil (和前景色相同).
 返回第一个字符的这种属性
 */
/**
 The stroke color. (read-only)
 
 @discussion Default value is nil (same as foreground color).
 @discussion Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0
 */
@property (nullable, nonatomic, strong, readonly) UIColor *yy_strokeColor;
- (nullable UIColor *)yy_strokeColorAtIndex:(NSUInteger)index;

/**
 文本阴影. (只读)
 
 默认值为 nil (没有阴影).
 返回第一个字符的这种属性
 */

/**
 The text shadow. (read-only)
 
 @discussion Default value is nil (no shadow).
 @discussion Get this property returns the first character's attribute.
 @since UIKit:6.0  YYText:6.0
 */
@property (nullable, nonatomic, strong, readonly) NSShadow *yy_shadow;
- (nullable NSShadow *)yy_shadowAtIndex:(NSUInteger)index;

/**
 删除线的风格. (只读)
 
 默认值是 NSUnderlineStyleNone (没有删除线).
 返回第一个字符的这种属性
 */

/**
 The strikethrough style. (read-only)
 
 @discussion Default value is NSUnderlineStyleNone (no strikethrough).
 @discussion Get this property returns the first character's attribute.
 @since UIKit:6.0
 */
@property (nonatomic, readonly) NSUnderlineStyle yy_strikethroughStyle;
- (NSUnderlineStyle)yy_strikethroughStyleAtIndex:(NSUInteger)index;

/**
 删除线的颜色. (只读)
 
 默认值是 nil (和前景色一样).
 返回第一个字符的这种属性
 */

/**
 The strikethrough color. (read-only)
 
 @discussion Default value is nil (same as foreground color).
 @discussion Get this property returns the first character's attribute.
 @since UIKit:7.0
 */
@property (nullable, nonatomic, strong, readonly) UIColor *yy_strikethroughColor;
- (nullable UIColor *)yy_strikethroughColorAtIndex:(NSUInteger)index;

/**
 下划线样式. (只读)
 
 默认值是 NSUnderlineStyleNone (没有下划线).
 返回第一个字符的这种属性
 */

/**
 The underline style. (read-only)
 
 @discussion Default value is NSUnderlineStyleNone (no underline).
 @discussion Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0
 */
@property (nonatomic, readonly) NSUnderlineStyle yy_underlineStyle;
- (NSUnderlineStyle)yy_underlineStyleAtIndex:(NSUInteger)index;

/**
 下划线的颜色. (只读)
 
 默认值是 nil (与前景色相同).
 返回第一个字符的这种属性
 */
/**
 The underline color. (read-only)
 
 @discussion Default value is nil (same as foreground color).
 @discussion Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:7.0
 */
@property (nullable, nonatomic, strong, readonly) UIColor *yy_underlineColor;
- (nullable UIColor *)yy_underlineColorAtIndex:(NSUInteger)index;

/**
 连字格式控制. (只读)
 ligature 连字
 
 默认值为1(int). 连字属性确定在显示字符串时应使用什么类型的连字。值0表示只应使用正确呈现文本所必需的连字，1表示应使用标准连字，2表示应使用所有可用的连字。哪些连字是标准的取决于脚本和可能的字体.
 返回第一个字符的这种属性
 */
/**
 Ligature formation control. (read-only)
 
 @discussion Default is int value 1. The ligature attribute determines what kinds 
 of ligatures should be used when displaying the string. A value of 0 indicates 
 that only ligatures essential for proper rendering of text should be used, 
 1 indicates that standard ligatures should be used, and 2 indicates that all 
 available ligatures should be used. Which ligatures are standard depends on the 
 script and possibly the font.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0  YYText:6.0
 */
@property (nullable, nonatomic, strong, readonly) NSNumber *yy_ligature;
- (nullable NSNumber *)yy_ligatureAtIndex:(NSUInteger)index;

/**
 文本效果. (只读)
 
 默认值是 nil (没有效果). 当前唯一被支持的值是 NSTextEffectLetterpressStyle.
 返回第一个字符的这种属性
 */
/**
 The text effect. (read-only)
 
 @discussion Default is nil (no effect). The only currently supported value
 is NSTextEffectLetterpressStyle.
 @discussion Get this property returns the first character's attribute.
 @since UIKit:7.0
 */
@property (nullable, nonatomic, strong, readonly) NSString *yy_textEffect;
- (nullable NSString *)yy_textEffectAtIndex:(NSUInteger)index;


/**
 字形倾斜. (只读) obliqueness倾斜
 
 默认值是 0 (不倾斜).
 返回第一个字符的这种属性
 */

/**
 The skew to be applied to glyphs. (read-only)
 
 @discussion Default is 0 (no skew).
 @discussion Get this property returns the first character's attribute.
 @since UIKit:7.0
 */
@property (nullable, nonatomic, strong, readonly) NSNumber *yy_obliqueness;
- (nullable NSNumber *)yy_obliquenessAtIndex:(NSUInteger)index;

/**
 要应用于字形的扩展因子的日志. (只读)
 
 默认值是 0 (没有扩展).
 返回第一个字符的这种属性
 */

/**
 The log of the expansion factor to be applied to glyphs. (read-only)
 
 @discussion Default is 0 (no expansion).
 @discussion Get this property returns the first character's attribute.
 @since UIKit:7.0
 */
@property (nullable, nonatomic, strong, readonly) NSNumber *yy_expansion;
- (nullable NSNumber *)yy_expansionAtIndex:(NSUInteger)index;

/**
 字符与基线的偏移, 以点为单位. (只读)
 
 默认值是 0.
 返回第一个字符的这种属性
 */
/**
 The character's offset from the baseline, in points. (read-only)
 
 @discussion Default is 0.
 @discussion Get this property returns the first character's attribute.
 @since UIKit:7.0
 */
@property (nullable, nonatomic, strong, readonly) NSNumber *yy_baselineOffset;
- (nullable NSNumber *)yy_baselineOffsetAtIndex:(NSUInteger)index;

/**
 字形方向控制. (只读)
 
 默认值是 NO. NO表示水平字形, YES表示垂直字形
 返回第一个字符的这种属性
 */
/**
 Glyph orientation control. (read-only)
 
 @discussion Default is NO. A value of NO indicates that horizontal glyph forms 
 are to be used, YES indicates that vertical glyph forms are to be used.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:4.3  YYText:6.0
 */
@property (nonatomic, readonly) BOOL yy_verticalGlyphForm;
- (BOOL)yy_verticalGlyphFormAtIndex:(NSUInteger)index;

/**
 指定文本语言. (只读)
 
 值必须是包含区域设置标识符的NSString. 默认为未设置. 
 当此属性设置为有效标识符时，将用于选择 本地化字形（如果字体支持）和特定于语言环境的换行规则.
 
 返回第一个字符的这种属性
 */
/**
 Specifies text language. (read-only)
 
 @discussion Value must be a NSString containing a locale identifier. Default is 
 unset. When this attribute is set to a valid identifier, it will be used to select 
 localized glyphs (if supported by the font) and locale-specific line breaking rules.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:7.0  YYText:7.0
 */
@property (nullable, nonatomic, strong, readonly) NSString *yy_language;
- (nullable NSString *)yy_languageAtIndex:(NSUInteger)index;


/**
 指定双向覆盖或嵌入. (只读)
 
 请参阅 NSWritingDirection and NSWritingDirectionAttributeName.
 返回第一个字符的这种属性
 */
/**
 Specifies a bidirectional override or embedding. (read-only)
 
 @discussion See alse NSWritingDirection and NSWritingDirectionAttributeName.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:7.0  YYText:6.0
 */
@property (nullable, nonatomic, strong, readonly) NSArray<NSNumber *> *yy_writingDirection;
- (nullable NSArray<NSNumber *> *)yy_writingDirectionAtIndex:(NSUInteger)index;

/**
 一个段落样式对象，用于指定如 段落行对齐，制表符，写入方向等 (只读)
 
 默认是空 ([NSParagraphStyle defaultParagraphStyle]).
 返回第一个字符的这种属性
 */

/**
 An NSParagraphStyle object which is used to specify things like
 line alignment, tab rulers, writing direction, etc. (read-only)
 
 @discussion Default is nil ([NSParagraphStyle defaultParagraphStyle]).
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nullable, nonatomic, strong, readonly) NSParagraphStyle *yy_paragraphStyle;
- (nullable NSParagraphStyle *)yy_paragraphStyleAtIndex:(NSUInteger)index;

#pragma mark - Get paragraph attribute as property 获取段落属性paragraph attribute作为property
///=============================================================================
/// @name Get paragraph attribute as property  添加像设置属性一样的设置paragraph attribute的方法。
///=============================================================================

/**
 文本对齐，(NSParagraphStyle包装属性) (只读)
 
 自然文本对齐实现为左对齐或右对齐，取决于段落中包含的第一个字符的 行扫描方向。
 默认为NSTextAlignmentNatural。
 返回第一个字符的这种属性
 */
/**
 The text alignment (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion Natural text alignment is realized as left or right alignment 
 depending on the line sweep direction of the first script contained in the paragraph.
 @discussion Default is NSTextAlignmentNatural.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readonly) NSTextAlignment yy_alignment;
- (NSTextAlignment)yy_alignmentAtIndex:(NSUInteger)index;

/**
 lineBreakMode 断行方式
 
 设置标签文字过长时的显示方式。
 
 文字截断时的模式，(NSParagraphStyle包装属性) (只读)
 
 这个属性包含了 line break 模式，当布局段落文字时会被使用；
 默认值为NSLineBreakByWordWrapping；
 返回第一个字符的这种属性
 */
/**
 The mode that should be used to break lines (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion This property contains the line break mode to be used laying out the paragraph's text.
 @discussion Default is NSLineBreakByWordWrapping.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readonly) NSLineBreakMode yy_lineBreakMode;
- (NSLineBreakMode)yy_lineBreakModeAtIndex:(NSUInteger)index;

/**
 lineSpacing 行间距
 
 一行片段的底部与下一个片段的顶部之间的距离。(NSParagraphStyle包装属性) (只读)
 
 这个值总是非负的，该值包含在 该行中布局管理器中的片段高度。
 默认为0；
 
 */

/**
 The distance in points between the bottom of one line fragment and the top of the next.
 (A wrapper for NSParagraphStyle) (read-only)
 
 @discussion This value is always nonnegative. This value is included in the line 
 fragment heights in the layout manager.
 @discussion Default is 0.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readonly) CGFloat yy_lineSpacing;
- (CGFloat)yy_lineSpacingAtIndex:(NSUInteger)index;

/**
 paragraphSpacing 段间距
 
 */
/**
 The space after the end of the paragraph (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion This property contains the space (measured in points) added at the 
 end of the paragraph to separate it from the following paragraph. This value must
 be nonnegative. The space between paragraphs is determined by adding the previous 
 paragraph's paragraphSpacing and the current paragraph's paragraphSpacingBefore.
 @discussion Default is 0.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readonly) CGFloat yy_paragraphSpacing;
- (CGFloat)yy_paragraphSpacingAtIndex:(NSUInteger)index;

/**
 paragraphSpacingBefore 段首空间
 
 */
/**
 The distance between the paragraph's top and the beginning of its text content.
 (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion This property contains the space (measured in points) between the 
 paragraph's top and the beginning of its text content.
 @discussion Default is 0.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readonly) CGFloat yy_paragraphSpacingBefore;
- (CGFloat)yy_paragraphSpacingBeforeAtIndex:(NSUInteger)index;

/**
 firstLineHeadIndent 首行缩进
 
 */

/**
 The indentation of the first line (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion This property contains the distance (in points) from the leading margin 
 of a text container to the beginning of the paragraph's first line. This value 
 is always nonnegative.
 @discussion Default is 0.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readonly) CGFloat yy_firstLineHeadIndent;
- (CGFloat)yy_firstLineHeadIndentAtIndex:(NSUInteger)index;

/**
 headIndent 段落头部缩进
 
 */

/**
 The indentation of the receiver's lines other than the first. (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion This property contains the distance (in points) from the leading margin 
 of a text container to the beginning of lines other than the first. This value is 
 always nonnegative.
 @discussion Default is 0.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readonly) CGFloat yy_headIndent;
- (CGFloat)yy_headIndentAtIndex:(NSUInteger)index;

/**
 tailIndent 尾部缩进
 */
/**
 The trailing indentation (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion If positive, this value is the distance from the leading margin 
 (for example, the left margin in left-to-right text). If 0 or negative, it's the 
 distance from the trailing margin.
 @discussion Default is 0.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readonly) CGFloat yy_tailIndent;
- (CGFloat)yy_tailIndentAtIndex:(NSUInteger)index;

/**
 minimumLineHeight 最小行高
 */
/**
 The receiver's minimum height (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion This property contains the minimum height in points that any line in 
 the receiver will occupy, regardless of the font size or size of any attached graphic. 
 This value must be nonnegative.
 @discussion Default is 0.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readonly) CGFloat yy_minimumLineHeight;
- (CGFloat)yy_minimumLineHeightAtIndex:(NSUInteger)index;

/**
 maximumLineHeight 最大行高
 
 */

/**
 The receiver's maximum line height (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion This property contains the maximum height in points that any line in 
 the receiver will occupy, regardless of the font size or size of any attached graphic. 
 This value is always nonnegative. Glyphs and graphics exceeding this height will 
 overlap neighboring lines; however, a maximum height of 0 implies no line height limit. 
 Although this limit applies to the line itself, line spacing adds extra space between adjacent lines.
 @discussion Default is 0 (no limit).
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readonly) CGFloat yy_maximumLineHeight;
- (CGFloat)yy_maximumLineHeightAtIndex:(NSUInteger)index;

/**
 lineHeightMultiple      可变行高,乘因数
 
 */
/**
 The line height multiple (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion This property contains the line break mode to be used laying out the paragraph's text.
 @discussion Default is 0 (no multiple).
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readonly) CGFloat yy_lineHeightMultiple;
- (CGFloat)yy_lineHeightMultipleAtIndex:(NSUInteger)index;

/**
 baseWritingDirection    句子方向
 
 */
/**
 The base writing direction (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion If you specify NSWritingDirectionNaturalDirection, the receiver resolves 
 the writing direction to either NSWritingDirectionLeftToRight or NSWritingDirectionRightToLeft, 
 depending on the direction for the user's `language` preference setting.
 @discussion Default is NSWritingDirectionNatural.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readonly) NSWritingDirection yy_baseWritingDirection;
- (NSWritingDirection)yy_baseWritingDirectionAtIndex:(NSUInteger)index;

/**
 hyphenationFactor      连字符属性，取值 0 - 1
 
 */
/**
 The paragraph's threshold for hyphenation. (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion Valid values lie between 0.0 and 1.0 inclusive. Hyphenation is attempted 
 when the ratio of the text width (as broken without hyphenation) to the width of the 
 line fragment is less than the hyphenation factor. When the paragraph's hyphenation 
 factor is 0.0, the layout manager's hyphenation factor is used instead. When both 
 are 0.0, hyphenation is disabled.
 @discussion Default is 0.
 @discussion Get this property returns the first character's attribute.
 @since UIKit:6.0
 */
@property (nonatomic, readonly) float yy_hyphenationFactor;
- (float)yy_hyphenationFactorAtIndex:(NSUInteger)index;

/**
 defaultTabInterval 默认的tab间隔
 
 */

/**
 The document-wide default tab interval (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion This property represents the default tab interval in points. Tabs after the 
 last specified in tabStops are placed at integer multiples of this distance (if positive).
 @discussion Default is 0.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:7.0  UIKit:7.0  YYText:7.0
 */
@property (nonatomic, readonly) CGFloat yy_defaultTabInterval;
- (CGFloat)yy_defaultTabIntervalAtIndex:(NSUInteger)index;

/**
 tabstop表示该控件在用tab键进行切换焦点时,是否要得到焦点
 
 */
/**
 An array of NSTextTab objects representing the receiver's tab stops.
 (A wrapper for NSParagraphStyle). (read-only)
 
 @discussion The NSTextTab objects, sorted by location, define the tab stops for 
 the paragraph style.
 @discussion Default is 12 TabStops with 28.0 tab interval.
 @discussion Get this property returns the first character's attribute.
 @since CoreText:7.0  UIKit:7.0  YYText:7.0
 */
@property (nullable, nonatomic, copy, readonly) NSArray<NSTextTab *> *yy_tabStops;
- (nullable NSArray<NSTextTab *> *)yy_tabStopsAtIndex:(NSUInteger)index;

#pragma mark - Get YYText attribute as property  获取YYText属性作为property
///=============================================================================
/// @name Get YYText attribute as property 添加像设置属性一样的设置YYText attribute的方法。
///=============================================================================

/**
 文字阴影 (只读)
 
 */
/**
 The text shadow. (read-only)
 
 @discussion Default value is nil (no shadow).
 @discussion Get this property returns the first character's attribute.
 @since YYText:6.0
 */
@property (nullable, nonatomic, strong, readonly) YYTextShadow *yy_textShadow;
- (nullable YYTextShadow *)yy_textShadowAtIndex:(NSUInteger)index;


/**
 文字内阴影 (只读)
 
 */
/**
 The text inner shadow. (read-only)
 
 @discussion Default value is nil (no shadow).
 @discussion Get this property returns the first character's attribute.
 @since YYText:6.0
 */
@property (nullable, nonatomic, strong, readonly) YYTextShadow *yy_textInnerShadow;
- (nullable YYTextShadow *)yy_textInnerShadowAtIndex:(NSUInteger)index;

/**
 文字下划线 (只读)
 
 */
/**
 The text underline. (read-only)
 
 @discussion Default value is nil (no underline).
 @discussion Get this property returns the first character's attribute.
 @since YYText:6.0
 */
@property (nullable, nonatomic, strong, readonly) YYTextDecoration *yy_textUnderline;
- (nullable YYTextDecoration *)yy_textUnderlineAtIndex:(NSUInteger)index;

/**
 文字删除线 (只读)
 
 */
/**
 The text strikethrough. (read-only)
 
 @discussion Default value is nil (no strikethrough).
 @discussion Get this property returns the first character's attribute.
 @since YYText:6.0
 */
@property (nullable, nonatomic, strong, readonly) YYTextDecoration *yy_textStrikethrough;
- (nullable YYTextDecoration *)yy_textStrikethroughAtIndex:(NSUInteger)index;

/**
 文字边框 (只读)
 
 */

/**
 The text border. (read-only)
 
 @discussion Default value is nil (no border).
 @discussion Get this property returns the first character's attribute.
 @since YYText:6.0
 */
@property (nullable, nonatomic, strong, readonly) YYTextBorder *yy_textBorder;
- (nullable YYTextBorder *)yy_textBorderAtIndex:(NSUInteger)index;

/**
 背景边框 (只读)
 
 */
/**
 The text background border. (read-only)
 
 @discussion Default value is nil (no background border).
 @discussion Get this property returns the first character's attribute.
 @since YYText:6.0
 */
@property (nullable, nonatomic, strong, readonly) YYTextBorder *yy_textBackgroundBorder;
- (nullable YYTextBorder *)yy_textBackgroundBorderAtIndex:(NSUInteger)index;


/**
 字形变换 (只读) 竖直方式显示文字 ？？？？
 
 */
/**
 The glyph transform. (read-only)
 
 @discussion Default value is CGAffineTransformIdentity (no transform).
 @discussion Get this property returns the first character's attribute.
 @since YYText:6.0
 */
@property (nonatomic, readonly) CGAffineTransform yy_textGlyphTransform;
- (CGAffineTransform)yy_textGlyphTransformAtIndex:(NSUInteger)index;


#pragma mark - Query for YYText  YYText的查询
///=============================================================================
/// @name Query for YYText
///=============================================================================

/**
 返回指定范围中的纯文本。
 如果有“YYTextBackedStringAttributeName”属性，backed string将会替换指定范围的属性字符串。
 
 */
/**
 Returns the plain text from a range.
 If there's `YYTextBackedStringAttributeName` attribute, the backed string will
 replace the attributed string range.
 
 @param range A range in receiver.
 @return The plain text.
 */
- (nullable NSString *)yy_plainTextForRange:(NSRange)range;


#pragma mark - Create attachment string for YYText  创建YYText的附件属性
///=============================================================================
/// @name Create attachment string for YYText
///=============================================================================

/**
 创建并返回 附件。
 上行高度(Ascent)和下行高度(Decent)
 
 
 */
/**
 Creates and returns an attachment.
 
 @param content      The attachment (UIImage/UIView/CALayer).
 @param contentMode  The attachment's content mode.
 @param width        The attachment's container width in layout.
 @param ascent       The attachment's container ascent in layout.
 @param descent      The attachment's container descent in layout.
 
 @return An attributed string, or nil if an error occurs.
 @since YYText:6.0
 */
+ (NSMutableAttributedString *)yy_attachmentStringWithContent:(nullable id)content
                                                  contentMode:(UIViewContentMode)contentMode
                                                        width:(CGFloat)width
                                                       ascent:(CGFloat)ascent
                                                      descent:(CGFloat)descent;

/**
 创建并返回 附件。
 上行高度(Ascent)和下行高度(Decent)
 
 
 */
/**
 Creates and returns an attachment.
 
 
 Example: ContentMode:bottom Alignment:Top.
 
      The text      The attachment holder
         ↓                ↓
     ─────────┌──────────────────────┐───────
        / \   │                      │ / ___|
       / _ \  │                      │| |
      / ___ \ │                      │| |___     ←── The text line
     /_/   \_\│    ██████████████    │ \____|
     ─────────│    ██████████████    │───────
              │    ██████████████    │
              │    ██████████████ ←───────────────── The attachment content
              │    ██████████████    │
              └──────────────────────┘

 @param content        The attachment (UIImage/UIView/CALayer).
 @param contentMode    The attachment's content mode in attachment holder
 @param attachmentSize The attachment holder's size in text layout.
 @param fontSize       The attachment will align to this font.
 @param alignment      The attachment holder's alignment to text line.
 
 @return An attributed string, or nil if an error occurs.
 @since YYText:6.0
 */
+ (NSMutableAttributedString *)yy_attachmentStringWithContent:(nullable id)content
                                                  contentMode:(UIViewContentMode)contentMode
                                               attachmentSize:(CGSize)attachmentSize
                                                  alignToFont:(UIFont *)font
                                                    alignment:(YYTextVerticalAlignment)alignment;

/**
 创建并返回 附件。 四方形image，例如表情emoji

 */
/**
 Creates and returns an attahment from a fourquare image as if it was an emoji.
 
 @param image     A fourquare image.
 @param fontSize  The font size.
 
 @return An attributed string, or nil if an error occurs.
 @since YYText:6.0
 */
+ (nullable NSMutableAttributedString *)yy_attachmentStringWithEmojiImage:(UIImage *)image
                                                                 fontSize:(CGFloat)fontSize;

#pragma mark - Utility
///=============================================================================
/// @name Utility  其他的工具型的方法。
///=============================================================================

/**
 Returns NSMakeRange(0, self.length).
 */
- (NSRange)yy_rangeOfAll;


/**
 如果为 YES，它在整个文本范围内共享相同的属性
 */
/**
 If YES, it share the same attribute in entire text range.
 */
- (BOOL)yy_isSharedAttributesInAllRange;

/**
 YES, 它会使用 [drawWithRect:options:context:] 方法绘制，或者使用 UIKit显示
 NO, 使用CoreText 或 YYText 进行绘制；
 
 如果该方法返回NO，则表示至少有一个属性UIKit不支持（如CTParagraphStyleRef）。 
 如果在UIKit中显示此字符串，它可能会丢失一些属性，甚至会崩溃应用程序。
 
 */
/**
 If YES, it can be drawn with the [drawWithRect:options:context:] method or displayed with UIKit.
 If NO, it should be drawn with CoreText or YYText.
 
 @discussion If the method returns NO, it means that there's at least one attribute 
 which is not supported by UIKit (such as CTParagraphStyleRef). If display this string
 in UIKit, it may lose some attribute, or even crash the app.
 */
- (BOOL)yy_canDrawWithUIKit;

@end




/**
 设定预定义的属性设 到 属性字符串。
 包括在UIKit，CoreText和YYText中定义的所有属性。
 */
/**
 Set pre-defined attributes to attributed string.
 All properties defined in UIKit, CoreText and YYText are included.
 */
@interface NSMutableAttributedString (YYText)

#pragma mark - Set character attribute
///=============================================================================
/// @name Set character attribute  设置字符属性
///=============================================================================

/**
 设置属性到整个文本字符串。

*/
/**
 Sets the attributes to the entire text string.
 
 @discussion The old attributes will be removed.
 
 @param attributes  A dictionary containing the attributes to set, or nil to remove all attributes.
 */
- (void)yy_setAttributes:(nullable NSDictionary<NSString *, id> *)attributes;
- (void)setYy_attributes:(nullable NSDictionary<NSString *, id> *)attributes;


/**
 设置给定名称和值的属性到整个文本字符串。
 
 */
/**
 Sets an attribute with the given name and value to the entire text string.
 
 @param name   A string specifying the attribute name.
 @param value  The attribute value associated with name. Pass `nil` or `NSNull` to
 remove the attribute.
 */
- (void)yy_setAttribute:(NSString *)name value:(nullable id)value;

/**
 设置给定名称和值的属性到指定范围的字符。
 
 */
/**
 Sets an attribute with the given name and value to the characters in the specified range.
 
 @param name   A string specifying the attribute name.
 @param value  The attribute value associated with name. Pass `nil` or `NSNull` to
 remove the attribute.
 @param range  The range of characters to which the specified attribute/value pair applies.
 */
- (void)yy_setAttribute:(NSString *)name value:(nullable id)value range:(NSRange)range;

/**
 删除指定范围的所有属性
 
 */
/**
 Removes all attributes in the specified range.
 
 @param range  The range of characters.
 */
- (void)yy_removeAttributesInRange:(NSRange)range;


#pragma mark - Set character attribute as property 设置属性一样的设置character attribute的font等

///=============================================================================
/// @name Set character attribute as property
/// 添加像设置属性一样的设置character attribute的font、color、backgroundColor等等的方法。
///=============================================================================

/**
 字体
 */
/**
 The font of the text.
 
 @discussion Default is Helvetica (Neue) 12.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0  YYText:6.0
 */
@property (nullable, nonatomic, strong, readwrite) UIFont *yy_font;
- (void)yy_setFont:(nullable UIFont *)font range:(NSRange)range;


/**
 字距调整。
 */
/**
 A kerning adjustment.
 
 @discussion Default is standard kerning. The kerning attribute indicate how many 
 points the following character should be shifted from its default offset as 
 defined by the current character's font in points; a positive kern indicates a 
 shift farther along and a negative kern indicates a shift closer to the current 
 character. If this attribute is not present, standard kerning will be used. 
 If this attribute is set to 0.0, no kerning will be done at all.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0  YYText:6.0
 */
@property (nullable, nonatomic, strong, readwrite) NSNumber *yy_kern;
- (void)yy_setKern:(nullable NSNumber *)kern range:(NSRange)range;


/**
 前景色
 */

/**
 The foreground color.
 
 @discussion Default is Black.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0  YYText:6.0
 */
@property (nullable, nonatomic, strong, readwrite) UIColor *yy_color;
- (void)yy_setColor:(nullable UIColor *)color range:(NSRange)range;


/**
 背景色
 */
/**
 The background color.
 
 @discussion Default is nil (or no background).
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since UIKit:6.0
 */
@property (nullable, nonatomic, strong, readwrite) UIColor *yy_backgroundColor;
- (void)yy_setBackgroundColor:(nullable UIColor *)backgroundColor range:(NSRange)range;

/**
 笔画宽度
 */

/**
 The stroke width.
 
 @discussion Default value is 0.0 (no stroke). This attribute, interpreted as
 a percentage of font point size, controls the text drawing mode: positive 
 values effect drawing with stroke only; negative values are for stroke and fill.
 A typical value for outlined text is 3.0.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0  YYText:6.0
 */
@property (nullable, nonatomic, strong, readwrite) NSNumber *yy_strokeWidth;
- (void)yy_setStrokeWidth:(nullable NSNumber *)strokeWidth range:(NSRange)range;

/**
 笔触颜色
 
 */

/**
 The stroke color.
 
 @discussion Default value is nil (same as foreground color).
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0  YYText:6.0
 */
@property (nullable, nonatomic, strong, readwrite) UIColor *yy_strokeColor;
- (void)yy_setStrokeColor:(nullable UIColor *)strokeColor range:(NSRange)range;

/**
 文本阴影
 
 */
/**
 The text shadow.
 
 @discussion Default value is nil (no shadow).
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since UIKit:6.0  YYText:6.0
 */
@property (nullable, nonatomic, strong, readwrite) NSShadow *yy_shadow;
- (void)yy_setShadow:(nullable NSShadow *)shadow range:(NSRange)range;

/**
 删除线的风格
 
 */
/**
 The strikethrough style.
 
 @discussion Default value is NSUnderlineStyleNone (no strikethrough).
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since UIKit:6.0
 */
@property (nonatomic, readwrite) NSUnderlineStyle yy_strikethroughStyle;
- (void)yy_setStrikethroughStyle:(NSUnderlineStyle)strikethroughStyle range:(NSRange)range;

/**
 删除线的颜色
 
 */
/**
 The strikethrough color.
 
 @discussion Default value is nil (same as foreground color).
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since UIKit:7.0
 */
@property (nullable, nonatomic, strong, readwrite) UIColor *yy_strikethroughColor;
- (void)yy_setStrikethroughColor:(nullable UIColor *)strikethroughColor range:(NSRange)range NS_AVAILABLE_IOS(7_0);

/**
 下划线样式
 
 */
/**
 The underline style.
 
 @discussion Default value is NSUnderlineStyleNone (no underline).
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0
 */
@property (nonatomic, readwrite) NSUnderlineStyle yy_underlineStyle;
- (void)yy_setUnderlineStyle:(NSUnderlineStyle)underlineStyle range:(NSRange)range;


/**
 下划线的颜色
 */

/**
 The underline color.
 
 @discussion Default value is nil (same as foreground color).
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:7.0
 */
@property (nullable, nonatomic, strong, readwrite) UIColor *yy_underlineColor;
- (void)yy_setUnderlineColor:(nullable UIColor *)underlineColor range:(NSRange)range;

/**
 连字格式控制
 
 */
/**
 Ligature formation control.
 
 @discussion Default is int value 1. The ligature attribute determines what kinds 
 of ligatures should be used when displaying the string. A value of 0 indicates 
 that only ligatures essential for proper rendering of text should be used, 
 1 indicates that standard ligatures should be used, and 2 indicates that all 
 available ligatures should be used. Which ligatures are standard depends on the 
 script and possibly the font.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:3.2  UIKit:6.0  YYText:6.0
 */
@property (nullable, nonatomic, strong, readwrite) NSNumber *yy_ligature;
- (void)yy_setLigature:(nullable NSNumber *)ligature range:(NSRange)range;

/**
 文本效果.
 
 */
/**
 The text effect.
 
 @discussion Default is nil (no effect). The only currently supported value
 is NSTextEffectLetterpressStyle.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since UIKit:7.0
 */
@property (nullable, nonatomic, strong, readwrite) NSString *yy_textEffect;
- (void)yy_setTextEffect:(nullable NSString *)textEffect range:(NSRange)range NS_AVAILABLE_IOS(7_0);

/**
 字形倾斜
 */
/**
 The skew to be applied to glyphs. 
 
 @discussion Default is 0 (no skew).
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since UIKit:7.0
 */
@property (nullable, nonatomic, strong, readwrite) NSNumber *yy_obliqueness;
- (void)yy_setObliqueness:(nullable NSNumber *)obliqueness range:(NSRange)range NS_AVAILABLE_IOS(7_0);

/**
 要应用于字形的扩展因子的日志.
 
 */
/**
 The log of the expansion factor to be applied to glyphs.
 
 @discussion Default is 0 (no expansion).
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since UIKit:7.0
 */
@property (nullable, nonatomic, strong, readwrite) NSNumber *yy_expansion;
- (void)yy_setExpansion:(nullable NSNumber *)expansion range:(NSRange)range NS_AVAILABLE_IOS(7_0);

/**
 字符与基线的偏移, 以点为单位
 */

/**
 The character's offset from the baseline, in points. 
 
 @discussion Default is 0.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since UIKit:7.0
 */
@property (nullable, nonatomic, strong, readwrite) NSNumber *yy_baselineOffset;
- (void)yy_setBaselineOffset:(nullable NSNumber *)baselineOffset range:(NSRange)range NS_AVAILABLE_IOS(7_0);

/**
 字形方向控制.
 
 */
/**
 Glyph orientation control.
 
 @discussion Default is NO. A value of NO indicates that horizontal glyph forms 
 are to be used, YES indicates that vertical glyph forms are to be used.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:4.3  YYText:6.0
 */
@property (nonatomic, readwrite) BOOL yy_verticalGlyphForm;
- (void)yy_setVerticalGlyphForm:(BOOL)verticalGlyphForm range:(NSRange)range;

/**
 指定文本语言.
 
 */
/**
 Specifies text language.
 
 @discussion Value must be a NSString containing a locale identifier. Default is 
 unset. When this attribute is set to a valid identifier, it will be used to select 
 localized glyphs (if supported by the font) and locale-specific line breaking rules.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:7.0  YYText:7.0
 */
@property (nullable, nonatomic, strong, readwrite) NSString *yy_language;
- (void)yy_setLanguage:(nullable NSString *)language range:(NSRange)range NS_AVAILABLE_IOS(7_0);

/**
 指定双向覆盖或嵌入
 
 */

/**
 Specifies a bidirectional override or embedding.
 
 @discussion See alse NSWritingDirection and NSWritingDirectionAttributeName.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:7.0  YYText:6.0
 */
@property (nullable, nonatomic, strong, readwrite) NSArray<NSNumber *> *yy_writingDirection;
- (void)yy_setWritingDirection:(nullable NSArray<NSNumber *> *)writingDirection range:(NSRange)range;

/**
 一个段落样式对象，用于指定如 段落行对齐，制表符，写入方向等
 */
/**
 An NSParagraphStyle object which is used to specify things like
 line alignment, tab rulers, writing direction, etc.
 
 @discussion Default is nil ([NSParagraphStyle defaultParagraphStyle]).
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nullable, nonatomic, strong, readwrite) NSParagraphStyle *yy_paragraphStyle;
- (void)yy_setParagraphStyle:(nullable NSParagraphStyle *)paragraphStyle range:(NSRange)range;


#pragma mark - Set paragraph attribute as property
// 添加像设置属性一样的设置paragraph attribute的方法。

///=============================================================================
/// @name Set paragraph attribute as property
///=============================================================================

/**
 文本对齐
 */
 
/**
 The text alignment (A wrapper for NSParagraphStyle).
 
 @discussion Natural text alignment is realized as left or right alignment
 depending on the line sweep direction of the first script contained in the paragraph.
 @discussion Default is NSTextAlignmentNatural.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readwrite) NSTextAlignment yy_alignment;
- (void)yy_setAlignment:(NSTextAlignment)alignment range:(NSRange)range;

/**
 lineBreakMode 断行方式
 */

/**
 The mode that should be used to break lines (A wrapper for NSParagraphStyle).
 
 @discussion This property contains the line break mode to be used laying out the paragraph's text.
 @discussion Default is NSLineBreakByWordWrapping.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readwrite) NSLineBreakMode yy_lineBreakMode;
- (void)yy_setLineBreakMode:(NSLineBreakMode)lineBreakMode range:(NSRange)range;

/**
 lineSpacing 行间距
 
 */

/**
 The distance in points between the bottom of one line fragment and the top of the next.
 (A wrapper for NSParagraphStyle)
 
 @discussion This value is always nonnegative. This value is included in the line
 fragment heights in the layout manager.
 @discussion Default is 0.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readwrite) CGFloat yy_lineSpacing;
- (void)yy_setLineSpacing:(CGFloat)lineSpacing range:(NSRange)range;

/**
 paragraphSpacing 段间距
 
 */
/**
 The space after the end of the paragraph (A wrapper for NSParagraphStyle).
 
 @discussion This property contains the space (measured in points) added at the
 end of the paragraph to separate it from the following paragraph. This value must
 be nonnegative. The space between paragraphs is determined by adding the previous
 paragraph's paragraphSpacing and the current paragraph's paragraphSpacingBefore.
 @discussion Default is 0.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readwrite) CGFloat yy_paragraphSpacing;
- (void)yy_setParagraphSpacing:(CGFloat)paragraphSpacing range:(NSRange)range;


/**
 paragraphSpacingBefore 段首空间
 
 */

/**
 The distance between the paragraph's top and the beginning of its text content.
 (A wrapper for NSParagraphStyle).
 
 @discussion This property contains the space (measured in points) between the
 paragraph's top and the beginning of its text content.
 @discussion Default is 0.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readwrite) CGFloat yy_paragraphSpacingBefore;
- (void)yy_setParagraphSpacingBefore:(CGFloat)paragraphSpacingBefore range:(NSRange)range;


/**
 firstLineHeadIndent 首行缩进
 
 */
/**
 The indentation of the first line (A wrapper for NSParagraphStyle).
 
 @discussion This property contains the distance (in points) from the leading margin
 of a text container to the beginning of the paragraph's first line. This value
 is always nonnegative.
 @discussion Default is 0.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readwrite) CGFloat yy_firstLineHeadIndent;
- (void)yy_setFirstLineHeadIndent:(CGFloat)firstLineHeadIndent range:(NSRange)range;

/**
 headIndent 段落头部缩进
 
 */
/**
 The indentation of the receiver's lines other than the first. (A wrapper for NSParagraphStyle).
 
 @discussion This property contains the distance (in points) from the leading margin
 of a text container to the beginning of lines other than the first. This value is
 always nonnegative.
 @discussion Default is 0.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readwrite) CGFloat yy_headIndent;
- (void)yy_setHeadIndent:(CGFloat)headIndent range:(NSRange)range;

/**
 tailIndent 尾部缩进
 */

/**
 The trailing indentation (A wrapper for NSParagraphStyle).
 
 @discussion If positive, this value is the distance from the leading margin
 (for example, the left margin in left-to-right text). If 0 or negative, it's the
 distance from the trailing margin.
 @discussion Default is 0.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readwrite) CGFloat yy_tailIndent;
- (void)yy_setTailIndent:(CGFloat)tailIndent range:(NSRange)range;

/**
 minimumLineHeight 最小行高
 */

/**
 The receiver's minimum height (A wrapper for NSParagraphStyle).
 
 @discussion This property contains the minimum height in points that any line in
 the receiver will occupy, regardless of the font size or size of any attached graphic.
 This value must be nonnegative.
 @discussion Default is 0.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readwrite) CGFloat yy_minimumLineHeight;
- (void)yy_setMinimumLineHeight:(CGFloat)minimumLineHeight range:(NSRange)range;

/**
 maximumLineHeight 最大行高
 
 */

/**
 The receiver's maximum line height (A wrapper for NSParagraphStyle).
 
 @discussion This property contains the maximum height in points that any line in
 the receiver will occupy, regardless of the font size or size of any attached graphic.
 This value is always nonnegative. Glyphs and graphics exceeding this height will
 overlap neighboring lines; however, a maximum height of 0 implies no line height limit.
 Although this limit applies to the line itself, line spacing adds extra space between adjacent lines.
 @discussion Default is 0 (no limit).
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readwrite) CGFloat yy_maximumLineHeight;
- (void)yy_setMaximumLineHeight:(CGFloat)maximumLineHeight range:(NSRange)range;

/**
 lineHeightMultiple      可变行高,乘因数
 
 */
/**
 The line height multiple (A wrapper for NSParagraphStyle).
 
 @discussion This property contains the line break mode to be used laying out the paragraph's text.
 @discussion Default is 0 (no multiple).
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readwrite) CGFloat yy_lineHeightMultiple;
- (void)yy_setLineHeightMultiple:(CGFloat)lineHeightMultiple range:(NSRange)range;

/**
 baseWritingDirection    句子方向
 
 */
/**
 The base writing direction (A wrapper for NSParagraphStyle).
 
 @discussion If you specify NSWritingDirectionNaturalDirection, the receiver resolves
 the writing direction to either NSWritingDirectionLeftToRight or NSWritingDirectionRightToLeft,
 depending on the direction for the user's `language` preference setting.
 @discussion Default is NSWritingDirectionNatural.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:6.0  UIKit:6.0  YYText:6.0
 */
@property (nonatomic, readwrite) NSWritingDirection yy_baseWritingDirection;
- (void)yy_setBaseWritingDirection:(NSWritingDirection)baseWritingDirection range:(NSRange)range;

/**
 hyphenationFactor      连字符属性，取值 0 - 1
 
 */
/**
 The paragraph's threshold for hyphenation. (A wrapper for NSParagraphStyle).
 
 @discussion Valid values lie between 0.0 and 1.0 inclusive. Hyphenation is attempted
 when the ratio of the text width (as broken without hyphenation) to the width of the
 line fragment is less than the hyphenation factor. When the paragraph's hyphenation
 factor is 0.0, the layout manager's hyphenation factor is used instead. When both
 are 0.0, hyphenation is disabled.
 @discussion Default is 0.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since UIKit:6.0
 */
@property (nonatomic, readwrite) float yy_hyphenationFactor;
- (void)yy_setHyphenationFactor:(float)hyphenationFactor range:(NSRange)range;

/**
 defaultTabInterval 默认的tab间隔
 
 */
/**
 The document-wide default tab interval (A wrapper for NSParagraphStyle).
 
 @discussion This property represents the default tab interval in points. Tabs after the
 last specified in tabStops are placed at integer multiples of this distance (if positive).
 @discussion Default is 0.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:7.0  UIKit:7.0  YYText:7.0
 */
@property (nonatomic, readwrite) CGFloat yy_defaultTabInterval;
- (void)yy_setDefaultTabInterval:(CGFloat)defaultTabInterval range:(NSRange)range NS_AVAILABLE_IOS(7_0);


/**
 tabstop表示该控件在用tab键进行切换焦点时,是否要得到焦点
 
 */
/**
 An array of NSTextTab objects representing the receiver's tab stops.
 (A wrapper for NSParagraphStyle).
 
 @discussion The NSTextTab objects, sorted by location, define the tab stops for
 the paragraph style.
 @discussion Default is 12 TabStops with 28.0 tab interval.
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since CoreText:7.0  UIKit:7.0  YYText:7.0
 */
@property (nullable, nonatomic, copy, readwrite) NSArray<NSTextTab *> *yy_tabStops;
- (void)yy_setTabStops:(nullable NSArray<NSTextTab *> *)tabStops range:(NSRange)range NS_AVAILABLE_IOS(7_0);

#pragma mark - Set YYText attribute as property 添加像设置属性一样的设置YYText attribute的方法。
///=============================================================================
/// @name Set YYText attribute as property
///=============================================================================

/**
 文字阴影
 
 */
/**
 The text shadow.
 
 @discussion Default value is nil (no shadow).
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since YYText:6.0
 */
@property (nullable, nonatomic, strong, readwrite) YYTextShadow *yy_textShadow;
- (void)yy_setTextShadow:(nullable YYTextShadow *)textShadow range:(NSRange)range;

/**
 文字内阴影
 
 */
/**
 The text inner shadow.
 
 @discussion Default value is nil (no shadow).
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since YYText:6.0
 */
@property (nullable, nonatomic, strong, readwrite) YYTextShadow *yy_textInnerShadow;
- (void)yy_setTextInnerShadow:(nullable YYTextShadow *)textInnerShadow range:(NSRange)range;

/**
 文字下划线
 
 */
/**
 The text underline.
 
 @discussion Default value is nil (no underline).
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since YYText:6.0
 */
@property (nullable, nonatomic, strong, readwrite) YYTextDecoration *yy_textUnderline;
- (void)yy_setTextUnderline:(nullable YYTextDecoration *)textUnderline range:(NSRange)range;


/**
 文字删除线
 
 */
/**
 The text strikethrough.
 
 @discussion Default value is nil (no strikethrough).
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since YYText:6.0
 */
@property (nullable, nonatomic, strong, readwrite) YYTextDecoration *yy_textStrikethrough;
- (void)yy_setTextStrikethrough:(nullable YYTextDecoration *)textStrikethrough range:(NSRange)range;

/**
 文字边框
 
 */
/**
 The text border.
 
 @discussion Default value is nil (no border).
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since YYText:6.0
 */
@property (nullable, nonatomic, strong, readwrite) YYTextBorder *yy_textBorder;
- (void)yy_setTextBorder:(nullable YYTextBorder *)textBorder range:(NSRange)range;

/**
 背景边框
 
 */
/**
 The text background border.
 
 @discussion Default value is nil (no background border).
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since YYText:6.0
 */
@property (nullable, nonatomic, strong, readwrite) YYTextBorder *yy_textBackgroundBorder;
- (void)yy_setTextBackgroundBorder:(nullable YYTextBorder *)textBackgroundBorder range:(NSRange)range;


/**
 字形变换 (只读) 竖直方式显示文字s
 
 */
/**
 The glyph transform.
 
 @discussion Default value is CGAffineTransformIdentity (no transform).
 @discussion Set this property applies to the entire text string.
             Get this property returns the first character's attribute.
 @since YYText:6.0
 */
@property (nonatomic, readwrite) CGAffineTransform yy_textGlyphTransform;
- (void)yy_setTextGlyphTransform:(CGAffineTransform)textGlyphTransform range:(NSRange)range;


#pragma mark - Set discontinuous attribute for range 使用range设置不连续的attribute的方法

///=============================================================================
/// @name Set discontinuous attribute for range  使用range设置不连续的attribute的方法
///=============================================================================

- (void)yy_setSuperscript:(nullable NSNumber *)superscript range:(NSRange)range;
- (void)yy_setGlyphInfo:(nullable CTGlyphInfoRef)glyphInfo range:(NSRange)range;
- (void)yy_setCharacterShape:(nullable NSNumber *)characterShape range:(NSRange)range;
- (void)yy_setRunDelegate:(nullable CTRunDelegateRef)runDelegate range:(NSRange)range;
- (void)yy_setBaselineClass:(nullable CFStringRef)baselineClass range:(NSRange)range;
- (void)yy_setBaselineInfo:(nullable CFDictionaryRef)baselineInfo range:(NSRange)range;
- (void)yy_setBaselineReferenceInfo:(nullable CFDictionaryRef)referenceInfo range:(NSRange)range;
- (void)yy_setRubyAnnotation:(nullable CTRubyAnnotationRef)ruby range:(NSRange)range NS_AVAILABLE_IOS(8_0);
- (void)yy_setAttachment:(nullable NSTextAttachment *)attachment range:(NSRange)range NS_AVAILABLE_IOS(7_0);
- (void)yy_setLink:(nullable id)link range:(NSRange)range NS_AVAILABLE_IOS(7_0);
- (void)yy_setTextBackedString:(nullable YYTextBackedString *)textBackedString range:(NSRange)range;
- (void)yy_setTextBinding:(nullable YYTextBinding *)textBinding range:(NSRange)range;
- (void)yy_setTextAttachment:(nullable YYTextAttachment *)textAttachment range:(NSRange)range;
- (void)yy_setTextHighlight:(nullable YYTextHighlight *)textHighlight range:(NSRange)range;
- (void)yy_setTextBlockBorder:(nullable YYTextBorder *)textBlockBorder range:(NSRange)range;
- (void)yy_setTextRubyAnnotation:(nullable YYTextRubyAnnotation *)ruby range:(NSRange)range NS_AVAILABLE_IOS(8_0);


#pragma mark - Convenience methods for text highlight 设置text highlight 的便捷方法

///=============================================================================
/// @name Convenience methods for text highlight  设置text highlight 的便捷方法
///=============================================================================

/**
 Convenience method to set text highlight
 
 @param range           text range
 @param color           text color (pass nil to ignore)
 @param backgroundColor text background color when highlight
 @param userInfo        user information dictionary (pass nil to ignore)
 @param tapAction       tap action when user tap the highlight (pass nil to ignore)
 @param longPressAction long press action when user long press the highlight (pass nil to ignore)
 */
- (void)yy_setTextHighlightRange:(NSRange)range
                           color:(nullable UIColor *)color
                 backgroundColor:(nullable UIColor *)backgroundColor
                        userInfo:(nullable NSDictionary *)userInfo
                       tapAction:(nullable YYTextAction)tapAction
                 longPressAction:(nullable YYTextAction)longPressAction;

/**
 Convenience method to set text highlight
 
 @param range           text range
 @param color           text color (pass nil to ignore)
 @param backgroundColor text background color when highlight
 @param tapAction       tap action when user tap the highlight (pass nil to ignore)
 */
- (void)yy_setTextHighlightRange:(NSRange)range
                           color:(nullable UIColor *)color
                 backgroundColor:(nullable UIColor *)backgroundColor
                       tapAction:(nullable YYTextAction)tapAction;

/**
 Convenience method to set text highlight
 
 @param range           text range
 @param color           text color (pass nil to ignore)
 @param backgroundColor text background color when highlight
 @param userInfo        tap action when user tap the highlight (pass nil to ignore)
 */
- (void)yy_setTextHighlightRange:(NSRange)range
                           color:(nullable UIColor *)color
                 backgroundColor:(nullable UIColor *)backgroundColor
                        userInfo:(nullable NSDictionary *)userInfo;

#pragma mark - Utilities
// 和其他的工具型的方法

///=============================================================================
/// @name Utilities
///=============================================================================

/**
 
 */
/**
 Inserts into the receiver the characters of a given string at a given location.
 The new string inherit the attributes of the first replaced character from location.
 
 @param string  The string to insert into the receiver, must not be nil.
 @param location The location at which string is inserted. The location must not 
    exceed the bounds of the receiver.
 @throw Raises an NSRangeException if the location out of bounds.
 */
- (void)yy_insertString:(NSString *)string atIndex:(NSUInteger)location;

/**
 Adds to the end of the receiver the characters of a given string.
 The new string inherit the attributes of the receiver's tail.
 
 @param string  The string to append to the receiver, must not be nil.
 */
- (void)yy_appendString:(NSString *)string;

/**
 在连接表情符号范围内 `joined-emoji` 使用[UIColor clearColor]设置前景色。
 情符号绘制不会受到前景色的影响。
  
 @discussion在iOS 8.3中，苹果发布了一些新的多元化表情符号。
 有一些表情符号可以组合成一个新的合并表情 `joined-emoji`。
 连接器是unicode字符“ZERO WIDTH JOINER”（U + 200D）。
 例如：👨👩👧👧 -> 👨‍👩‍👧‍👧.
 
 当一个CTLine中有超过5个'joined-emoji'时，CoreText可能会渲染一些
 额外的字形在表情符号之上。 这是CoreText中的一个bug，使用这个方法尝试避免bug。
 iOS 9中修复了这个bug。
 
 */
/**
 Set foreground color with [UIColor clearColor] in joined-emoji range.
 Emoji drawing will not be affected by the foreground color.
 
 @discussion In iOS 8.3, Apple releases some new diversified emojis. 
 There's some single emoji which can be assembled to a new 'joined-emoji'.
 The joiner is unicode character 'ZERO WIDTH JOINER' (U+200D).
 For example: 👨👩👧👧 -> 👨‍👩‍👧‍👧.
 
 When there are more than 5 'joined-emoji' in a same CTLine, CoreText may render some
 extra glyphs above the emoji. It's a bug in CoreText, try this method to avoid.
 This bug is fixed in iOS 9.
 */
- (void)yy_setClearColorToJoinedEmoji;

/**
 Removes all discontinuous attributes in a specified range.
 See `allDiscontinuousAttributeKeys`.
 
 @param range A text range.
 */
- (void)yy_removeDiscontinuousAttributesInRange:(NSRange)range;

/**
 Returns all discontinuous attribute keys, such as RunDelegate/Attachment/Ruby.
 
 @discussion These attributes can only set to a specified range of text, and
 should not extend to other range when editing text.
 */
+ (NSArray<NSString *> *)yy_allDiscontinuousAttributeKeys;

@end

NS_ASSUME_NONNULL_END
