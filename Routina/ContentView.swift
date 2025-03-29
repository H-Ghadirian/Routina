//
//  ContentView.swift
//  Routina
//
//  Created by ghadirianh on 07.03.25.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("lastCallDate") private var lastCallDate: Date = Date()
    @AppStorage("callInterval") private var callInterval: Int = 7 // Default to 7 days

    private var daysSinceLastCall: Int {
        Calendar.current.dateComponents([.day], from: lastCallDate, to: Date()).day ?? 0
    }

    private var progressColor: Color {
        let progress = Double(daysSinceLastCall) / Double(callInterval)
        switch progress {
        case ..<0.33:
            return .green
        case ..<0.66:
            return .yellow
        default:
            return .red
        }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 40), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("Call Mom")
                .font(.largeTitle)
                .bold()

            Text("\(daysSinceLastCall) day(s) passed")
                .foregroundColor(.secondary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(0..<callInterval, id: \ .self) { index in
                    Rectangle()
                        .fill(index < daysSinceLastCall ? progressColor : Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .cornerRadius(5)
                }
            }
            .padding()

            Text("Last called: \(lastCallDate.formatted(date: .abbreviated, time: .omitted))")
                .foregroundColor(.gray)

            Button("Mark as Done") {
                lastCallDate = Date()
            }
            .buttonStyle(.borderedProminent)

            HStack {
                Text("Call every:")
                Picker("Interval", selection: $callInterval) {
                    ForEach([1, 3, 7, 14, 30], id: \ .self) { days in
                        Text("\(days) days").tag(days)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding()
    }
}
