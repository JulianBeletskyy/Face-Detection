/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 * @flow strict-local
 */

import React, { useEffect, useState, useRef } from 'react'
import { SafeAreaView, StyleSheet, requireNativeComponent, Text, Dimensions, View } from 'react-native'
import { request, PERMISSIONS, RESULTS } from 'react-native-permissions'
import Canvas from 'react-native-canvas'

const { width, height } = Dimensions.get('window')

// console.log(width, height)

const RNTPoseView = requireNativeComponent('PoseView')
const ARKitView = requireNativeComponent('ARKitView')

const App = () => {

  const canvas = useRef(null)

  const [cameraStatus, setCameraStatus] = useState(null)
  const [detectionType, setDetectionType] = useState('contour')

  useEffect(() => {
    request(PERMISSIONS.IOS.CAMERA).then(result => {
      setCameraStatus(result)
    }).catch(error => console.log(error))
  }, [])

  const onDetectFace = ({nativeEvent: {face}}) => {
    // console.log(face)
    let points = []
    switch (detectionType) {
      case 'landmark':
        points = face.filter(el => el.position).map(el => {
          return {
            x: el.position.x,
            y: el.position.y
          }
        })
        break
      case 'contour':
        points = face.filter(el => 'points' in el).flatMap(contour => {
          // console.log(contour.points)
          if (contour?.points) {
            return Object.values(contour.points)
          }
        })
        break
      default:
        return
    }
    drawDots(points)
  }

  const drawDots = points => {
    canvas.current.height = height
    canvas.current.width = width
    const ctx = canvas.current.getContext('2d')
    ctx.clearRect(0, 0, canvas.current.width, canvas.current.height)
    points.map((item, i) => {
      const x = (item.x / 480) * width
      const y = (item.y / 640) * height
      ctx.beginPath()
      ctx.fillStyle = 'red'
      ctx.arc(x,y,3,0,Math.PI*2,true)
      ctx.fill()
    })
  }

  const handleLayout = event => {
    console.log(event.nativeEvent)
  }

  return (
    <View style={{flex: 1}}>
      {/* <ARKitView style={{width: '100%', height: '100%', borderWidth: 1, borderColor: 'red'}} /> */}
      {
        cameraStatus === RESULTS.GRANTED
          ? <RNTPoseView
              onLayout={handleLayout}
              cameraType="front"
              detectionMode={detectionType}
              onDetect={onDetectFace}
              style={{width: '100%', height: '100%', borderWidth: 1, borderColor: 'red'}} />
          : <Text>Haven't camera access</Text>
      }
      <Canvas ref={canvas} style={styles.canvas} />
    </View>
  )
}

const styles = StyleSheet.create({
  canvas: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    left: 0,
    right: 0,
    borderWidth: 1,
    borderColor: 'green'
  }
})

export default App
