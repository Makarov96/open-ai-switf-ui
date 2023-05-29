//
//  ContentView.swift
//  openai
//
//  Created by Guerin Steven Colocho Chacon on 25/05/23.
//

import SwiftUI
import OpenAIKit
import Combine
import SVGKit


struct ContentView: View {
    @State var text:String = ""
    @State var flag:String = ""
    @StateObject var controller:OpenAIController
    @State private var  animation:Bool = false

    var scaleEffectSize: CGSize {
        animation ? CGSize(width: 70, height: 70) : CGSize(width: 50, height:50)
    }
    
    
    
    init() {
        _controller = .init(wrappedValue: OpenAIController(viewModel:OpenAiViewModel()))

    }
 
    var body: some View {
     
        TabView{
            chatBotGenerator().tabItem {
                Label("ChatBot", systemImage: "circle.bottomhalf.filled")
            }
            imageGenerator()
                .tabItem {
                    Label("Image Generator", systemImage: "photo.fill")
                }
            
          
        }
        .padding(.horizontal, 30)
        .tint(.black)
        .ignoresSafeArea()
        .onAppear{
            controller.setUp()
      
        }
    }
    
    @ViewBuilder
    func chatBotGenerator()-> some View{
        VStack{
         
            Spacer()
            switch controller.status {
            case .successText(let text):
                if let text = text {
                    ScrollView(showsIndicators: false){
                        Text(text)
                    }
                }
             
            case .loading:
                
                 VStack{
                  
                     Image("gpt").resizable().aspectRatio(contentMode: .fit).frame(width: scaleEffectSize.width, height: scaleEffectSize.height).rotationEffect(.degrees(animation ? 360 : 0))
                        
                  
                        
                 
                 }
            case .success( _):
                ZStack{
                   
                }
            case .error:
                ZStack{}
                
            case .none:
                
                 VStack{
                     Text("write something")
                     Image("gpt").resizable().aspectRatio(contentMode: .fit).frame(width: 80, height: 80)
                         
                  
                 }
            }
        Spacer()
            HStack{
                TextField("Your prompt",text:$text)
            
                Button {
                  
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeInOut(duration: 1.5)
                            .repeatCount(30, autoreverses: true)) {
                                animation = true
       
                        }
                        
                    }
                   
                    if !text.trimmingCharacters(in: .whitespaces).isEmpty{
                        
                        Task{
                           flag = text
                            text = ""
                            await controller.requestMessage(input:flag)
                            animation = false
                            flag = ""
                            
                         }
                    }
                      
                } label: {
                    Circle().frame(width: 43, height: 43).overlay {
                        Image(systemName: "paperplane.fill").foregroundColor(.white)
                    }
                }

            }
            
        }
    }
    
    @ViewBuilder
    func imageGenerator()-> some View {
        VStack {
            Spacer()
            switch controller.status {
            case .successText(_):
                VStack{}
             
            case .loading:
                
                 VStack{
                     ProgressView("generating response…")
                         .progressViewStyle(CircularProgressViewStyle()).frame(width: 100, height: 100)
                 }
            case .success(let image):
                ZStack{
                   if let image = image {
                        Image(uiImage: image).resizable().aspectRatio(contentMode: .fit).frame(width: 300, height: 300)
                    }
                }
            case .error:
                ZStack{}
                
            case .none:
                
                 VStack{
                     Text("write something")
                 }
            }
        
      
            Spacer()
                HStack{
                    TextField("Your prompt",text:$text)
                
                    Button {
                        print("hey")
                           if !text.trimmingCharacters(in: .whitespaces).isEmpty{
                               Task{
                                   
                                   flag = text
                                   text = ""
                                   await controller.requestOption(input:flag)
                                
                                   flag = ""
                               }
                           }
                    } label: {
                        Circle().frame(width: 43, height: 43).overlay {
                            Image(systemName: "paperplane.fill").foregroundColor(.white)
                        }
                    }

                }
                
       

        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}






protocol OpenAiBase: ObservableObject{
    var openAI: OpenAI? {get set}
    var statusBinding: Published<Status>.Publisher {get}
    func septup()->Void
    func makeImage(input prompt:String) async-> Void
    func makeChatBot(input promp:String) async -> Void
    
}

enum Status: Equatable{
    case none
    case loading
    case error
    case success(UIImage?)
    case successText(String?)
 }



class StatusSelection: ObservableObject {
    @Published var selectedOption: Status = .none
    func updated(status input: Status)->Void{
        selectedOption = input
    }
    
}
final class OpenAIController: ObservableObject{
    
    var viewModel:any OpenAiBase
    @Published var status:Status = .none
    init(viewModel: any OpenAiBase) {
        self.viewModel = viewModel
  
     setup()
    }
    func setup()->Void{
        viewModel.statusBinding.assign(to: &$status)
    }
    
    func requestOption(input prompt:String)async->Void{
          await  viewModel.makeImage(input: prompt)
    }
    
    func requestMessage(input prompt:String)async -> Void {
        await viewModel.makeChatBot(input: prompt)
    }
    
    func setUp()->Void{
        viewModel.septup()
    }
    
}

final class OpenAiViewModel:OpenAiBase,ObservableObject{
 
  @Published var status: Status = .none
    
    var statusBinding: Published<Status>.Publisher {$status}
  
    var openAI: OpenAI?
    func septup() {
            let config = Configuration(organizationId: "your-org-api", apiKey: "your-api-key")
        openAI = OpenAI(config)
    }
    
    func makeImage(input prompt: String) async {
        status = .loading
        guard let openAI = openAI else {
            return
        }
        do{
            let imageParams = ImageParameters(prompt: prompt, resolution: .medium,responseFormat: .base64Json)
            let result = try await openAI.createImage(
               parameters: imageParams
             )
             let b64Image = result.data[0].image
             let image = try openAI.decodeBase64Image(b64Image)
            status = .success(image)

       
        }catch{
            print("here's error: \(error)")
            status = .error
            return
        }
    }
    
    func makeChatBot(input prompt: String) async {
        status = .loading
        guard let openAI = openAI else {
            return
        }
 
        do{
            let chatMsg = ChatMessage(role: .user, content: prompt)
               let chat = ChatParameters(model: "gpt-3.5-turbo", messages: [chatMsg])
               var response = ""
               let result = try? await openAI.generateChatCompletion(parameters: chat)
               if let aiResult = result {
                   if let text = aiResult.choices.first?.message.content {
                       response = "Response: " + text }
                   else {
                       response = "Error"
                   }
               } else { response = "Nada"}
            status = .successText(response)
        }catch{
            print("here's error: \(error)")
            status = .error
            return
        }
    }
     
    
}
