//
//  ContentView.swift
//
//
//  Created by Naoya Maeda on 2024/01/20
//
//

import SwiftUI

struct ContentView: View {
    @StateObject var reader = NFCTagReader()
    @FocusState private var emailFieldIsFocused: Bool
    
    var body: some View {
        VStack {
            Text("Scan Result")
                .font(.title)
            Text(reader.readMessage ?? "")
            Spacer()
            if reader.sessionType == .write {
                VStack(alignment: .leading) {
                    Text("Write Message")
                    TextField(
                        "Enter the message.",
                        text: $reader.writeMesage
                    )
                    .focused($emailFieldIsFocused)
                    .onSubmit {
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
            }
            Picker("Session Type", selection: $reader.sessionType) {
                ForEach(SessionType.allCases) { session in
                    Text(session.rawValue).tag(session)
                }
            }
            .colorMultiply(.accentColor)
            .pickerStyle(.segmented)
            .padding()
            Picker("NFC Type", selection: $reader.nfcype) {
                ForEach(NFCType.allCases) { session in
                    Text(session.rawValue).tag(session)
                }
            }
            .colorMultiply(.accentColor)
            .pickerStyle(.segmented)
            .padding()
            Button(action: {
                reader.beginScanning()
            }, label: {
                Text("Scan")
                    .frame(width: 200, height: 15)
            })
            .padding()
            .accentColor(Color.white)
            .background(Color.accentColor)
            .cornerRadius(.infinity)
            .disabled(!reader.readingAvailable)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
