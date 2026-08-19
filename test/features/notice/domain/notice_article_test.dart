import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/features/notice/domain/notice_article.dart';

void main() {
  test('구조화된 공지 내용을 섹션과 행으로 변환한다', () {
    const article = NoticeArticle(
      id: 1,
      title: '길드 내규',
      content:
          r'길드 내규 > 참여 > 주 3회\n필수'
          '\n'
          r'마무리 >  > 감사합니다',
      color: '#4F6EF7',
      updatedAt: null,
    );

    expect(article.sections, hasLength(2));
    expect(article.sections.first.title, '길드 내규');
    expect(article.sections.first.rows.first.label, '참여');
    expect(article.sections.first.rows.first.value, '주 3회\n필수');
    expect(article.sections.last.rows.first.value, '감사합니다');
  });

  test('줄바꿈과 역슬래시를 보존해 구조화된 공지 본문을 생성한다', () {
    const sections = <NoticeSection>[
      NoticeSection(
        title: '길드 내규',
        rows: <NoticeRow>[
          NoticeRow(label: '보스 참여', value: '1차 참여\n경로 C:\\boss'),
        ],
      ),
    ];

    final content = NoticeSection.buildContent(sections);
    final parsed = NoticeSection.parse(content);

    expect(parsed.single.title, '길드 내규');
    expect(parsed.single.rows.single.label, '보스 참여');
    expect(parsed.single.rows.single.value, '1차 참여\n경로 C:\\boss');
  });

  test('내규의 제목 또는 본문만 있는 행도 보존한다', () {
    const sections = <NoticeSection>[
      NoticeSection(
        title: '길드 내규',
        rows: <NoticeRow>[
          NoticeRow(label: '보스 참여', value: ''),
          NoticeRow(label: '', value: '운영진에게 먼저 알려 주세요.'),
        ],
      ),
    ];

    final parsed = NoticeSection.parse(NoticeSection.buildContent(sections));

    expect(parsed.single.rows[0].label, '보스 참여');
    expect(parsed.single.rows[0].value, isEmpty);
    expect(parsed.single.rows[1].label, isEmpty);
    expect(parsed.single.rows[1].value, '운영진에게 먼저 알려 주세요.');
  });
}
