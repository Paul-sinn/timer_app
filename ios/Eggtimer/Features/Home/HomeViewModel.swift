//
//  HomeViewModel.swift
//  Eggtimer
//
//  홈 화면의 상태 소스(MVVM). Phase 0이므로 MockData(AppSnapshot)를 주입받아
//  화면을 그리기만 한다. 실제 타이머 카운트다운/부화 로직은 Phase 2 범위(미구현).
//

import SwiftUI

@Observable
final class HomeViewModel {
    /// 인사용 표시 이름.
    let displayName: String
    /// 알 부화 진행 상태(crack 단계/진행도/남은 시간 계산 소스).
    let egg: EggState

    init(displayName: String, egg: EggState) {
        self.displayName = displayName
        self.egg = egg
    }

    /// AppSnapshot에서 홈에 필요한 부분만 추려 주입.
    convenience init(snapshot: AppSnapshot) {
        self.init(displayName: snapshot.displayName, egg: snapshot.egg)
    }

    /// 더미 타이머 표시값(mm:ss). 실제 카운트다운은 없고 고정 더미값을 보여준다.
    let timerDisplay = "25:00"

    /// 진행도 보조 캡션. 부화 임박 여부에 따라 문구가 바뀐다.
    var progressCaption: String {
        let percent = Int((egg.progress * 100).rounded())
        if egg.isHatched {
            return "부화 준비 완료 · \(percent)%"
        }
        return "부화까지 \(egg.remainingMinutes)분 · \(percent)%"
    }

    /// 균열 단계 캡션(15분마다 1단계).
    var crackCaption: String {
        "균열 \(egg.crackStage)단계"
    }
}
